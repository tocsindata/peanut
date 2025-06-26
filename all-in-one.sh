#!/bin/bash
set -e

i=0

error_exit() {
    echo "❌ $1" >&2
    exit 1
}

status() {
    echo "🔹 $1"
}

# Prompt for domain and username
read -rp "Domain name (example.com): " DOMAIN
[[ "$DOMAIN" =~ ^[a-zA-Z0-9.-]+$ ]] || error_exit "Invalid domain"
read -rp "System username: " USERNAME
[[ -z "$USERNAME" ]] && error_exit "Username cannot be empty"
read -rp "System group name: " GROUPNAME
[[ -z "$GROUPNAME" ]] && error_exit "Group name cannot be empty"

# Create group if it doesn't exist
getent group "$GROUPNAME" >/dev/null || groupadd "$GROUPNAME" || error_exit "Failed to create group $GROUPNAME"

# Create user if it doesn't exist
if ! id "$USERNAME" >/dev/null 2>&1; then
    useradd -m -d "/home/$USERNAME" -s /bin/bash -g "$GROUPNAME" "$USERNAME" || error_exit "Failed to create user $USERNAME"
    status "User $USERNAME created"
fi

# Set password for the user
read -rp "Set password for user $USERNAME (leave empty for random): " USER_PASS
if [[ -z "$USER_PASS" ]]; then
    USER_PASS=$(openssl rand -base64 12)
    echo "Generated password: $USER_PASS"
fi
echo "$USERNAME:$USER_PASS" | chpasswd || error_exit "Failed to set password"
echo "$USER_PASS" > "/root/$USERNAME-password.txt"
echo "Password saved to /root/$USERNAME-password.txt"

# Ensure public_html exists
WEB_ROOT="/home/$USERNAME/public_html"
mkdir -p "$WEB_ROOT"
chown -R "$USERNAME:$GROUPNAME" "/home/$USERNAME"
chmod 711 "/home/$USERNAME"
chmod 755 "$WEB_ROOT"

# Apache config
CONF_FILE="/etc/apache2/sites-available/$DOMAIN.conf"
status "Creating Apache virtual host configuration..."
echo "<VirtualHost *:80>
    ServerName $DOMAIN
    DocumentRoot $WEB_ROOT

    <Directory $WEB_ROOT>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
        DirectoryIndex index.php index.html
        <FilesMatch \\\.php$>
            SetHandler application/x-httpd-php
        </FilesMatch>
    </Directory>

    ErrorLog /var/log/apache2/${DOMAIN}_error.log
    CustomLog /var/log/apache2/${DOMAIN}_access.log combined
    RewriteEngine on
    RewriteCond %{HTTP_HOST} =$DOMAIN
    RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [END,NE,R=permanent]
</VirtualHost>" > "$CONF_FILE"

a2ensite "$DOMAIN"

# SSL Selection
echo "Select SSL certificate type:"
echo "  1) Snakeoil (self-signed)"
echo "  2) Let's Encrypt (recommended)"
read -rp "Enter 1 or 2: " SSL_CHOICE

if [[ "$SSL_CHOICE" == "2" ]]; then
    echo
    echo "🔐 Cloudflare Proxy Detection:"
    echo "  1) Manual — I will disable/enable it myself"
    echo "  2) Use Cloudflare API to check status"
    read -rp "Choose 1 or 2: " CLOUDFLARE_MODE

    if [[ "$CLOUDFLARE_MODE" == "2" ]]; then
        read -rp "Cloudflare Zone ID (from dashboard): " CF_ZONE
        read -rp "Cloudflare API Token (read permissions for DNS zone): " CF_TOKEN
        RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE/dns_records?name=$DOMAIN" \
            -H "Authorization: Bearer $CF_TOKEN" -H "Content-Type: application/json" | jq -r '.result[0].id')

        PROXY_STATUS=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE/dns_records/$RECORD_ID" \
            -H "Authorization: Bearer $CF_TOKEN" -H "Content-Type: application/json" | jq -r '.result.proxied')

        if [[ "$PROXY_STATUS" == "true" ]]; then
            echo "⚠️ Cloudflare proxy is ENABLED for $DOMAIN (orange cloud ☁️)."
            read -rp "Disable proxy and continue? (y/N): " CF_CONTINUE
            [[ "$CF_CONTINUE" =~ ^[Yy]$ ]] || error_exit "Aborted. Disable the proxy first."
        else
            echo "✅ Cloudflare proxy is DISABLED for $DOMAIN."
        fi
    else
        echo "⚠️ Please DISABLE the Cloudflare proxy (orange cloud ☁️) for $DOMAIN now."
        read -rp "Continue once done? (y/N): " CF_MANUAL
        [[ "$CF_MANUAL" =~ ^[Yy]$ ]] || error_exit "Aborted. Please disable proxy and run again."
    fi

    apt install -y certbot python3-certbot-apache

    read -rp "Email for SSL renewal notices: " EMAIL

    IP=$(curl -s ifconfig.me)
    RESOLVED_IP=$(dig +short "$DOMAIN" | tail -n1)
    if [[ "$RESOLVED_IP" != "$IP" ]]; then
        echo "⚠️ Warning: $DOMAIN resolves to $RESOLVED_IP but server IP is $IP"
        read -rp "Proceed anyway? (y/N): " CONFIRM
        [[ "$CONFIRM" =~ ^[Yy]$ ]] || error_exit "Aborting due to DNS mismatch."
    fi

    apachectl configtest || error_exit "Apache configtest failed before Certbot"
    systemctl restart apache2 || error_exit "Apache restart failed before Certbot"

    while true; do
        echo "⏳ Waiting 60 seconds for DNS propagation before running Certbot..."
        for ((i=60; i>0; i--)); do
            echo -ne "  Continuing in $i seconds...\r"
            sleep 1
        done
        echo ""

        certbot --apache --agree-tos --email "$EMAIL" -d "$DOMAIN" && break

        echo "❌ Let's Encrypt failed. Try again? (y to retry / q to quit): "
        read -r ANSWER
        [[ "$ANSWER" == "q" || "$ANSWER" == "Q" ]] && error_exit "User aborted Certbot retry."
    done

    status "Let's Encrypt certificate installed"
    echo
    echo "🔐 Cloudflare SSL Settings:"
    echo "Now that your domain has a valid SSL certificate..."
    echo "➡️  Please go to your Cloudflare dashboard"
    echo "➡️  Navigate to: SSL/TLS > Overview"
    echo "➡️  Set SSL mode to: Full (Strict)"
    echo "❗ Using 'Flexible' SSL is insecure and will break HTTPS with this setup."
    read -rp "Press Enter once you have confirmed SSL mode is Full (Strict)..."
    echo "🔁 You may now RE-ENABLE the Cloudflare proxy for this domain (orange cloud ☁️)"
else
    if ! grep -q "<VirtualHost *:443>" "$CONF_FILE"; then
        echo "<VirtualHost *:443>
    ServerName $DOMAIN
    DocumentRoot $WEB_ROOT

    <Directory $WEB_ROOT>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
        DirectoryIndex index.php index.html
        <FilesMatch \\\.php$>
            SetHandler application/x-httpd-php
        </FilesMatch>
    </Directory>

    ErrorLog /var/log/apache2/${DOMAIN}_ssl_error.log
    CustomLog /var/log/apache2/${DOMAIN}_ssl_access.log combined

    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/ssl-cert-snakeoil.pem
    SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key
</VirtualHost>" >> "$CONF_FILE"
        status "Using self-signed Snakeoil certificate"
    else
        status "Skipped adding <VirtualHost *:443> because it already exists"
    fi
fi

# Validate Apache config before reload
apachectl configtest || error_exit "Apache configtest failed"
systemctl reload apache2 || error_exit "Apache reload failed"

# PHP self-test
INFO_FILE="$WEB_ROOT/info.php"
echo "<?php phpinfo(); ?>" > "$INFO_FILE"
chown "$USERNAME:$GROUPNAME" "$INFO_FILE"
chmod 644 "$INFO_FILE"
echo "PHP self-test created at https://$DOMAIN/info.php"
 

status "Setup complete."



# Git Repos - Public
read -rp "How many public Git repos to deploy? (0 for none): " PUBLIC_REPO_COUNT
[[ "$PUBLIC_REPO_COUNT" =~ ^[0-9]+$ ]] || error_exit "Invalid public repo count"

for ((i=1; i<=PUBLIC_REPO_COUNT; i++)); do
    read -rp "Public repo #$i URL: " URL
    [[ "$URL" =~ ^https?:// ]] || error_exit "Invalid URL"
    echo "Choose target directory:"
    echo "  1) /home/$USERNAME"
    echo "  2) /home/$USERNAME/public_html"
    read -rp "Enter 1 or 2: " TARGET_CHOICE
    [[ "$TARGET_CHOICE" =~ ^[12]$ ]] || error_exit "Invalid target"
    DEST_DIR="/home/$USERNAME"
    [[ "$TARGET_CHOICE" == "2" ]] && DEST_DIR+="/public_html"
    mkdir -p "$DEST_DIR"
    TMP_DIR=$(mktemp -d)
    git clone "$URL" "$TMP_DIR"
    rsync -a "$TMP_DIR"/ "$DEST_DIR"/ --ignore-existing
    rm -rf "$TMP_DIR"
    chown -R "$USERNAME:$GROUPNAME" "$DEST_DIR"
    status "Deployed repo $URL to $DEST_DIR"

done

# Git Repos - Private
read -rp "How many private Git repos to deploy? (0 for none): " PRIVATE_REPO_COUNT
[[ "$PRIVATE_REPO_COUNT" =~ ^[0-9]+$ ]] || error_exit "Invalid private repo count"

for ((i=1; i<=PRIVATE_REPO_COUNT; i++)); do
    read -rp "Private repo #$i URL: " URL
    [[ "$URL" =~ ^https?:// ]] || error_exit "Invalid URL"
    read -rp "GitHub token: " TOKEN
    [[ -n "$TOKEN" ]] || error_exit "Token required"
    echo "Choose target directory:"
    echo "  1) /home/$USERNAME"
    echo "  2) /home/$USERNAME/public_html"
    read -rp "Enter 1 or 2: " TARGET_CHOICE
    [[ "$TARGET_CHOICE" =~ ^[12]$ ]] || error_exit "Invalid target"
    DEST_DIR="/home/$USERNAME"
    [[ "$TARGET_CHOICE" == "2" ]] && DEST_DIR+="/public_html"
    mkdir -p "$DEST_DIR"
    TMP_DIR=$(mktemp -d)
    git clone "https://$TOKEN@${URL#https://}" "$TMP_DIR"
    rsync -a "$TMP_DIR"/ "$DEST_DIR"/ --ignore-existing
    rm -rf "$TMP_DIR"
    chown -R "$USERNAME:$GROUPNAME" "$DEST_DIR"
    chmod -R 755 "$DEST_DIR"
    status "Deployed private repo to $DEST_DIR"
done

    chmod 711 "/home/$USERNAME"

status "✅ Setup complete."


# Adminer Option
echo "Do you want to install Adminer?"
echo "  1) Yes"
echo "  2) No"
read -rp "Enter 1 or 2: " ADMINER_CHOICE

if [[ "$ADMINER_CHOICE" == "1" ]]; then
    ADMINER_DIR="$WEB_ROOT/adminer"
    mkdir -p "$ADMINER_DIR"
    chmod 755 "$ADMINER_DIR"
    curl -fsSL "https://www.adminer.org/latest-mysql-en.php" -o "$ADMINER_DIR/index.php" || error_exit "Failed to download Adminer"
    chown "$USERNAME:$GROUPNAME" "$ADMINER_DIR/index.php"
    chmod 640 "$ADMINER_DIR/index.php"
    echo "AuthType Basic" > "$ADMINER_DIR/.htaccess"
    echo "AuthName \"Restricted Adminer Access\"" >> "$ADMINER_DIR/.htaccess"
    echo "AuthUserFile /home/$USERNAME/.htpasswd-adminer" >> "$ADMINER_DIR/.htaccess"
    echo "Require valid-user" >> "$ADMINER_DIR/.htaccess"
    echo "php_flag engine off" >> "$ADMINER_DIR/.htaccess"
    chown "$USERNAME:$GROUPNAME" "$ADMINER_DIR/.htaccess"
    chmod 640 "$ADMINER_DIR/.htaccess"
    read -rp "Adminer username (default: adminer): " ADMINER_USER
    ADMINER_USER=${ADMINER_USER:-adminer}
    read -rp "Adminer password: " ADMINER_PASS
    [[ -n "$ADMINER_PASS" ]] || error_exit "Adminer password required"
    htpasswd -bc "/home/$USERNAME/.htpasswd-adminer" "$ADMINER_USER" "$ADMINER_PASS"
    chown "$USERNAME:$GROUPNAME" "/home/$USERNAME/.htpasswd-adminer"
    chmod 640 "/home/$USERNAME/.htpasswd-adminer"
    status "Adminer installed"
fi

systemctl reload apache2 || error_exit "Failed to reload Apache"

# Final notice
IP=$(curl -s ifconfig.me)
echo "✅ Setup complete!"
echo "🌐 Visit: https://$DOMAIN"
echo "🔐 User password saved to /root/$USERNAME-password.txt"
echo "🧪 PHP test page: https://$DOMAIN/info.php"
echo "⚠️ If you installed Adminer, access it at https://$DOMAIN/adminer/"
echo "📌 Remember to set your DNS A record for $DOMAIN to point to $IP"
echo "📌 TODO: sudo a2enmod rewrite"
echo "📌 TODO: sudo usermod -a -G $USERNAME www-data"
echo "📌 TODO: nano /home/$USERNAME/public_html/adminer/.htaccess ; # and remove the php_flag engine off if you use adminer"
echo "📖 For more info, check the README.md in your home directory."
