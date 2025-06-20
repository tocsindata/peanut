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

# Check if Apache2 is installed
if ! command -v apache2ctl >/dev/null 2>&1; then
    echo "Apache2 is not installed. Skipping Apache-related cleanup."
    apache_installed=false
else
    apache_installed=true
fi

for domain in "${domains[@]}"; do
    # Extract subdomain (e.g., "snoopy" from "snoopy.something.com" or "subdomain" from "subdomain.example.com")
    subdomain=${domain%%.*}  # Removes the longest match of .* from the end

    # Disable and remove Apache virtual host configuration
    if [ "$apache_installed" = true ]; then
        if [ -f "/etc/apache2/sites-available/$domain.conf" ]; then
            a2dissite "$domain.conf" >/dev/null 2>&1 || { echo "Failed to disable site $domain"; exit 1; }
            rm -f "/etc/apache2/sites-available/$domain.conf" || { echo "Failed to remove $domain.conf"; exit 1; }
            echo "Removed Apache virtual host for $domain"
        else
            echo "No Apache virtual host found for $domain"
        fi
    fi

    # Remove password file
    if [ -f "/root/$subdomain-password.txt" ]; then
        rm -f "/root/$subdomain-password.txt" || { echo "Failed to remove password file for $subdomain"; exit 1; }
        echo "Removed password file for $subdomain"
    else
        echo "No password file found for $subdomain"
    fi

    # Remove user and home directory
    if id "$subdomain" >/dev/null 2>&1; then
        userdel -r "$subdomain" || { echo "Failed to remove user $subdomain"; exit 1; }
        echo "Removed user $subdomain and home directory"
    else
        echo "User $subdomain does not exist"
    fi

    # Remove group
    if getent group "$subdomain" >/dev/null; then
        groupdel "$subdomain" || { echo "Failed to remove group $subdomain"; exit 1; }
        echo "Removed group $subdomain"
    else
        echo "Group $subdomain does not exist"
    fi
done

# Reload Apache2 if installed
if [ "$apache_installed" = true ]; then
    systemctl reload apache2 || { echo "Failed to reload Apache2"; exit 1; }
    echo "Apache2 reloaded"
fi

echo "Cleanup complete for all specified domains."
