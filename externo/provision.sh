#!/usr/bin/env bash
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends curl tcpdump nmap

# Como el resto: eth0 (NAT de Vagrant) no debe poner ruta por defecto
grep -q '^interface eth0' /etc/dhcpcd.conf || cat >> /etc/dhcpcd.conf <<'CONF'
interface eth0
nogateway
CONF