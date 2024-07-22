#!/usr/bin/env bash
#
echo == EXAMPLE of custom script ==================
echo Running ./config/run.sh custom script.
echo Modify this file to execute any custom script
echo ==============================================

# In this example we creata a more sophisticated
# /var/www/html/index.html file.

# Variables
export CONFIG_ROOT=/config
CONFIG_ROOT_MOUNT_CHECK=$(mount | grep ${CONFIG_ROOT})
export WEB_ROOT=/var/www/html
WEB_ROOT_MOUNT_CHECK=$(mount | grep ${WEB_ROOT})
HOSTNAME=$(hostname)
COMPANY="${COMPANY_TITLE:-localhost}"

# If the html directory is mounted, it means user has mounted some content in it.
# In that case, we must not over-write the index.html file.
# If not mounted then create a more sophisticated index.html
if [ -z "${WEB_ROOT_MOUNT_CHECK}" ] ; then
  echo "The directory ${WEB_ROOT} is not mounted."
  echo "Over-writing the default index.html"

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
    <title>Welcome to Netkit</title>
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
            padding: 10px;
        }
        .logo {
            margin: 5px auto;
            height: 90px;
        }
        h1 {
            color: #0056b3;
        }
        p {
            font-size: 1.0em;
        }
        .info {
            background: #fff;
            padding: 5px;
            border-radius: 5px;
            box-shadow: 0 0 5px rgba(0, 0, 0, 0.1);
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
            margin: 10px 0;
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
        <h2>${TITLE}</h2>
        <p>${SUBTITLE}</p>
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
    chmod +x ${CONFIG_ROOT}/htmlgenerator.sh
    . ${CONFIG_ROOT}/htmlgenerator.sh ${CONFIG_ROOT}/${CSV_FILE}
    mv table.html /var/www/html
  fi

else
  # Inform only
  echo "The directory ${WEB_ROOT} is a volume mount."
  echo "Therefore, will not over-write index.html"
  echo "Only logging the container characteristics:"
  echo -e "Company Netkit - ${HOSTNAME} - ${CONTAINER_IP} - HTTP: ${HTTP_PORT:-80} , HTTPS: ${HTTPS_PORT:-443}"
fi

