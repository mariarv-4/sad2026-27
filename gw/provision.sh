#!/usr/bin/env bash

# El script se detiene si hay errores
set -e
export DEBIAN_FRONTEND=noninteractive
echo "########################################"
echo " Aprovisionando Gateway "
echo "########################################"
echo "-----------------"
echo "Actualizando repositorios"
apt-get update -y && apt-get autoremove -y
apt-get install -y net-tools iputils-ping curl tcpdump nmap

echo "Cortafuegos básico: hacemos NAT"
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-ipforward.conf

iptables -P FORWARD ACCEPT
iptables -t nat -F POSTROUTING

iptables -t nat -A POSTROUTING -s 172.1.7.0/24 -o eth0 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 172.2.7.0/24 -o eth0 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 172.3.7.0/24 -o eth0 -j MASQUERADE

echo "Gateway configurado"
