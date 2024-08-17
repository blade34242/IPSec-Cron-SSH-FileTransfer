#!/bin/bash

# Configuration variables
CONFIG_FILE="/usr/local/scripts/backup_config.conf"
LOG_FILE="/var/log/backup_debug.log"

# Create log file if it doesn't exist
touch $LOG_FILE

# Log the start of the script
echo "$(date): Script started" >> $LOG_FILE

# Function to process each backup configuration
process_backup() {
  local job_name=$1
  local local_backup_dir=$2

  START_TIME=$(date +"%Y-%m-%dT%H:%M:%S%z")

  echo "$(date): Starting backup job $job_name." >> $LOG_FILE

  # Find the latest backup files with today's date in the name
  TODAY_DATE=$(date +"%Y-%m-%d")
  echo "$(date): TODAY_DATE is $TODAY_DATE" >> $LOG_FILE
  echo "$(date): Listing contents of $local_backup_dir" >> $LOG_FILE
  ls -l "$local_backup_dir" >> $LOG_FILE

  echo "$(date): Looking for files with pattern *_${TODAY_DATE}* in $local_backup_dir" >> $LOG_FILE
  TODAY_FILES=$(find "$local_backup_dir" -type f -name "*_${TODAY_DATE}*")
  echo "$(date): find command returned: $TODAY_FILES" >> $LOG_FILE

  if [ -n "$TODAY_FILES" ]; then
    echo "$(date): Found files: $TODAY_FILES" >> $LOG_FILE
  else
    echo "$(date): No backup files found for today in $local_backup_dir." >> $LOG_FILE
  fi
}

# Read and process each backup configuration
if [ ! -f "$CONFIG_FILE" ]; then
  echo "$(date): Error: Configuration file not found at $CONFIG_FILE" >> $LOG_FILE
  exit 1
fi

echo "$(date): Reading configuration file $CONFIG_FILE" >> $LOG_FILE

while IFS= read -r line; do
  if [[ $line =~ ^\[(.*)\] ]]; then
    SECTION="${BASH_REMATCH[1]}"
  elif [[ $line =~ ^job_name\ *=\ *(.*) ]]; then
    JOB_NAME="${BASH_REMATCH[1]}"
  elif [[ $line =~ ^local_backup_dir\ *=\ *(.*) ]]; then
    LOCAL_BACKUP_DIR="${BASH_REMATCH[1]}"
    process_backup "$JOB_NAME" "$LOCAL_BACKUP_DIR"
  fi
done < "$CONFIG_FILE"

echo "$(date): Script completed" >> $LOG_FILE

