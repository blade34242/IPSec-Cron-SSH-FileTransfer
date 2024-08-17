#!/bin/bash

# Configuration variables
SFTP_USER="PrivSecShop"
SFTP_HOST="192.168.0.20"
SFTP_PORT=2222  # Correct SFTP port
SFTP_DIR="/homes/PrivSecShop/Backups/wpprd"  # Correct path
LOCAL_BACKUP_DIR="/backupsToDo/wpvividbackups"

# Create log file if it doesn't exist
LOG_FILE="/var/log/backup.log"
touch $LOG_FILE

# Define constants for job logging
JOB_NAME="wpprd-daily-backup"
HOSTNAME=$(hostname)
START_TIME=$(date +"%Y-%m-%dT%H:%M:%S%z")

# Function to log entry
log_entry() {
  local status=$1
  local message=$2
  local exit_code=$3

  END_TIME=$(date +"%Y-%m-%dT%H:%M:%S%z")
  DURATION=$(date -d @$(( $(date -d "$END_TIME" +%s) - $(date -d "$START_TIME" +%s) )) -u +'%H:%M:%S')

  # Escape message and remove newlines using sed
  ESCAPED_MESSAGE=$(echo "$message" | tr -d '\n' | sed 's/"/\\"/g')

  LOG_ENTRY=$(cat <<EOF
{
  "timestamp": "$START_TIME",
  "job_name": "$JOB_NAME",
  "status": "$status",
  "duration": "$DURATION",
  "message": "$ESCAPED_MESSAGE",
  "host": "$HOSTNAME",
  "exit_code": $exit_code
}
EOF
)

  # Remove newlines from the log entry before writing
  echo "$LOG_ENTRY" | tr -d '\n' >> "$LOG_FILE"
  # Add a newline after each JSON object for readability
  echo "" >> "$LOG_FILE"
}

# Function to check and establish VPN connection
check_vpn_connection() {
  VPN_IP="192.168.0.202"
  if ip addr show | grep -q "$VPN_IP"; then
    echo "$(date): VPN connection established successfully with IP $VPN_IP." >> $LOG_FILE
  else
    echo "$(date): VPN connection not found. Attempting to establish VPN connection." >> $LOG_FILE
    # Start vpnc
    vpnc /etc/vpnc/fritzbox.conf >> $LOG_FILE 2>&1

    # Wait for a few seconds to allow VPN connection to establish
    sleep 10

    # Check again if VPN connection is established
    if ip addr show | grep -q "$VPN_IP"; then
      echo "$(date): VPN connection established successfully with IP $VPN_IP after retry." >> $LOG_FILE
    else
      echo "$(date): VPN connection failed - IP $VPN_IP not found after retry." >> $LOG_FILE
      log_entry "failure" "VPN connection failed - IP $VPN_IP not found after retry." 1
      exit 1
    fi
  fi
}

# Initialize job log message
JOB_LOG_MESSAGE=""

# Log start of backup in log file
echo "$(date): Starting backup of files modified today." >> $LOG_FILE

# Check and establish VPN connection
check_vpn_connection

# Find and copy files modified today and starting with privsec.ch_wpvivid
TODAY_FILES=$(find $LOCAL_BACKUP_DIR -type f -name 'privsec.ch_wpvivid*' -newermt $(date +%Y-%m-%d) ! -newermt $(date -d tomorrow +%Y-%m-%d))

if [ -n "$TODAY_FILES" ]; then
  for file in $TODAY_FILES; do
    echo "$(date): Starting to copy $file to SFTP server" >> $LOG_FILE

    scp -o StrictHostKeyChecking=no -i /root/.ssh/id_rsa -P $SFTP_PORT "$file" $SFTP_USER@$SFTP_HOST:$SFTP_DIR >> $LOG_FILE 2>&1

    if [ $? -eq 0 ]; then
      echo "$(date): Successfully copied $file to SFTP server" >> $LOG_FILE
      JOB_LOG_MESSAGE+="$file successfully copied; "
    else
      echo "$(date): Failed to copy $file" >> $LOG_FILE
      JOB_LOG_MESSAGE+="$file failed to copy; "
      log_entry "failure" "$JOB_LOG_MESSAGE" $?
      exit $?
    fi
  done
  JOB_LOG_MESSAGE="Backup successful: $JOB_LOG_MESSAGE"
else
  echo "$(date): No files modified today to backup." >> $LOG_FILE
  JOB_LOG_MESSAGE="No files to backup."
fi

# Log job summary
log_entry "success" "$JOB_LOG_MESSAGE" 0

