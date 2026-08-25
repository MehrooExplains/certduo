#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

# CertDuo - interactive Let's Encrypt certificate installer for a domain or
# the current server's public IPv4 address.

if [[ ${1:-} == "--help" || ${1:-} == "-h" ]]; then
  cat <<'EOF'
CertDuo issues a Let's Encrypt certificate for either:
  1) a domain name
  2) this server's public IPv4 address

Usage: sudo ./certduo.sh [--staging]

Use --staging for a safe test with an untrusted certificate.
EOF
  exit 0
fi

if [[ $EUID -ne 0 ]]; then
  echo "Please run CertDuo with sudo/root." >&2
  exit 1
fi

STAGING=0
if [[ ${1:-} == "--staging" ]]; then
  STAGING=1
elif [[ $# -gt 0 ]]; then
  echo "Unknown option: $1" >&2
  exit 2
fi

echo
echo "======================================"
echo "  CertDuo - Domain & IP Certificates"
echo "======================================"
echo
echo "Choose certificate type:"
echo "  1) Domain certificate"
echo "  2) Certificate for this server's public IP"
echo
read -r -p "Enter 1 or 2: " CERT_TYPE
[[ $CERT_TYPE == "1" || $CERT_TYPE == "2" ]] || {
  echo "Invalid choice. Run the script again and enter 1 or 2." >&2
  exit 2
}

read -r -p "Let's Encrypt account email: " EMAIL
[[ $EMAIL == *@*.* ]] || { echo "Invalid email address." >&2; exit 2; }

read -r -p "Webroot directory [/var/www/html]: " WEBROOT
WEBROOT=${WEBROOT:-/var/www/html}
[[ -d $WEBROOT ]] || { echo "Webroot does not exist: $WEBROOT" >&2; exit 1; }

DOMAIN=""
IP_ADDRESS=""
INCLUDE_WWW=0

if [[ $CERT_TYPE == "1" ]]; then
  read -r -p "Domain (example.com): " DOMAIN
  DOMAIN=${DOMAIN,,}
  [[ $DOMAIN =~ ^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$ ]] || {
    echo "Invalid domain name: $DOMAIN" >&2
    exit 2
  }
  read -r -p "Also include www.$DOMAIN? [y/N]: " WWW_REPLY
  [[ ${WWW_REPLY,,} == "y" || ${WWW_REPLY,,} == "yes" ]] && INCLUDE_WWW=1
else
  echo "Detecting this server's public IPv4 address..."
  IP_ADDRESS=$(curl -4fsS --max-time 10 https://api.ipify.org || true)
  if [[ ! $IP_ADDRESS =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "Could not detect a public IPv4 address." >&2
    exit 1
  fi
  IFS=. read -r o1 o2 o3 o4 <<<"$IP_ADDRESS"
  for octet in "$o1" "$o2" "$o3" "$o4"; do
    (( octet >= 0 && octet <= 255 )) || { echo "Detected IP is invalid." >&2; exit 1; }
  done
  echo "Detected public IP: $IP_ADDRESS"
fi

install_certbot() {
  if command -v certbot >/dev/null 2>&1; then return; fi

  echo "Certbot is not installed; installing it with Snap..."
  if ! command -v snap >/dev/null 2>&1; then
    if command -v apt-get >/dev/null 2>&1; then
      apt-get update
      DEBIAN_FRONTEND=noninteractive apt-get install -y snapd
    elif command -v dnf >/dev/null 2>&1; then
      dnf install -y snapd
    elif command -v yum >/dev/null 2>&1; then
      yum install -y snapd
    else
      echo "Install Snap and Certbot 5.4+ manually, then rerun CertDuo." >&2
      exit 1
    fi
  fi

  systemctl enable --now snapd.socket
  snap wait system seed.loaded
  snap install core >/dev/null 2>&1 || snap refresh core
  snap install --classic certbot
  [[ -e /usr/local/bin/certbot ]] || ln -s /snap/bin/certbot /usr/local/bin/certbot
}

install_certbot

CERTBOT_VERSION=$(certbot --version 2>&1 | awk '{print $2}')
if ! printf '%s\n%s\n' "5.4" "$CERTBOT_VERSION" | sort -V -C; then
  echo "Certbot 5.4+ is required; installed version is $CERTBOT_VERSION." >&2
  exit 1
fi

mkdir -p "$WEBROOT/.well-known/acme-challenge"
ARGS=(certonly --non-interactive --agree-tos --email "$EMAIL" --webroot --webroot-path "$WEBROOT")
(( STAGING == 1 )) && ARGS+=(--staging)

if [[ $CERT_TYPE == "1" ]]; then
  ARGS+=(-d "$DOMAIN")
  (( INCLUDE_WWW == 1 )) && ARGS+=(-d "www.$DOMAIN")
  echo "Requesting a certificate for $DOMAIN..."
  certbot "${ARGS[@]}"
  CERT_NAME=$DOMAIN
else
  echo "Requesting a short-lived certificate for $IP_ADDRESS..."
  certbot "${ARGS[@]}" --preferred-profile shortlived --ip-address "$IP_ADDRESS"
  CERT_NAME=$IP_ADDRESS
fi

HOOK_DIR=/etc/letsencrypt/renewal-hooks/deploy
mkdir -p "$HOOK_DIR"
tee "$HOOK_DIR/reload-webserver.sh" >/dev/null <<'HOOK'
#!/usr/bin/env bash
set -eu
if systemctl is-active --quiet nginx; then systemctl reload nginx; fi
if systemctl is-active --quiet apache2; then systemctl reload apache2; fi
if systemctl is-active --quiet httpd; then systemctl reload httpd; fi
HOOK
chmod 0755 "$HOOK_DIR/reload-webserver.sh"

if ! systemctl list-unit-files 'snap.certbot.renew.timer' --no-legend 2>/dev/null | grep -q snap.certbot.renew.timer; then
  tee /etc/systemd/system/certbot-renew.service >/dev/null <<'EOF'
[Unit]
Description=Renew Let's Encrypt certificates
[Service]
Type=oneshot
ExecStart=/usr/local/bin/certbot renew --quiet
EOF
  tee /etc/systemd/system/certbot-renew.timer >/dev/null <<'EOF'
[Unit]
Description=Run Certbot renewal twice daily
[Timer]
OnCalendar=*-*-* 00,12:17:00
RandomizedDelaySec=1800
Persistent=true
[Install]
WantedBy=timers.target
EOF
  systemctl daemon-reload
  systemctl enable --now certbot-renew.timer
fi

echo
echo "Certificate issued successfully."
echo "Certificate: /etc/letsencrypt/live/$CERT_NAME/fullchain.pem"
echo "Private key: /etc/letsencrypt/live/$CERT_NAME/privkey.pem"
[[ $CERT_TYPE == "2" ]] && echo "IP certificates expire after about 6 days; automatic renewal is enabled."
