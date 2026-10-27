#!/bin/bash

# El script se detiene si hay errores
set -e

echo "########################################"
echo " Aprovisionando adminpc (Alpine) "
echo "########################################"

echo "=> Instalando utilidades..."
apk update && apk add sudo bash sed

echo "=> Creando usuario administrador local en adminpc..."
# 1. Crear el usuario en Alpine sin contraseña
adduser -D admin_maria
adduser admin_maria wheel
echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel

echo "=> Importando claves SSH desde el anfitrión..."
# 2. Movemos las llaves inyectadas por Vagrant en /tmp
mkdir -p /home/admin_maria/.ssh
cp /tmp/id_ed25519 /home/admin_maria/.ssh/id_ed25519
cp /tmp/id_ed25519.pub /home/admin_maria/.ssh/id_ed25519.pub

# Limpiar posibles retornos de carro de Windows (CRLF)
sed -i 's/\r$//' /home/admin_maria/.ssh/id_ed25519
sed -i 's/\r$//' /home/admin_maria/.ssh/id_ed25519.pub

# 3. Ajustamos los permisos por seguridad
chown -R admin_maria:admin_maria /home/admin_maria/.ssh
chmod 700 /home/admin_maria/.ssh
chmod 600 /home/admin_maria/.ssh/id_ed25519
chmod 644 /home/admin_maria/.ssh/id_ed25519.pub

echo "------ FIN ------"