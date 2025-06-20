#!/bin/bash

# Configurable variables
CHOWN_USER="snoopy"              # Username for chown
CHOWN_GROUP="snoopy"             # Group for chown
INSTALL_PATH="/home/snoopy/public_html/adminer/index.php"  # Path where Adminer will be installed
HTPASSWD_PASSWORD="abc123"      # Password for .htaccess authentication
HTPASSWD_USER="adminer_user"    # Username for .htaccess authentication (change if needed)

# Ensure required tools are installed
command -v curl >/dev/null 2>&1 || { echo "curl is required but not installed. Exiting."; exit 1; }
command -v htpasswd >/dev/null 2>&1 || { echo "htpasswd is required but not installed. Install apache2-utils. Exiting."; exit 1; }

# Get the latest release version from GitHub
LATEST_VERSION=$(curl -s https://api.github.com/repos/vrana/adminer/releases/latest | grep 'tag_name' | cut -d'"' -f4)

if [ -z "$LATEST_VERSION" ]; then
    echo "Failed to fetch the latest Adminer version. Exiting."
    exit 1
fi

# Construct the download URL
DOWNLOAD_URL="https://github.com/vrana/adminer/releases/download/$LATEST_VERSION/adminer-$LATEST_VERSION-mysql-en.php"

# Create the directory for INSTALL_PATH if it doesn't exist
INSTALL_DIR=$(dirname "$INSTALL_PATH")
mkdir -p "$INSTALL_DIR"

# Download the latest Adminer file
echo "Downloading Adminer version $LATEST_VERSION from $DOWNLOAD_URL..."
curl -sL "$DOWNLOAD_URL" -o "$INSTALL_PATH"

# Check if the download was successful
if [ $? -ne 0 ] || [ ! -f "$INSTALL_PATH" ]; then
    echo "Failed to download Adminer. Exiting."
    exit 1
fi

# Set correct ownership
chown "$CHOWN_USER:$CHOWN_GROUP" "$INSTALL_PATH"
chmod 640 "$INSTALL_PATH"

# Create .htaccess file for HTTP Basic Authentication
HTACCESS_FILE="$INSTALL_DIR/.htaccess"
HTPASSWD_FILE="$INSTALL_DIR/.htpasswd"

cat > "$HTACCESS_FILE" <<EOF
AuthType Basic
AuthName "Restricted Adminer Access"
AuthUserFile $HTPASSWD_FILE
Require valid-user
EOF

# Create .htpasswd file with the specified user and password
htpasswd -bc "$HTPASSWD_FILE" "$HTPASSWD_USER" "$HTPASSWD_PASSWORD"

# Set correct ownership and permissions for .htaccess and .htpasswd
chown "$CHOWN_USER:$CHOWN_GROUP" "$HTACCESS_FILE" "$HTPASSWD_FILE"
chmod 640 "$HTACCESS_FILE" "$HTPASSWD_FILE"

# Verify Apache configuration (if applicable)
if [ -f "/etc/apache2/apache2.conf" ]; then
    echo "Ensuring .htaccess is enabled in Apache configuration..."
    # Check if AllowOverride is set to All in the directory context
    if ! grep -q "AllowOverride All" /etc/apache2/apache2.conf; then
        echo "Warning: Apache may not be configured to allow .htaccess files. Please ensure 'AllowOverride All' is set in your Apache configuration for $INSTALL_DIR."
    fi
fi

# Echo the results
echo "Adminer version $LATEST_VERSION installed successfully at $INSTALL_PATH"
echo "HTTP Basic Authentication set up with user '$HTPASSWD_USER' and password '$HTPASSWD_PASSWORD'"
echo "Access restricted via .htaccess in $INSTALL_DIR"
