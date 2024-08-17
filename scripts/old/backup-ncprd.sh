#!/bin/bash

# Configuration variables
SFTP_USER="PrivSecShop"
SFTP_HOST="192.168.0.20"
SFTP_PORT=2222  # Correct SFTP port
SFTP_DIR="/homes/PrivSecShop/Backups/ncprd"  # Correct path
LOCAL_BACKUP_DIR="/backupsToDo/ncprd"

# Create log file if it doesn't exist
LOG_FILE="/var/log/backup.log"
touch $LOG_FILE

# Define constants for job logging
JOB_NAME="ncprd-daily-sftp-transfer"
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

# Initialize job log message
JOB_LOG_MESSAGE=""

# Log start of backup in log file
echo "$(date): [$JOB_NAME] Starting backup of files starting with 'backup_'." >> $LOG_FILE

# Change to the local backup directory
echo "$(date): [$JOB_NAME] Changing to directory $LOCAL_BACKUP_DIR." >> $LOG_FILE
cd $LOCAL_BACKUP_DIR
if [ $? -ne 0 ]; then
  echo "$(date): [$JOB_NAME] Failed to change directory to $LOCAL_BACKUP_DIR." >> $LOG_FILE
  log_entry "failure" "Failed to change directory to $LOCAL_BACKUP_DIR." 1
  exit 1
fi

# Debug: List files in the current directory
echo "$(date): [$JOB_NAME] Listing files in $LOCAL_BACKUP_DIR:" >> $LOG_FILE
ls -l >> $LOG_FILE

# Find and copy files starting with 'backup_' and modified today
TODAY_FILES=$(find $LOCAL_BACKUP_DIR -type f -name 'backup_*' -newermt $(date +%Y-%m-%d) ! -newermt $(date -d tomorrow +%Y-%m-%d))

if [ -n "$TODAY_FILES" ]; then
  for file in $TODAY_FILES; do
    echo "$(date): [$JOB_NAME] Starting to copy $file to SFTP server" >> $LOG_FILE

    scp -o StrictHostKeyChecking=no -i /root/.ssh/id_rsa -P $SFTP_PORT "$file" $SFTP_USER@$SFTP_HOST:$SFTP_DIR >> $LOG_FILE 2>&1

    if [ $? -eq 0 ]; then
      echo "$(date): [$JOB_NAME] Successfully copied $file to SFTP server" >> $LOG_FILE
      JOB_LOG_MESSAGE+="$file successfully copied; "
    else
      echo "$(date): [$JOB_NAME] Failed to copy $file" >> $LOG_FILE
      JOB_LOG_MESSAGE+="$file failed to copy; "
      log_entry "failure" "$JOB_LOG_MESSAGE" $?
      exit $?
    fi
  done
  JOB_LOG_MESSAGE="Backup successful: $JOB_LOG_MESSAGE"
else
  echo "$(date): [$JOB_NAME] No files starting with 'backup_' to backup today." >> $LOG_FILE
  JOB_LOG_MESSAGE="No files to backup."
fi

# Log job summary
log_entry "success" "$JOB_LOG_MESSAGE" 0

# Print completion message
echo "Transfer completed successfully on $DATE."

