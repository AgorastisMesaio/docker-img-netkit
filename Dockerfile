# Dockerfile for NetKit
#
# Compile a small Go program that will create a list of discovered links
#
FROM golang:alpine AS build
WORKDIR /var/www/goapp
COPY config/gc_connections/. .
RUN mkdir /var/www/goapp/static
COPY config/logo.svg /var/www/goapp/static
RUN go mod init gc_connections
RUN go mod tidy
RUN go build -o /go/bin/gc_connections

# This Dockerfile sets up a minimal Alpine Linux container with multiple networking tools
# and an Nginx web server, designed for network testing and diagnostics.
#
FROM alpine:latest

LABEL org.opencontainers.image.authors="Agorastis Mesaio"

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
    go \
    docker \
    htop \
    && rm -rf /var/cache/apk/*

# Rewrite the motd
RUN echo "Welcome to Netkit!" > /etc/motd

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

# Create a 'admin' user and assign to the sudo group
RUN adduser -D -s /bin/bash admin && adduser admin wheel

# Allow the 'admin' user to execute sudo commands without a password
RUN echo 'admin ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# In parallel su must be suid to work properly
RUN chmod u+s /bin/su

# Create necessary directories and config files
RUN mkdir -p /run/nginx /var/www/html

# Copy configuration files and scripts
ADD nginx.conf /etc/nginx/nginx.conf
ADD index.html /var/www/html/index.html

# Set environment variables for ports
ENV HTTP_PORT=80
ENV HTTPS_PORT=443

# Generate SSH key pair for 'admin' user
USER admin
RUN mkdir /home/admin/.nano
RUN mkdir -p /home/admin/.ssh && \
    ssh-keygen -t ed25519 -f /home/admin/.ssh/id_ed25519 -N "" && \
    cat /home/admin/.ssh/id_ed25519.pub > /home/admin/.ssh/authorized_keys && \
    chmod 600 /home/admin/.ssh/id_ed25519 && \
    chmod 644 /home/admin/.ssh/id_ed25519.pub && \
    chmod 700 /home/admin/.ssh && \
    chmod 644 /home/admin/.ssh/authorized_keys

# Switch back to root for further configurations
USER root

# Install the small Go app
COPY --from=build /var/www/goapp /var/www/goapp
COPY --from=build /go/bin/gc_connections /var/www/goapp

# Configure SSHD
RUN echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "AllowUsers root admin" >> /etc/ssh/sshd_config

# Copy entrypoint
ADD entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Copy healthcheck
ADD healthcheck.sh /healthcheck.sh
RUN chmod +x /healthcheck.sh

# My custom health check
# I'm calling /healthcheck.sh so my container will report 'healthy' instead of running
# --interval=30s: Docker will run the health check every 'interval'
# --timeout=10s: Wait 'timeout' for the health check to succeed.
# --start-period=3s: Wait time before first check. Gives the container some time to start up.
# --retries=3: Retry check 'retries' times before considering the container as unhealthy.
HEALTHCHECK --interval=30s --timeout=10s --start-period=3s --retries=3 \
  CMD /healthcheck.sh || exit $?

# Expose my ports
# 22   ssh port
# 80   http port to nginx
# 443  https port to nginx (self certificate)
# 9090 gc_connections
EXPOSE 22 80 443 9090

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]

# The CMD line represent the Arguments that will be passed to the
# /entrypoint.sh. We'll use them to indicate the script what
# command will be executed through our entrypoint when it finishes
CMD ["nginx", "-g", "daemon off;"]

