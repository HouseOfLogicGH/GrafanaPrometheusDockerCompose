Run make-certs.sh here (as root) before the first docker compose up.

ca.crt / ca.key   Lab CA (10 years), limited to your .lan names and local network.
                  Import ca.crt into your PC's trusted roots. Never copy ca.key anywhere.
grafana.crt/.key  Grafana's certificate (825 days). Renew by running make-certs.sh
                  again, then: docker compose restart grafana

None of these files are committed (see .gitignore).
