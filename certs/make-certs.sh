#!/bin/sh
# Creates a lab CA (once) and a certificate for Grafana, in this folder.
# Usage: sh make-certs.sh [hostname] [ip] [network]
#   e.g. sh make-certs.sh grafana.lan 192.168.5.227 192.168.5.0/255.255.255.0
# Re-run to renew the Grafana certificate; the CA is kept.
set -e
NAME=${1:-grafana.lan}
IP=${2:-192.168.5.227}
NET=${3:-192.168.5.0/255.255.255.0}
DOMAIN=${NAME#*.}
cd "$(dirname "$0")"

if [ ! -f ca.key ]; then
  # The CA can only sign names under .$DOMAIN and addresses in $NET,
  # so trusting it on your PC can't make any other site look genuine.
  openssl req -x509 -newkey rsa:3072 -sha256 -days 3650 -nodes \
    -keyout ca.key -out ca.crt -subj "/CN=Lab CA" \
    -addext "basicConstraints=critical,CA:TRUE,pathlen:0" \
    -addext "keyUsage=critical,keyCertSign,cRLSign" \
    -addext "nameConstraints=critical,permitted;DNS:$DOMAIN,permitted;IP:$NET"
  chmod 600 ca.key
fi

openssl req -new -newkey rsa:2048 -nodes -keyout grafana.key -out grafana.csr -subj "/CN=$NAME"
printf '%s\n' "subjectAltName=DNS:$NAME,IP:$IP" \
  "extendedKeyUsage=serverAuth" "keyUsage=critical,digitalSignature,keyEncipherment" > grafana.ext
openssl x509 -req -in grafana.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -days 825 -sha256 -extfile grafana.ext -out grafana.crt
rm grafana.csr grafana.ext
chown 472:0 grafana.key && chmod 600 grafana.key   # Grafana runs as uid 472
openssl verify -CAfile ca.crt grafana.crt
