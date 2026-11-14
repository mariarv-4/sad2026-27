#!/usr/bin/env bash
# El script se detiene si hay errores
set -e
export DEBIAN_FRONTEND=noninteractive

echo "########################################"
echo "Aprovisionando WWW"
echo "########################################"

# 1. Actualización
apt-get update -y

# 2. Nginx, OpenSSL y PHP (php-fpm instala la versión de la distribución: 8.4 en Debian 13)
apt-get install -y nginx openssl php-fpm php-opcache php-gd php-mysql php-curl
PHPV=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')

# 3. Certificado autofirmado (en una próxima unidad lo firmará la CA de la empresa)
mkdir -p /etc/ssl/private /etc/ssl/certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
-keyout /etc/ssl/private/nginx-selfsigned.key \
-out /etc/ssl/certs/nginx-selfsigned.crt \
-subj "/C=ES/ST=Almeria/L=Almeria/O=IES_CELIA_VINAS/OU=IT/CN=localhost"

# 4. Sitio web. En Debian se escribe en sites-available y se activa con un enlace en sites-enabled
rm -f /etc/nginx/sites-enabled/default
cat <<'NGINX' > /etc/nginx/sites-available/servidor_web
server {
    listen 80;
    listen [::]:80;
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name localhost;
    ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
    ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;
    root /var/www/html;
    index index.php index.html;
    location / {
        try_files $uri $uri/ =404;
    }
    # PHP: php-fpm escucha en un socket Unix
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php-fpm.sock;
    }
}
NGINX

ln -sf /etc/nginx/sites-available/servidor_web /etc/nginx/sites-enabled/servidor_web

# 5. Limitamos los procesos de PHP para no agotar los 400 MB de RAM
sed -i 's/^pm.max_children .*/pm.max_children = 3/' /etc/php/$PHPV/fpm/pool.d/www.conf

# 6. Página de prueba
rm -f /var/www/html/index.nginx-debian.html
cat > /var/www/html/index.php << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Servidor WWW DMZ</title>
</head>
<body>
    <h1>¡Hola! Estás en el servidor WWW</h1>
    <p>Dirección IP del servidor: <?php echo $_SERVER['SERVER_ADDR']; ?></p>
    <p><a href="info.php">Ver PHP Info</a></p>
</body>
</html>
HTML

echo "<?php phpinfo(); ?>" > /var/www/html/info.php
chown -R www-data:www-data /var/www/html

# 7. Arrancar los servicios (nginx -t comprueba la configuración antes)
nginx -t
systemctl enable php$PHPV-fpm nginx
systemctl restart php$PHPV-fpm nginx

echo "=> Blindando acceso SSH en www..."
# Cuenta de emergencia: sin contraseña, solo se entra con clave SSH
id admin_maria >/dev/null 2>&1 || useradd -m -s /bin/bash admin_maria
usermod -aG sudo admin_maria

# Clave pública de adminpc
mkdir -p /home/admin_maria/.ssh
sed 's/\r$//' /tmp/id_ed25519.pub > /home/admin_maria/.ssh/authorized_keys
chown -R admin_maria:admin_maria /home/admin_maria/.ssh
chmod 700 /home/admin_maria/.ssh
chmod 600 /home/admin_maria/.ssh/authorized_keys

# Bastionado de SSH en un fichero propio
cat > /etc/ssh/sshd_config.d/00-bastionado.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication no
EOF

# test de la configuración
sshd -t
systemctl restart ssh

# eth0 es la NAT de Vagrant: solo la queremos para que Vagrant entre por SSH.
# dhcpcd no debe poner rutas por defecto (ni IPv4 ni IPv6) por ella: todo sale por el gw.
grep -q '^interface eth0' /etc/dhcpcd.conf || cat >> /etc/dhcpcd.conf <<'EOF'
interface eth0
nogateway
EOF

echo "=> Acceso de los administradores de LDAP..."

# Las claves públicas se piden a LDAP (a través de SSSD)
cat > /etc/ssh/sshd_config.d/10-ldap.conf <<'SSHD'
AuthorizedKeysCommand /usr/bin/sss_ssh_authorizedkeys
AuthorizedKeysCommandUser nobody
SSHD

# El grupo admins de LDAP tiene sudo (con su contraseña de LDAP)
echo "%admins ALL=(ALL:ALL) ALL" > /etc/sudoers.d/admins
chmod 440 /etc/sudoers.d/admins
visudo -c

sshd -t
systemctl restart ssh

echo "----- FIN -----"

