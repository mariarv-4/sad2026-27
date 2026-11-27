#!/bin/bash
# Comprueba y carga gw/nftables.conf. Si tiene un error, no toca nada de lo que hay cargado.
set -e

# nft no admite finales de línea de Windows (CRLF)
tr -d '\r' < /vagrant/gw/nftables.conf > /tmp/nftables.nuevo
nft -c -f /tmp/nftables.nuevo
cp /tmp/nftables.nuevo /etc/nftables.conf
nft -f /etc/nftables.conf
echo "Reglas cargadas"

