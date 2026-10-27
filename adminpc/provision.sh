#!/bin/sh

# El script se detiene si hay errores
set -e
expoort DEBIAN_FRONTEND=noninteractive
echo "########################################"
echo " Aprovisionando adminpc "
echo "########################################"
echo "-----------------"
echo "Actualizando repositorios"
apt-get update -y
apk add curl nmap tcpdump wget bash iputils nano
echo "=> Creando usuario administrador..."
adduser -D admin_maria
adduser admin_maria wheel
echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel
echo "=> Importando claves SSH desde el anfitrión..."
mkdir -p /home/admin_maria/.ssh
cp /tmp/id_ed25519 /home/admin_maria/.ssh/id_ed25519
cp /tmp/id_ed25519.pub /home/admin_maria/.ssh/id_ed25519.pub
chomod 440 /etc/sudoers.d/admin_maria

# Limpiar saltos de línea de Windows (CRLF)
sed -i 's/\r$//' /home/admin_maria/.ssh/id_ed25519

# Ajustar permisos
chown -R admin_maria:admin_maria /home/admin_maria/.ssh
chmod 700 /home/admin_maria/.ssh
chmod 600 /home/admin_maria/.ssh/id_ed25519
chmod 644 /home/admin_maria/.ssh/id_ed25519.pub
echo "------ FIN ------"