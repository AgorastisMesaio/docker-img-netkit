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

# If the html directory is mounted, it means user has mounted some content in it.
# In that case, we must not over-write the index.html file.
if [ -z "${WEB_ROOT_MOUNT_CHECK}" ] ; then
  echo "The directory ${WEB_ROOT} is not mounted."
  echo "Therefore, over-writing the default index.html file with some useful information:"

  # The 'ip -j route' shows JSON output, and always shows the default route as the first entry.
  # It also shows the correct device name as 'prefsrc', with correct IP address.
  CONTAINER_IP=$(ip -j route get 1 | jq -r '.[0] .prefsrc')

  # Logo
  if [ -f ${CONFIG_ROOT}/logo.svg ]; then
    cp ${CONFIG_ROOT}/logo.svg ${WEB_ROOT}/logo.svg
  fi

  # Company's default index.html
  cat << EOF > ${WEB_ROOT}/index.html
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to ${COMPANY}</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background-color: #f4f4f4;
            color: #333;
            text-align: center;
            margin: 0;
            padding: 0;
        }
        .container {
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        h1 {
            color: #0056b3;
        }
        p {
            font-size: 1.2em;
        }
        .info {
            margin-top: 20px;
            background: #fff;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 0 10px rgba(0, 0, 0, 0.1);
            display: inline-block;
        }
        .info p {
            margin: 5px 0;
        }
        .frame {
            width: 80%;
            border: 2px solid #000;
            background-color: #f0f0f0;
            padding: 10px;
            margin: 20px 0;
        }
        iframe {
            width: 100%;
            border: none;
        }
    </style>
</head>
<body>
    <div class="container">
        <img src="logo.svg" alt="Company Logo" class="logo"/>
        <h1>Welcome to ${COMPANY}'s NetKit Container</h1>
        <p>If you see this page, the web server is successfully installed and working.</p>
        <div class="info">
            <p><strong>My hostname (IP):</strong> ${HOSTNAME} (${CONTAINER_IP})</p>
            <p><strong>My http/https ports:</strong> ${HTTP_PORT:-80}/${HTTPS_PORT:-443}</p>
        </div>
        <div class="frame">
            <iframe src="table.html" id="contentFrame" onload="resizeIframe(this)"></iframe>
        </div>
    </div>
    <script>
        function resizeIframe(iframe) {
            iframe.style.height = iframe.contentWindow.document.documentElement.scrollHeight + 'px';
        }
    </script>
</body>
</html>
EOF

  # Useful Links
  if [ -f ${CONFIG_ROOT}/links.csv ]; then
    CSV_FILE=${CONFIG_ROOT}/links.csv
    echo "Using ${CSV_FILE} to populate index.html!!"
    /htmlgenerator.sh ${CSV_FILE}
    mv table.html /var/www/html
  fi

else
  # Inform only
  echo "The directory ${WEB_ROOT} is a volume mount."
  echo "Therefore, will not over-write index.html"
  echo "Only logging the container characteristics:"
  echo -e "Company Netkit - ${HOSTNAME} - ${CONTAINER_IP} - HTTP: ${HTTP_PORT:-80} , HTTPS: ${HTTPS_PORT:-443}"
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
echo $NETKIT_PASS
echo "root:${ROOT_PASS}" | chpasswd
echo "netkit:${NETKIT_PASS}" | chpasswd

# Start SSH server
/usr/sbin/sshd

# Run nginx
exec "$@"
