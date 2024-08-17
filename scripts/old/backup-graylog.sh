#!/bin/bash

# Configuration variables
SFTP_USER="PrivSecShop"
SFTP_HOST="192.168.0.20"
SFTP_PORT=2222  # Correct SFTP port
SFTP_DIR="/homes/PrivSecShop/Backups/graylog"  # Correct path
LOCAL_BACKUP_DIR="/backupsToDo/graylog"
LOG_FILE="/var/log/backup.log"

# Create log file if it doesn't exist
touch $LOG_FILE

# Define constants for job logging
JOB_NAME="graylog-daily-sftp-transfer"
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

# Log start of file transfer
echo "$(date): Starting file transfer to SFTP server." >> $LOG_FILE

# Get current date
DATE=$(date +"%Y-%m-%d")

# Compress all backup files into one tar file
TAR_FILE="/tmp/graylog_backup_$DATE.tar.gz"
echo "$(date): Creating tar file $TAR_FILE with today's backups." >> $LOG_FILE
cd $LOCAL_BACKUP_DIR
tar -czf $TAR_FILE *_backup_$DATE* >> $LOG_FILE 2>&1
if [ $? -ne 0 ]; then
  echo "$(date): Failed to create tar file." >> $LOG_FILE
  log_entry "failure" "Failed to create tar file." 1
  exit 1
fi

# Transfer the tar file to the SFTP server
echo "$(date): Starting to copy $TAR_FILE to SFTP server" >> $LOG_FILE
scp -o StrictHostKeyChecking=no -i /root/.ssh/id_rsa -P $SFTP_PORT "$TAR_FILE" $SFTP_USER@$SFTP_HOST:$SFTP_DIR >> $LOG_FILE 2>&1

if [ $? -eq 0 ]; then
  echo "$(date): Successfully copied $TAR_FILE to SFTP server" >> $LOG_FILE
  JOB_LOG_MESSAGE+="$TAR_FILE successfully copied; "
else
  echo "$(date): Failed to copy $TAR_FILE" >> $LOG_FILE
  JOB_LOG_MESSAGE+="Failed to copy $TAR_FILE; "
  log_entry "failure" "$JOB_LOG_MESSAGE" $?
  exit $?
fi

# Cleanup
echo "$(date): Cleaning up local tar file $TAR_FILE." >> $LOG_FILE
rm $TAR_FILE

# Log job summary
log_entry "success" "$JOB_LOG_MESSAGE" 0

# Print completion message
echo "Transfer completed successfully on $DATE."

