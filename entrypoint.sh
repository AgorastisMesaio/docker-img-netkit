#!/usr/bin/env bash
#
# entrypoint.sh for NetKit
#
# Executed everytime the service is run
#
# This file is copied as /entrypoint.sh inside the container image.
#

# Variables
export CONFIG_ROOT=/config
CONFIG_ROOT_MOUNT_CHECK=$(mount | grep ${CONFIG_ROOT})
export WEB_ROOT=/var/www/html
WEB_ROOT_MOUNT_CHECK=$(mount | grep ${WEB_ROOT})
HOSTNAME=$(hostname)
COMPANY="${COMPANY_TITLE:-localhost}"
ROOT_PASS="${ROOT_PASSWORD:-password}"
NETKIT_PASS="${NETKIT_PASSWORD:-password}"

# Generate self-signed certificates if they don't exist
if [ ! -f /etc/nginx/ssl/nginx.crt ]; then
    echo "Generate self-signed certificates for nginx"
    mkdir -p /etc/nginx/ssl
    openssl req -x509 -nodes -days 7300 -newkey rsa:2048 -keyout /etc/nginx/ssl/nginx.key -out /etc/nginx/ssl/nginx.crt -subj "/CN=localhost" 2>/dev/null
fi

# Generate SSH host keys if they don't exist
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    ssh-keygen -A
fi

# Substitute environment variables in nginx configuration file
if [ -n "${HTTP_PORT}" ]; then
  echo "Replacing HTTP default port with HTTP_PORT: ${HTTP_PORT}."
  envsubst '${HTTP_PORT}' < /etc/nginx/nginx.conf > /etc/nginx/nginx.conf.tmp
  mv /etc/nginx/nginx.conf.tmp /etc/nginx/nginx.conf
fi
if [ -n "${HTTPS_PORT}" ]; then
  echo "Replacing HTTPS default port with HTTPS_PORT: ${HTTPS_PORT}."
  envsubst '${HTTPS_PORT}' < /etc/nginx/nginx.conf > /etc/nginx/nginx.conf.tmp
  mv /etc/nginx/nginx.conf.tmp /etc/nginx/nginx.conf
fi

#
echo "NGINX ready http://localhost:${HTTP_PORT}"
echo "NGINX ready https://localhost:${HTTPS_PORT}"

# Set password of root and netkit
echo "root:${ROOT_PASS}" | chpasswd
echo "netkit:${NETKIT_PASS}" | chpasswd

# Start SSH server
/usr/sbin/sshd

# Start custom script run.sh
if [ -f ${CONFIG_ROOT}/run.sh ]; then
    cp ${CONFIG_ROOT}/run.sh /run.sh
    chmod +x /run.sh
    /run.sh
fi

# Run the arguments from CMD in the Dockerfile
# In our case we are starting nginx by default
exec "$@"
