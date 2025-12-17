# Cobbler container image

A Cobbler container image. Up-to-date, easy to maintain, and easy to use.

## Version

3.3.3

## Docker hub

[weiyang/docker-cobbler:3.3.3](https://hub.docker.com/r/weiyang/docker-cobbler)

After starting, open http://localhost:8080/cobbler_web (user: cobbler / password: cobbler).

## How to build

```
docker build -t cobbler:3.3.3 .
```

## How to use

Web UI only (Docker Desktop friendly):

```sh
docker run -d \
  -p 8080:80 \
  -p 25151:25151 \
  -e SERVER_IP_V4=127.0.0.1 -e ROOT_PASSWORD=Password \
  -v $PWD/lib:/var/lib/cobbler -v $PWD/www:/var/www/cobbler -v $PWD/dhcpd:/var/lib/dhcpd \
  --name cobbler \
  cobbler:3.3.3
```

Full PXE (Linux host only, requires privileged/host networking):

```sh
docker run -d --privileged \
  -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
  --net host \
  -e SERVER_IP_V4=<your_host_ip> -e ROOT_PASSWORD=Password \
  -v $PWD/lib:/var/lib/cobbler -v $PWD/www:/var/www/cobbler -v $PWD/dhcpd:/var/lib/dhcpd \
  --name cobbler \
  cobbler:3.3.3
```

### Environments

- SERVER_IP_V4: Cobbler server v4 ip
- SERVER_IP_V6: Cobbler server v6 ip
- SERVER: Cobbler server ip or hostname, required, default $SERVER_IP_V4
- ROOT_PASSWORD: Installation (root) password, required

### Custom settings

```sh
-v path/to/settings.d:/etc/cobbler/settings.d:ro
```

### Custom dhcp template

```sh
-v path/to/dhcp.template:/etc/cobbler/dhcp.template:ro
```
