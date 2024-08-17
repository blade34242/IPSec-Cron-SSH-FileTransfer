FROM debian:latest

# Install necessary packages
#RUN apt-get update && apt-get install -y cron vpnc iproute2 curl procps openssh-client

# Install vpnc and other necessary utilities
RUN apt-get update && apt-get install -y \
    vpnc \
    iproute2 \
    iputils-ping \
    iptables \
    net-tools \
    less \
    nano \
    vim \
    procps \
    netcat-openbsd \
    dnsutils \
    cron \
    curl \
    openssh-client


# Ensure vpnc-script is in the right place
RUN ln -s /usr/share/vpnc-scripts/vpnc-script /etc/vpnc/vpnc-script

# Set the timezone
ENV TZ=Europe/Zurich
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone


# Create the log files to be able to run tail
RUN touch /var/log/transfer-backups-sftp.log 

# Copy VPN configuration file
COPY fritzbox.conf /etc/vpnc/fritzbox.conf

# Add a script to start the VPN and other necessary services
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# Copy any scripts you want to run via cron
COPY scripts/ /usr/local/scripts/
RUN chmod +x /usr/local/scripts/*



# Run the command on container startup
CMD /usr/local/bin/start.sh

