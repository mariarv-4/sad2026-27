#!/usr/bin/env bash

# El script se detiene si hay errores
set -e
export DEBIAN_FRONTEND=noninteractive
echo "########################################"
echo " Aprovisionando idp "
echo "########################################"
echo "Actualizando repositorios"
apt-get update -y
apt-get install -y net-tools iputils-ping curl tcpdump nmap

# --- Datos del directorio (DOMINIO, ORGANIZACION y LDAP_ADMIN_PASS llegan desde el Vagrantfile)
BASE="dc=${DOMINIO//./,dc=}" 
ADMIN="cn=admin,${BASE}"
LDIF=/vagrant/idp/ldap

if [ -z "$LDAP_ADMIN_PASS" ]; then
    echo "ERROR: falta LDAP_ADMIN_PASS. ¿Has creado el fichero .env?"
    exit 1
fi

# --- 1. OpenLDAP desde cero
apt-get install -y slapd ldap-utils easy-rsa

# Respondemos de antemano a las preguntas de "dpkg-reconfigure slapd" y lo reconfiguramos.
# Se hace en cada provisión: el directorio queda SIEMPRE como dicen los LDIF.
# (Las respuestas se dan justo antes: slapd borra la contraseña de debconf en cuanto la usa.)
debconf-set-selections <<EOL
slapd slapd/no_configuration boolean false
slapd slapd/domain string ${DOMINIO}
slapd shared/organization string ${ORGANIZACION}
slapd slapd/password1 password ${LDAP_ADMIN_PASS}
slapd slapd/password2 password ${LDAP_ADMIN_PASS}
slapd slapd/purge_database boolean true
slapd slapd/move_old_database boolean true
EOL
dpkg-reconfigure -f noninteractive slapd

# --- 2. CA de la empresa: se restaura la copia de seguridad (la CA no se regenera nunca)
if [ -f /vagrant/idp/ca/ca-backup.tgz ] && [ ! -d /root/ca ]; then
    tar xzf /vagrant/idp/ca/ca-backup.tgz -C /root
fi

# --- 3. StartTLS con el certificado firmado por la CA, y exigir cifrado
mkdir -p /etc/ldap/tls
cp /vagrant/idp/tls/ca.crt /vagrant/idp/tls/idp.crt /vagrant/idp/tls/idp.key /etc/ldap/tls/
chmod 644 /etc/ldap/tls/*.crt
chown root:openldap /etc/ldap/tls/idp.key
chmod 640 /etc/ldap/tls/idp.key
ldapmodify -Q -Y EXTERNAL -H ldapi:/// -f $LDIF/tls.ldif
ldapmodify -Q -Y EXTERNAL -H ldapi:/// -f $LDIF/exigir-tls.ldif

# --- 4. Módulo ppolicy y esquema openssh-lpk (configuración: cn=config)
ldapmodify -Q -Y EXTERNAL -H ldapi:/// -f $LDIF/ppolicy-modulo.ldif
ldapadd -Q -Y EXTERNAL -H ldapi:/// -f $LDIF/openssh-lpk.ldif

# --- 5. Datos: estructura, grupos, usuarios, política y claves SSH (en orden)
for f in $LDIF/0*.ldif; do
    echo "[*] Cargando $(basename $f)"
    ldapmodify -a -x -H ldapi:/// -D "$ADMIN" -w "$LDAP_ADMIN_PASS" -f "$f"
done

echo "------ FIN ------"