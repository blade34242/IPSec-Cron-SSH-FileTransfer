#!/bin/bash

LOG_FILE="/var/log/transfer-backups-sftp.log"

# Log the start of the script
echo "$(date): Starting start.sh script" >> $LOG_FILE

# Backup current DNS settings
echo "$(date): Backing up DNS settings" >> $LOG_FILE
cp /etc/resolv.conf /etc/resolv.conf.bak

# Start vpnc
echo "$(date): Starting vpnc" >> $LOG_FILE
vpnc /etc/vpnc/fritzbox.conf >> $LOG_FILE 2>&1

# Wait for VPN connection to establish by checking the VPN IP
VPN_IP="192.168.0.202"
while ! ip addr show | grep -q "$VPN_IP"; do
  echo "$(date): Waiting for VPN connection to be established..." >> $LOG_FILE
  sleep 2
done

echo "$(date): VPN connection established successfully with IP $VPN_IP." >> $LOG_FILE

# Run the backup script
echo "$(date): Starting backup process" >> $LOG_FILE
/usr/local/scripts/transfer-backups-sftp.sh >> $LOG_FILE 2>&1 &

# Restore DNS settings
# echo "$(date): Restoring DNS settings" >> $LOG_FILE
# cp /etc/resolv.conf.bak /etc/resolv.conf

# Tail the logs
tail -f $LOG_FILE

