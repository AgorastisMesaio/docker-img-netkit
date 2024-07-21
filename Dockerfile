# Dockerfile for NetKit
#
# This Dockerfile sets up a minimal Alpine Linux container with multiple networking tools
# and an Nginx web server, designed for network testing and diagnostics.
#
FROM alpine:latest

LABEL org.opencontainers.image.authors="Luis Palacios Derqui"

# Install necessary tools
RUN apk update && apk add --no-cache \
    bash \
    sudo \
    nano \
    envsubst \
    nginx \
    openssl \
    curl \
    wget \
    bind-tools \
    iproute2 \
    iputils \
    net-tools \
    mtr \
    tcptraceroute \
    tcpdump \
    ethtool \
    mii-tool \
    traceroute \
    nmap \
    iperf3 \
    openssh \
    lftp \
    rsync \
    git \
    apache2-utils \
    mysql-client \
    postgresql-client \
    jq \
    netcat-openbsd \
    socat \
    tshark \
    vim \
    grep \
    sed \
    gawk \
    diffutils \
    findutils \
    coreutils \
    gzip \
    cpio \
    tar \
    openrc \
    && rm -rf /var/cache/apk/*

# Needed for our custom nanorc
ADD nanorc /etc/nanorc
RUN mkdir /root/.nano

# Create the /usr/bin/confcat file with heredocs
RUN cat <<'EOF' > /usr/bin/confcat
#!/bin/bash
#
# confcat: removes lines with comments, very useful as a substitute
# for the "cat" program when we want to see only the effective lines,
# not the lines that have comments.

grep -vh '^[[:space:]]*#' "$@" | grep -v '^//' | grep -v '^;' | grep -v '^$'
EOF

# Make the confcat file executable
RUN chmod +x /usr/bin/confcat

# Create the /usr/bin/e file with heredocs
RUN cat <<'EOF' > /usr/bin/e
#!/bin/bash
nano "${*}"
EOF

# Make the e file executable
RUN chmod +x /usr/bin/e

# Create a 'netkit' user and assign to the sudo group
RUN adduser -D -s /bin/bash netkit && adduser netkit wheel

# Allow the 'netkit' user to execute sudo commands without a password
RUN echo 'netkit ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# In parallel su must be suid to work properly
RUN chmod u+s /bin/su

# Create necessary directories and config files
RUN mkdir -p /run/nginx /var/www/html

# Copy configuration files and scripts
ADD nginx.conf /etc/nginx/nginx.conf
ADD config/index.html /var/www/html/index.html
ADD config/logo.svg /var/www/html/

# Set environment variables for ports
ENV HTTP_PORT=80
ENV HTTPS_PORT=443

# Generate SSH key pair for 'netkit' user
USER netkit
RUN mkdir /home/netkit/.nano
RUN mkdir -p /home/netkit/.ssh && \
    ssh-keygen -t ed25519 -f /home/netkit/.ssh/id_ed25519 -N "" && \
    cat /home/netkit/.ssh/id_ed25519.pub > /home/netkit/.ssh/authorized_keys && \
    chmod 600 /home/netkit/.ssh/id_ed25519 && \
    chmod 644 /home/netkit/.ssh/id_ed25519.pub && \
    chmod 700 /home/netkit/.ssh && \
    chmod 644 /home/netkit/.ssh/authorized_keys

# Switch back to root for further configurations
USER root

# Configure SSHD
RUN echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "AllowUsers root netkit" >> /etc/ssh/sshd_config

# Copy entrypoint script
ADD entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose necessary ports
EXPOSE 80 443 22

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]

# Command that will be executed through our entrypoint
CMD ["nginx", "-g", "daemon off;"]