# NetKit Container

![GitHub action workflow status](https://github.com/AgorastisMesaio/docker-img-netkit/actions/workflows/docker-publish.yml/badge.svg)

This repository contains a `Dockerfile` aimed to create a *base image* to provide a minimal Linux environment with multiple networking tools and an Nginx web server so you have a multi use knife tool.

Typical use cases:

- Add into a existing docker-compose.yml project
- Use it as multi use knife tool bastion to be "inside" your Docker network.
- Troubleshoot networking from within the project.
- Portal to internal docker network URL's.

## Features

- **Nginx Web Server** with support for HTTP and HTTPS
- **Self-signed SSL certificates**
- **Multi use knife tool**:
  - **Networking utilities:** curl, wget, dig, nslookup, ip, ifconfig, route, traceroute, tracepath, mtr, tcptraceroute, ping, arp, arping, ps, netstat, gzip, cpio, tar, telnet, tcpdump, jq, bash, iperf3, ethtool, mii-tool, nmap, ss, tshark, ssh, lftp, rsync, scp, netcat, socat, ApacheBench (ab), mysql & postgresql client, git.
  - **Text utilities:** gawk, cut, diff, find, grep, sed, vi editor, wc.
- **SSHD enabled** for both `root` and `admin` users.
- **`/config/run.sh`** You can create your custom bash script that will be called from the `/entrypoint.sh`

## Usage

### Consume in your `docker-compose.yml`

This is the typical use case; I want to have a multi use knife in my docker compose project, using it as a bastion to troubleshoot and test other containers "from inside". Here is an example of a docker-compose.yml project:

```yaml
networks:
  my_network:
    name: my_network
    driver: bridge

services:
  redis:
    image: redis/redis-stack-server:latest
    hostname: redis.company.com
    container_name: redis
    restart: always
    ports:
      - 6379:6379
    networks:
      - my_network

  netkit:
    image: ghcr.io/agorastismesaio/docker-img-netkit:main
    hostname: netkit.company.com
    container_name: netkit
    ports:
      - "8822:22"    # Exposed ssh port
      - "8880:8880"  # Exposed http port to nginx
      - "9990:9990"  # Exposed https port to nginx (self certificate)
    environment:
      - HTTP_PORT=8880            # Run nginx http listener on this port
      - HTTPS_PORT=9990           # Run nginx http listener on this port
      - COMPANY_TITLE=Company Inc # Titile to show on the default index.html
      - ROOT_PASSWORD=rootpass
      - ADMIN_PASSWORD=netkitpass
    volumes:
      - ./dockerfiles/config:/config
    networks:
      - my_network
```

You can create optional files that will be consumed by the container.

```zsh
.
├── config
│   ├── index.html
│   └── logo.svg
│   └── links.csv
```

- `index.html` Optional. Use it if present, otherwise, generate one automatically.
- `logo.svg` Optional. If present, use it in the automatically generated index.html file
- `links.csv` Optional. If present will be used in the automatically generated index.html. A table will be created. This CSV is expected to have `logo,url,short-name,description` format.

Start your services

```sh
docker compose up --build -d
```

In our example, you can now connect to [http://localhost:8880](http://localhost:8880) or [https://localhost:9990](https://localhost:9990)

![Browser to the web server](./.assets/00.web.png)

You can use SSH, with either `root` or `admin`.

```zsh
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 8822 admin@localhost
```

Otherwise, connect to the container directly

```zsh
docker exec -it netkit /bin/bash
```

Alternatively you might want to run the container in a oneliner, using default variables (ports, users passwords, etc), like:

```sh
docker run --rm -d --name netkit ghcr.io/agorastismesaio/docker-img-netkit:main
```

## For developers

If you copy or fork this project to create their own base image, instead of consuming the image itself.

### Building the Image

To build the Docker image, run the following command in the directory containing the Dockerfile:

```sh
docker build -t netkit .
or
docker compose up --build -d
```

### Troubleshoot

```sh
docker run --rm -it --entrypoint /bin/bash --name mi_netkit --hostname netkit agorastismesaio/docker-img-netkit:latest
```
