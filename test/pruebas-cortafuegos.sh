#!/bin/bash
# Batería de pruebas del cortafuegos (Práctica 4, UD4). NO LA MODIFIQUES.
# Se ejecuta dentro de cada máquina, sin cambiar nada:  sudo bash /vagrant/tests/pruebas-cortafuegos.sh
# Averigua sola quién es (por el hostname) y cuál es tu N (por el Vagrantfile).

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
N=$(tr -d '\r' < "$DIR/../Vagrantfile" | sed -n 's/^N *= *"\([0-9]*\)".*/\1/p' | head -1)
[ -n "$N" ] || { echo "ERROR: no encuentro N en el Vagrantfile"; exit 2; }

HOST=$(hostname)
MAQUINA=${HOST%%-*}
GW_WAN=203.0.113.254; GW_DMZ=172.1.$N.1; GW_LAN=172.2.$N.1; GW_GES=172.3.$N.1
WWW=172.1.$N.3; ADMINPC=172.2.$N.10; EMPLEADO=172.2.$N.100; IDP=172.3.$N.2
DNS_EXT=1.1.1.1; NTP_EXT=162.159.200.1; IP_EXT=8.8.8.8

TOTAL=0; BIEN=0

# Si se acaba de recrear el gw, tiene otra MAC: olvidamos la antigua para no dar fallos falsos
ip neigh flush all 2>/dev/null

# --- Sondas: devuelven 0 si la comunicación llega ---
tcp()  { timeout 3 bash -c "exec 3<>/dev/tcp/$1/$2" 2>/dev/null; }
ping1(){ ping -c 1 -W 2 "$1" >/dev/null 2>&1; }
web()  { curl -ks -m 6 -o /dev/null "$1"; }
# DNS y NTP: un paquete UDP de verdad, y hay que recibir respuesta
dns()  { timeout 3 bash -c "exec 3<>/dev/udp/$1/53; printf '\x12\x34\x01\x00\x00\x01\x00\x00\x00\x00\x00\x00\x07example\x03com\x00\x00\x01\x00\x01' >&3; head -c 2 <&3 | grep -qc ." 2>/dev/null; }
ntp()  { timeout 3 bash -c "exec 3<>/dev/udp/$1/123; printf '\x1b%047d' 0 | tr 0 '\000' >&3; head -c 2 <&3 | grep -qc ." 2>/dev/null; }

# --- prueba <permitido|bloqueado> <descripción> <sonda...> ---
prueba() {
  local esperado=$1 desc=$2; shift 2
  local obtenido=bloqueado marca
  "$@" && obtenido=permitido
  TOTAL=$((TOTAL + 1))
  if [ "$obtenido" = "$esperado" ]; then BIEN=$((BIEN + 1)); marca="[ OK  ]"; else marca="[FALLO]"; fi
  printf '%s %-46s %s\n' "$marca" "$desc" "$obtenido"
}
# --- afirma <descripción> <comando...>: comprobaciones internas del gw ---
afirma() {
  local desc=$1 marca; shift
  TOTAL=$((TOTAL + 1))
  if "$@" >/dev/null 2>&1; then BIEN=$((BIEN + 1)); marca="[ OK  ]"; else marca="[FALLO]"; fi
  printf '%s %s\n' "$marca" "$desc"
}

HUELLA=$(tr -d '\r' < "${BASH_SOURCE[0]}" | sha256sum | cut -c1-8)
IPS=$(ip -4 -o addr show | awk '$2 != "lo" && $2 != "eth0" {sub("/.*","",$4); printf "%s ", $4}')
echo "=== PRUEBAS CORTAFUEGOS === maquina: $HOST === N=$N"
echo "IP: $IPS"
echo "$(date '+%d/%m/%Y %H:%M')  huella: $HUELLA"
echo "--------------------------------------------------------------"

case "$MAQUINA" in
  adminpc|empleado)
    prueba permitido "Internet: ping a $IP_EXT"            ping1 $IP_EXT
    prueba permitido "Internet: https://deb.debian.org"    web https://deb.debian.org
    prueba permitido "Internet: cualquier puerto (853)"    tcp $IP_EXT 853
    prueba permitido "gw: ping a su IP de la LAN"          ping1 $GW_LAN
    prueba permitido "www: HTTP (80)"                      tcp $WWW 80
    prueba permitido "www: HTTPS (443)"                    tcp $WWW 443
    prueba permitido "idp: LDAP (389)"                     tcp $IDP 389
    prueba bloqueado "idp: ping"                           ping1 $IDP
    if [ "$MAQUINA" = adminpc ]; then
      prueba permitido "gw: SSH, solo adminpc"             tcp $GW_LAN 22
      prueba permitido "www: SSH, solo adminpc"            tcp $WWW 22
      prueba permitido "idp: SSH, solo adminpc"            tcp $IDP 22
    else
      prueba bloqueado "gw: SSH, solo adminpc"             tcp $GW_LAN 22
      prueba bloqueado "www: SSH, solo adminpc"            tcp $WWW 22
      prueba bloqueado "idp: SSH, solo adminpc"            tcp $IDP 22
    fi
    ;;
  www)
    prueba permitido "Salida: http://deb.debian.org"       web http://deb.debian.org
    prueba permitido "Salida: https://deb.debian.org"      web https://deb.debian.org
    prueba permitido "Salida: DNS a $DNS_EXT"              dns $DNS_EXT
    prueba permitido "Salida: NTP a $NTP_EXT"              ntp $NTP_EXT
    prueba bloqueado "Salida: ping a $IP_EXT"              ping1 $IP_EXT
    prueba bloqueado "Salida: otro puerto (853)"           tcp $IP_EXT 853
    prueba permitido "idp: LDAP (389)"                     tcp $IDP 389
    prueba bloqueado "idp: SSH"                            tcp $IDP 22
    prueba bloqueado "LAN: ping a adminpc"                 ping1 $ADMINPC
    prueba bloqueado "LAN: SSH a adminpc"                  tcp $ADMINPC 22
    prueba permitido "gw: ping a su IP de la DMZ"          ping1 $GW_DMZ
    prueba bloqueado "gw: SSH"                             tcp $GW_DMZ 22
    ;;
  idp)
    prueba permitido "Salida: https://deb.debian.org"      web https://deb.debian.org
    prueba permitido "Salida: DNS a $DNS_EXT"              dns $DNS_EXT
    prueba permitido "Salida: NTP a $NTP_EXT"              ntp $NTP_EXT
    prueba bloqueado "Salida: otro puerto (853)"           tcp $IP_EXT 853
    prueba bloqueado "DMZ: HTTP a www"                     tcp $WWW 80
    prueba bloqueado "LAN: SSH a adminpc"                  tcp $ADMINPC 22
    prueba permitido "gw: ping a su IP de Gestion"         ping1 $GW_GES
    prueba bloqueado "gw: SSH"                             tcp $GW_GES 22
    ;;
  externo)
    ip route show | grep -q "^default via $GW_WAN" || echo "AVISO: sin ruta por defecto hacia el gw: la prueba no vale"
    prueba permitido "Web publicada: HTTP a $GW_WAN"       web http://$GW_WAN
    prueba permitido "Web publicada: HTTPS a $GW_WAN"      web https://$GW_WAN
    prueba bloqueado "gw: ping"                            ping1 $GW_WAN
    prueba bloqueado "gw: SSH"                             tcp $GW_WAN 22
    prueba bloqueado "LAN: ping a adminpc"                 ping1 $ADMINPC
    prueba bloqueado "LAN: SSH a adminpc"                  tcp $ADMINPC 22
    prueba bloqueado "DMZ: SSH a www"                      tcp $WWW 22
    prueba bloqueado "Gestion: LDAP en idp"                tcp $IDP 389
    ;;
  gw)
    [ "$(id -u)" = 0 ] || { echo "En el gw hay que ejecutarlo con sudo"; exit 2; }
    REGLAS=$(nft list ruleset 2>/dev/null)
    politicas_drop() {
      local h
      for h in input output forward; do
        grep -q "hook $h priority filter; policy drop" <<<"$REGLAS" || return 1
      done
    }
    afirma "nftables se carga al arrancar"            systemctl is-enabled nftables
    afirma "iptables-persistent desinstalado"         bash -c '! dpkg -s iptables-persistent 2>/dev/null | grep -q "Status: install ok"'
    afirma "Enrutamiento activado (ip_forward=1)"     test "$(sysctl -n net.ipv4.ip_forward)" = 1
    afirma "Politica drop en input, output y forward" politicas_drop
    afirma "Hay reglas de log"                        grep -q 'log prefix' <<<"$REGLAS"
    afirma "SNAT (masquerade) hacia eth0"             grep -Eq 'oifname .*eth0.* masquerade' <<<"$REGLAS"
    afirma "DNAT hacia www ($WWW)"                    grep -q "dnat .*to $WWW" <<<"$REGLAS"
    afirma "El cargado es el del repositorio"         bash -c "diff -q <(tr -d '\r' < '$DIR/../gw/nftables.conf') /etc/nftables.conf"
    prueba permitido "Salida: https://deb.debian.org" web https://deb.debian.org
    prueba permitido "Salida: DNS a $DNS_EXT"         dns $DNS_EXT
    prueba permitido "Salida: ping a $IP_EXT"         ping1 $IP_EXT
    prueba bloqueado "Salida: otro puerto (853)"      tcp $IP_EXT 853
    ;;
  *)
    echo "Esta prueba no es para la maquina '$HOST'."; exit 2 ;;
esac

echo "--------------------------------------------------------------"
echo "=== RESULTADO $HOST: $BIEN/$TOTAL correctas ==="
[ "$BIEN" = "$TOTAL" ]
