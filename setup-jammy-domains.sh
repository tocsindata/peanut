#!/bin/bash
set -e 

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

# Define domains as an array
domains=(
    "snoopy.example.com"
    "woodstock.example.com"
)

# Enable Apache SSL module
a2enmod ssl || { echo "Failed to enable SSL module"; exit 1; }

for domain in "${domains[@]}"; do
    # Extract subdomain (e.g., "snoopy" from "snoopy.darkdomain.com" or "subdomain" from "subdomain.example.com")
    subdomain=${domain%%.*}  # Removes the longest match of .* from the end

    # Create group if it doesn't exist
    if ! getent group "$subdomain" >/dev/null; then
        groupadd "$subdomain" || { echo "Failed to create group $subdomain"; exit 1; }
    fi

    # Create user if it doesn't exist
    if ! id "$subdomain" >/dev/null 2>&1; then
        useradd -m -d "/home/$subdomain" -s /bin/bash -g "$subdomain" "$subdomain" || { echo "Failed to create user $subdomain"; exit 1; }
    fi

    # Generate and set random password
    pass=$(openssl rand -base64 12)
    echo "$subdomain:$pass" | chpasswd || { echo "Failed to set password for $subdomain"; exit 1; }
    echo "Password for $subdomain: $pass" > "/root/$subdomain-password.txt"

    # Set up home directory for web content
    mkdir -p "/home/$subdomain/public_html"
    chown -R "$subdomain:$subdomain" "/home/$subdomain"
    chmod -R 755 "/home/$subdomain"
    chown "$subdomain:$subdomain" "/home/$subdomain/public_html"
    chmod 755 "/home/$subdomain/public_html"

    # Create Apache2 virtual host configuration for both port 80 and 443
    cat <<EOF > "/etc/apache2/sites-available/$domain.conf"
<VirtualHost *:80>
    ServerName $domain
    DocumentRoot /home/$subdomain/public_html
    <Directory /home/$subdomain/public_html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>

<VirtualHost *:443>
    ServerName $domain
    DocumentRoot /home/$subdomain/public_html
    <Directory /home/$subdomain/public_html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/ssl-cert-snakeoil.pem
    SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key
</VirtualHost>
EOF

    # Enable the site
    a2ensite "$domain.conf" || { echo "Failed to enable site $domain"; exit 1; }
done

# Reload Apache2
systemctl reload apache2 || { echo "Failed to reload Apache2"; exit 1; }

echo "Setup complete. Passwords saved in /root for each subdomain."
