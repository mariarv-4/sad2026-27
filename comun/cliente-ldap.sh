#!/usr/bin/env bash
# Convierte la máquina en cliente del directorio (SSSD) usando su <maquina>/sssd.conf
set -e
export DEBIAN_FRONTEND=noninteractive

echo "=> Configurando cliente LDAP (SSSD)..."
apt-get install -y --no-install-recommends sssd-ldap libnss-sss libpam-sss ldap-utils

# Confiar en la CA de la empresa (para comprobar el certificado del idp)
cp /vagrant/idp/tls/ca.crt /usr/local/share/ca-certificates/ca-empresa.crt
update-ca-certificates

# Configuración de SSSD propia de cada máquina (debe tener permisos 600)
cp /vagrant/$1/sssd.conf /etc/sssd/sssd.conf
chown root:root /etc/sssd/sssd.conf
chmod 600 /etc/sssd/sssd.conf

# Crear el /home de los usuarios de LDAP en su primer inicio de sesión
pam-auth-update --enable mkhomedir
systemctl restart sssd