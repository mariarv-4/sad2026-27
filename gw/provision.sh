#!/usr/bin/env bash

# N llega como argumento desde el vagrantfile
N=$1

# El script se detiene si hay errores
set -e
export DEBIAN_FRONTEND=noninteractive
echo "########################################"
echo " Aprovisionando Gateway "
echo "########################################"
echo "-----------------"
echo "Actualizando repositorios"
apt-get update -y && apt-get autoremove -y
apt-get install -y net-tools iputils-ping curl tcpdump nmap nftables

# Activamos enrutamiento de forma persistente
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-enrutamiento.conf
sysctl -p /etc/sysctl.d/99-enrutamiento.conf

# nftables
cat > /etc/nftables-red.nft <<RED
define RED_DMZ = 172.1.$N.0/24
define RED_LAN = 172.2.$N.0/24
define RED_GES = 172.3.$N.0/24
define WWW     = 172.1.$N.3
define ADMINPC = 172.2.$N.10
define IDP     = 172.3.$N.2
RED

# Cargamos la política del repositorio y hacemos que se cargue en cada arranque.
bash /vagrant/gw/aplicar.sh
systemctl enable nftables

echo "Gateway configurado"