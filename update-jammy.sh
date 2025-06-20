#!/bin/bash

# === SETTINGS ===
SEND_EMAIL=true          # Set to true to enable email notification
EMAIL_TO="admin@example.com"
EMAIL_SUBJECT="Ubuntu Reboot Notification"
EMAIL_BODY="System rebooting after kernel update on $(hostname) at $(date)."

SEND_SLACK=true          # Set to true to enable Slack notification
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/your/webhook/url"
SLACK_MESSAGE="⚠️ *$(hostname)* will reboot in 1 minute due to a kernel update. $(date)"

LOG_DIR="/var/log/update-ubuntu"
RETENTION_DAYS=30

# === SCRIPT START ===

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit 1
fi

# Check required commands
check_command() {
  command -v "$1" >/dev/null 2>&1
}

if [ "$SEND_EMAIL" = true ] && ! check_command mail; then
  echo "⚠️  'mail' command not found. Disabling email notifications."
  SEND_EMAIL=false
fi

if [ "$SEND_SLACK" = true ] && ! check_command curl; then
  echo "⚠️  'curl' command not found. Disabling Slack notifications."
  SEND_SLACK=false
fi

# Create log dir and file
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/update-$(date +'%Y-%m-%d_%H-%M-%S').log"

CURRENT_KERNEL=$(uname -r)

{
  echo "=== System Update Started: $(date) ==="

  echo "Updating package list..."
  apt update

  echo "Upgrading installed packages..."
  apt upgrade -y

  echo "Performing distribution upgrade..."
  apt dist-upgrade -y

  echo "Removing unnecessary packages..."
  apt autoremove -y

  echo "Cleaning up package cache..."
  apt clean

  echo "Checking for kernel update..."
  NEW_KERNEL=$(dpkg -l | grep linux-image | awk '{print $2}' | sort | tail -n 1)

  if [[ "$NEW_KERNEL" != *"$CURRENT_KERNEL"* ]]; then
    echo "Kernel updated from $CURRENT_KERNEL to $NEW_KERNEL"
    
    if [ "$SEND_EMAIL" = true ]; then
      echo "$EMAIL_BODY" | mail -s "$EMAIL_SUBJECT" "$EMAIL_TO" && \
      echo "Email notification sent to $EMAIL_TO" || \
      echo "⚠️  Failed to send email notification."
    fi

    if [ "$SEND_SLACK" = true ]; then
      curl -s -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"$SLACK_MESSAGE\"}" "$SLACK_WEBHOOK_URL" && \
      echo "Slack notification sent." || \
      echo "⚠️  Failed to send Slack notification."
    fi

    echo "System will reboot in 1 minute..."
    shutdown -r +1 "Rebooting to apply kernel update"
  else
    echo "No kernel update detected. No reboot necessary."
  fi

  echo "Cleaning logs older than $RETENTION_DAYS days..."
  find "$LOG_DIR" -type f -mtime +$RETENTION_DAYS -name "*.log" -exec rm -f {} \;

  echo "=== System Update Complete: $(date) ==="

} | tee "$LOG_FILE"
