#!/bin/bash
set -e

# === Config ===
APACHE_CONF_DIR="/etc/apache2/sites-available"
ADMINER_PASS_FILE_NAME=".htpasswd-adminer"

# === Functions ===

function error_exit {
    echo "❌ $1"
    exit 1
}

function list_domains {
    echo "Available Apache Virtual Hosts:"
    for conf in "$APACHE_CONF_DIR"/*.conf; do
        [[ -f "$conf" ]] || continue
        domain=$(basename "${conf%.conf}")
        echo "  - $domain"
    done
    exit 0
}

function prompt_domain_selection {
    echo "Available domains:"
    for i in "${!available_sites[@]}"; do
        printf "  [%d] %s\n" "$i" "${available_sites[$i]}"
    done
    echo ""
    read -rp "Enter number(s) to remove (e.g. 0 2), or 'a' for all: " selection

    selected_domains=()
    if [[ "$selection" == "a" ]]; then
        selected_domains=("${available_sites[@]}")
    else
        for index in $selection; do
            if [[ "$index" =~ ^[0-9]+$ ]] && (( index >= 0 && index < ${#available_sites[@]} )); then
                selected_domains+=("${available_sites[$index]}")
            else
                error_exit "Invalid selection: $index"
            fi
        done
    fi
}

function show_plan {
    echo ""
    echo "📝 The following actions would be taken:"
    for domain in "${selected_domains[@]}"; do
        subdomain="${domain%%.*}"
        echo "--------------------------"
        echo "Domain: $domain"
        echo "  Apache conf: $APACHE_CONF_DIR/$domain.conf"
        echo "  Password file: /root/$subdomain-password.txt"
        echo "  Adminer .htpasswd: /home/$subdomain/$ADMINER_PASS_FILE_NAME"
        echo "  User account: $subdomain"
        echo "  Group: $subdomain"
        echo "  Home: /home/$subdomain"
    done
    echo "--------------------------"
}

function delete_domain {
    local domain=$1
    local subdomain="${domain%%.*}"

    echo "→ Removing domain: $domain"

    # Apache config
    if [ -f "$APACHE_CONF_DIR/$domain.conf" ]; then
        $dry_run a2dissite "$domain.conf" >/dev/null 2>&1 || true
        $dry_run rm -f "$APACHE_CONF_DIR/$domain.conf"
        echo "  ✔ Apache config removed"
    fi

    # Password file
    [ -f "/root/$subdomain-password.txt" ] && $dry_run rm -f "/root/$subdomain-password.txt" && echo "  ✔ Password file removed"

    # Adminer .htpasswd
    [ -f "/home/$subdomain/$ADMINER_PASS_FILE_NAME" ] && $dry_run rm -f "/home/$subdomain/$ADMINER_PASS_FILE_NAME" && echo "  ✔ Adminer .htpasswd removed"

    # User + Home
    if id "$subdomain" >/dev/null 2>&1; then
        $dry_run userdel -r "$subdomain" 2>/dev/null || echo "  ⚠️ Could not fully remove home"
        echo "  ✔ User removed"
    fi

    # Group
    if getent group "$subdomain" >/dev/null 2>&1; then
        $dry_run groupdel "$subdomain"
        echo "  ✔ Group removed"
    fi
}

# === CLI Args ===
MODE="delete"
dry_run=""

for arg in "$@"; do
    case "$arg" in
        --list)
            list_domains
            ;;
        --dry-run)
            dry_run="echo [DRY-RUN]"
            MODE="dry-run"
            ;;
        *)
            echo "Usage: $0 [--list] [--dry-run]"
            exit 1
            ;;
    esac
done

# === Root Check ===
if [[ $EUID -ne 0 ]]; then
    error_exit "This script must be run as root"
fi

# === Load Apache domains ===
available_sites=()
for conf in "$APACHE_CONF_DIR"/*.conf; do
    [[ -f "$conf" ]] || continue
    domain=$(basename "${conf%.conf}")
    available_sites+=("$domain")
done

if [[ ${#available_sites[@]} -eq 0 ]]; then
    echo "No virtual hosts found in $APACHE_CONF_DIR"
    exit 0
fi

# === Prompt selection ===
prompt_domain_selection
show_plan

if [[ "$MODE" == "dry-run" ]]; then
    echo "✅ Dry-run complete (no changes made)"
    exit 0
fi

# === Confirm and execute ===
echo ""
read -rp "Proceed with deletion? (y/n): " confirm
if [[ "$confirm" != "y" ]]; then
    echo "Aborted."
    exit 0
fi

for domain in "${selected_domains[@]}"; do
    delete_domain "$domain"
done

# Reload Apache
$dry_run systemctl reload apache2
echo ""
echo "✅ Cleanup complete."
