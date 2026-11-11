#!/usr/bin/env bash
# El script se detiene si hay errores
set -e
export DEBIAN_FRONTEND=noninteractive

echo "########################################"
echo "Aprovisionando cliente"
echo "########################################"

apt-get update -y
apt-get install -y curl nmap tcpdump wget iputils-ping


echo "FIN"