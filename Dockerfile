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

# Create necessary directories and config files
RUN mkdir -p /run/nginx /var/www/html

# Copy configuration files and scripts
ADD nginx.conf /etc/nginx/nginx.conf
ADD config/index.html /var/www/html/index.html
ADD config/logo.svg /var/www/html/

# Set environment variables for ports
ENV HTTP_PORT=80
ENV HTTPS_PORT=443

# Expose ports
EXPOSE 80 443

# Execute always through our entrypoint script
ADD entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

# Command that will be executed through our entrypoint
CMD ["nginx", "-g", "daemon off;"]
