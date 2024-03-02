#!/usr/bin/env bash

# generate and build dockerfile
docker build --tag djosmer/pi-hole-with-lancache:test --no-cache .

docker run -d \
    --name pihole_lancache \
    -p 53:53/tcp -p 53:53/udp \
    -p 80:80 \
    -e TZ="Europe/Moscow" \
    -v "$(pwd)/volumes/pihole:/etc/pihole" \
    -v "$(pwd)/volumes/dnsmasq.d:/etc/dnsmasq.d" \
    --dns=1.1.1.1 \
    --restart=unless-stopped \
    --hostname pi.hole \
    -e VIRTUAL_HOST="pi.hole" \
    -e PROXY_LOCATION="pi.hole" \
    -e FTLCONF_LOCAL_IPV4="127.0.0.1" \
    djosmer/pi-hole-with-lancache:test