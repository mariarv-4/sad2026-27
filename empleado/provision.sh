#!/usr/bin/env bash
# El script se detiene si hay errores
set -e
export DEBIAN_FRONTEND=noninteractive

echo "########################################"
echo "Aprovisionando cliente"
echo "########################################"

apt-get update -y
apt-get install -y curl nmap tcpdump wget iputils-ping

# eth0 es la NAT de Vagrant: solo la queremos para que Vagrant entre por SSH.
# dhcpcd no debe poner rutas por defecto (ni IPv4 ni IPv6) por ella: todo sale por el gw.
grep -q '^interface eth0' /etc/dhcpcd.conf || cat >> /etc/dhcpcd.conf <<'EOF'
interface eth0
nogateway
EOF

echo "FIN"