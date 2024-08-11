#!/usr/bin/env bash

# Functions
curl_test() {
    MSG=$1
    ERR=$2
    URL=$3
    # Test gc_connections, HTTP port 9090
    echo -n ${MSG}
    http_code=`curl -o /dev/null -s -w "%{http_code}\n" ${URL}`
    ret=$?
    if [ "${ret}" != 0 ]; then
        echo " - ${ERR}, return code: ${ret}"
        return ${ret}
    else
        if [ "${http_code}" != 200 ]; then
            echo " - ${ERR}, HTTP code: ${http_code}"
            return 1
        fi
    fi
    return 0
}

# Test SSH, port 22
echo -n "Test ssh"
export ERR_MSG="Error testing SSH ${HOSTNAME}:22"
/usr/bin/nc -w 3 -z ${HOSTNAME} 22 > /dev/null 2>&1 || { ret=${?}; echo " - ${ERR_MSG}, return code: ${ret}"; exit ${ret}; }
echo " Ok."

# Test nginx, HTTP port 80
curl_test "Test nginx http" "Error testing ${HOSTNAME}:80" "http://${HOSTNAME}:80" || { ret=${?}; exit ${ret}; }
echo " Ok."

# Test nginx, HTTPS port 443
echo -n "Test nginx https "
export ERR_MSG="Error testing ${HOSTNAME}:443"
echo "GET / HTTP/1.0" | openssl s_client -connect ${HOSTNAME}:443 > /dev/null 2>&1 || { ret=${?}; echo " - ${ERR_MSG}, return code: ${ret}" ; exit ${ret}; }
echo "Ok."

# Test gc_connections, HTTP port 9090
curl_test "Test gc_connections service" "Error testing ${HOSTNAME}:9090" "http://${HOSTNAME}:9090" || { ret=${?}; exit ${ret}; }
echo "Ok."

# All passed
exit 0
