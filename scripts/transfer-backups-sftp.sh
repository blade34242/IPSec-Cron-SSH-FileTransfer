#!/bin/bash

# SFTP Configuration
SFTP_USER="PrivSecShop"
SFTP_HOST="192.168.0.20"
SFTP_PORT=2222  # Correct SFTP port

# Configuration variables
CONFIG_FILE="/usr/local/scripts/backup_config.conf"
LOG_FILE="/var/log/transfer-backups-sftp.log"
touch $LOG_FILE

# Function to log entry
log_entry() {
  local job_name=$1
  local status=$2
  local message=$3
  local exit_code=$4
  local start_time=$5

  local END_TIME=$(date +"%Y-%m-%dT%H:%M:%S%z")
  local DURATION=$(date -d @$(( $(date -d "$END_TIME" +%s) - $(date -d "$start_time" +%s) )) -u +'%H:%M:%S')

  local ESCAPED_MESSAGE=$(echo "$message" | tr -d '\n' | sed 's/"/\\"/g')

  local LOG_ENTRY=$(cat <<EOF
{"timestamp":"$start_time","job_name":"$job_name","status":"$status","duration":"$DURATION","message":"$ESCAPED_MESSAGE","host":"$HOSTNAME","exit_code":$exit_code}
EOF
)
  echo "$LOG_ENTRY" | tr -d '\n' >> "$LOG_FILE"
  echo "" >> "$LOG_FILE"
}

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
      log_entry "VPN Connection" "failure" "VPN connection failed - IP $VPN_IP not found after retry." 1 "$(date +"%Y-%m-%dT%H:%M:%S%z")"
      exit 1
    fi
  fi
}

process_backup() {
  local job_name=$1
  local local_backup_dir=$2
  local target_sftp_dir=$3
  local start_time=$(date +"%Y-%m-%dT%H:%M:%S%z")
  local date=$(date +"%Y-%m-%d")

  echo "$(date): Starting backup job $job_name." >> $LOG_FILE
  echo "$(date): TODAY_DATE is $date" >> $LOG_FILE

  # Find files matching the pattern
  backup_files=$(find "$local_backup_dir" -type f -name "*_${date}*")

  if [ -z "$backup_files" ]; then
    echo "$(date): No backup files found for today in $local_backup_dir." >> $LOG_FILE
    log_entry "$job_name" "failure" "No backup files found for today." 1 "$start_time"
    return 1
  fi

  local job_log_message=""

  for file in $backup_files; do
    echo "$(date): Starting to copy $file to SFTP server" >> $LOG_FILE
    scp -o StrictHostKeyChecking=no -i /root/.ssh/id_rsa -P $SFTP_PORT "$file" $SFTP_USER@$SFTP_HOST:$target_sftp_dir >> $LOG_FILE 2>&1

    if [ $? -eq 0 ]; then
      echo "$(date): Successfully copied $file to SFTP server" >> $LOG_FILE
      job_log_message+="$file successfully copied; "
    else
      echo "$(date): Failed to copy $file" >> $LOG_FILE
      job_log_message+="Failed to copy $file; "
    fi
  done

  if [[ $job_log_message == *"Failed to copy"* ]]; then
    log_entry "$job_name" "failure" "$job_log_message" 1 "$start_time"
  else
    log_entry "$job_name" "success" "$job_log_message" 0 "$start_time"
  fi

  echo "Transfer completed for $job_name on $date." >> $LOG_FILE
}

if [ ! -f "$CONFIG_FILE" ]; then
  echo "$(date): Error: Configuration file not found at $CONFIG_FILE" >> $LOG_FILE
  exit 1
fi

echo "$(date): Reading configuration file $CONFIG_FILE" >> $LOG_FILE

while IFS= read -r line || [ -n "$line" ]; do
  echo "$(date): Processing line: $line" >> $LOG_FILE
  if [[ $line =~ ^\[(.*)\] ]]; then
    SECTION="${BASH_REMATCH[1]}"
    echo "$(date): Found section $SECTION" >> $LOG_FILE
  elif [[ $line =~ ^job_name\ *=\ *(.*) ]]; then
    JOB_NAME="${BASH_REMATCH[1]}"
    echo "$(date): Found job_name $JOB_NAME" >> $LOG_FILE
  elif [[ $line =~ ^local_backup_dir\ *=\ *(.*) ]]; then
    LOCAL_BACKUP_DIR="${BASH_REMATCH[1]}"
    echo "$(date): Found local_backup_dir $LOCAL_BACKUP_DIR" >> $LOG_FILE
  elif [[ $line =~ ^target_sftp_dir\ *=\ *(.*) ]]; then
    TARGET_SFTP_DIR="${BASH_REMATCH[1]}"
    echo "$(date): Found target_sftp_dir $TARGET_SFTP_DIR" >> $LOG_FILE
    check_vpn_connection
    process_backup "$JOB_NAME" "$LOCAL_BACKUP_DIR" "$TARGET_SFTP_DIR"
  elif [[ $line =~ ^\s*$ ]]; then
    # Skip empty lines
    continue
  fi
done < "$CONFIG_FILE"

echo "$(date): Script completed" >> $LOG_FILE

