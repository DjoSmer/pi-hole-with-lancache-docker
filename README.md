# Docker Pi-hole with LanCache

Recently I worked with LanCache.net project. LanCache.net project has 2 main projects. One of them is LanCache-dns which runs a dns server and adds domains from [uklans/cache-domains](https://github.com/uklans/cache-domains).
Also, I know about Pi-Hole project, which also runs a dns server, and I thought it'd be cool if 2 projects worked together. So, I did it.

If you use [uklans/cache-domains](https://github.com/uklans/cache-domains) or [Lancache-dns](https://lancache.net/docs/containers/dns/) this project is for you. You can import cache domains from [uklans/cache-domains](https://github.com/uklans/cache-domains) or your fork using `Pi-Hole web`.

[![Pi Hole with LanCache runs on Docker](https://i.imgur.com/Glukb4m.png)](https://www.youtube.com/watch?v=8s0gOLcQ1tU "Pi Hole with LanCache runs on Docker - Click to Watch!")

## Quick Start

1. Copy docker-compose.yml.example to docker-compose.yml and update as needed. See example below:
[Docker-compose](https://docs.docker.com/compose/install/) example:

```yaml
version: "3"

# More info at https://github.com/pi-hole/docker-pi-hole/ and https://docs.pi-hole.net/
services:
  pihole:
    container_name: pi-hole-with-lancache
    hostname: pi-hole
    image: djosmer/pi-hole-with-lancache:latest
    # For DHCP it is recommended to remove these ports and instead add: network_mode: "host"
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      #- "67:67/udp" # Only required if you are using Pi-hole as your DHCP server
      - "8080:80/tcp"
    environment:
      TZ: 'America/Chicago'
      # WEBPASSWORD: 'set a secure password here or it will be random'
    # Volumes store your data between container upgrades
    volumes:
      - './etc-pihole:/etc/pihole'
      - './etc-dnsmasq.d:/etc/dnsmasq.d'
    #   https://github.com/pi-hole/docker-pi-hole#note-on-capabilities
    #cap_add:
    #  - NET_ADMIN # Required if you are using Pi-hole as your DHCP server, else not needed
    restart: unless-stopped
```
2. Run `docker compose up -d` to build and start pi-hole (Syntax may be `docker-compose` on older systems)
3. Use the Pi-hole web UI to change the DNS settings *Interface listening behavior* to "Listen on all interfaces, permit all origins", if using Docker's default `bridge` network setting. (This can also be achieved by setting the environment variable `DNSMASQ_LISTENING` to `all`)

[Here is an equivalent docker run script](https://github.com/pi-hole/docker-pi-hole/blob/master/examples/docker_run.sh).

## Docker Pi-Hole
You can read all the information about [Docker Pi-Hole's own repository](https://github.com/pi-hole/docker-pi-hole)
