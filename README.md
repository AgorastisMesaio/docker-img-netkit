# NetKit Container

![GitHub action workflow status](https://github.com/SW-Luis-Palacios/base-netkit/actions/workflows/docker-publish.yml/badge.svg)

This Docker container is designed to provide a minimal Linux environment with multiple networking tools and an Nginx web server.

Typical use cases:

- Include it as a service in a existing docker-compose.yml project
- Use it as bastion to be "inside" your Docker network.
- Troubleshoot networking from within the docker network.

## Features

- **Nginx Web Server** with support for HTTP and HTTPS (ports configurable via environment variables `HTTP_PORT` and `HTTPS_PORT`).
- Automatically generated self-signed SSL certificates.
- Multiple included networking tools:

  - **Networking utilities:** curl, wget, dig, nslookup, ip, ifconfig, route, traceroute, tracepath, mtr, tcptraceroute, ping, arp, arping, ps, netstat, gzip, cpio, tar, telnet, tcpdump, jq, bash, iperf3, ethtool, mii-tool, nmap, ss, tshark, ssh, lftp, rsync, scp, netcat, socat, ApacheBench (ab), mysql & postgresql client, git.
  - **Text utilities:** gawk, cut, diff, find, grep, sed, vi editor, wc.

## Usage

### Building the Image

To build the Docker image, run the following command in the directory containing the Dockerfile:

```sh
docker build -t sw-luis-palacios/netkit .

or

docker compose up --build -d
```

### Run the container

```sh
docker run -d -p 80:80 -p 443:443 --name netkit sw-luis-palacios/netkit
```

If you want to change the default ports

```sh
docker run -d -p 8880:8880 -p 9990:9990 --name netkit -e HTTP_PORT=8880 -e HTTPS_PORT=9990 sw-luis-palacios/netkit
```

### Troubleshoot

```sh
docker run --rm -it --entrypoint /bin/bash --name mi_netkit --hostname netkit sw-luis-palacios/base-netkit
```

```sh
docker compose up --build -d
docker exec -it mi_netkit /bin/bash
```
