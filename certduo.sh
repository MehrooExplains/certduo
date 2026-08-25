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

command -v systemctl >/dev/null 2>&1 || {
  echo "CertDuo requires a systemd-based Linux server." >&2
  exit 1
}

detect_package_manager() {
  if command -v apt-get >/dev/null 2>&1; then
    PKG_MANAGER=apt
  elif command -v dnf >/dev/null 2>&1; then
    PKG_MANAGER=dnf
  elif command -v yum >/dev/null 2>&1; then
    PKG_MANAGER=yum
  else
    echo "Supported package managers: apt, dnf, and yum." >&2
    exit 1
  fi
}

install_packages() {
  case $PKG_MANAGER in
    apt)
      if (( APT_UPDATED == 0 )); then
        apt-get update
        APT_UPDATED=1
      fi
      DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
      ;;
    dnf) dnf install -y "$@" ;;
    yum) yum install -y "$@" ;;
  esac
}

ensure_prerequisites() {
  echo "Checking and installing prerequisites..."
  detect_package_manager

  local required_packages=(curl ca-certificates)
  [[ $PKG_MANAGER == apt ]] && required_packages+=(iproute2)
  [[ $PKG_MANAGER != apt ]] && required_packages+=(iproute)
  install_packages "${required_packages[@]}"

  if ! command -v nginx >/dev/null 2>&1 && \
     ! command -v apache2 >/dev/null 2>&1 && \
     ! command -v httpd >/dev/null 2>&1; then
    echo "No supported web server was found; installing Nginx..."
    install_packages nginx
    INSTALLED_NGINX=1
  fi

  if command -v nginx >/dev/null 2>&1; then
    systemctl enable --now nginx
  elif command -v apache2 >/dev/null 2>&1; then
    systemctl enable --now apache2
  elif command -v httpd >/dev/null 2>&1; then
    systemctl enable --now httpd
  fi

  if ! command -v snap >/dev/null 2>&1; then
    echo "Installing Snap..."
    install_packages snapd
  fi

  systemctl enable --now snapd.socket
  [[ $PKG_MANAGER == apt || -e /snap ]] || ln -s /var/lib/snapd/snap /snap
  snap wait system seed.loaded
  snap install core >/dev/null 2>&1 || snap refresh core

  if [[ -x /snap/bin/certbot ]]; then
    snap refresh certbot >/dev/null 2>&1 || true
  else
    echo "Installing Certbot..."
    snap install --classic certbot
  fi
  CERTBOT_BIN=/snap/bin/certbot

  local certbot_version
  certbot_version=$($CERTBOT_BIN --version 2>&1 | awk '{print $2}')
  if ! printf '%s\n%s\n' "5.4" "$certbot_version" | sort -V -C; then
    echo "Certbot 5.4+ is required; installed version is $certbot_version." >&2
    exit 1
  fi

  echo "All installable prerequisites are ready."
}

APT_UPDATED=0
INSTALLED_NGINX=0
CERTBOT_BIN=""
PKG_MANAGER=""
ensure_prerequisites

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

DEFAULT_WEBROOT=/var/www/html
[[ $PKG_MANAGER != apt && $INSTALLED_NGINX == 1 ]] && DEFAULT_WEBROOT=/usr/share/nginx/html
read -r -p "Webroot directory [$DEFAULT_WEBROOT]: " WEBROOT
WEBROOT=${WEBROOT:-$DEFAULT_WEBROOT}
mkdir -p "$WEBROOT/.well-known/acme-challenge"

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

mkdir -p "$WEBROOT/.well-known/acme-challenge"

CHALLENGE_TEST="certduo-$RANDOM-$$"
printf '%s' "$CHALLENGE_TEST" >"$WEBROOT/.well-known/acme-challenge/$CHALLENGE_TEST"
LOCAL_HOST=$([[ $CERT_TYPE == "1" ]] && printf '%s' "$DOMAIN" || printf '%s' "$IP_ADDRESS")
LOCAL_RESULT=$(curl -kfsS --max-time 5 -H "Host: $LOCAL_HOST" \
  "http://127.0.0.1/.well-known/acme-challenge/$CHALLENGE_TEST" || true)
rm -f "$WEBROOT/.well-known/acme-challenge/$CHALLENGE_TEST"
if [[ $LOCAL_RESULT != "$CHALLENGE_TEST" ]]; then
  echo "The selected webroot is not served correctly on port 80: $WEBROOT" >&2
  echo "Configure your web server to serve this directory, then rerun CertDuo." >&2
  exit 1
fi

if ! ss -ltn | awk '$4 ~ /:80$/ { found=1 } END { exit !found }'; then
  echo "No service is listening on TCP port 80." >&2
  exit 1
fi

ARGS=(certonly --non-interactive --agree-tos --email "$EMAIL" --webroot --webroot-path "$WEBROOT")
(( STAGING == 1 )) && ARGS+=(--staging)

if [[ $CERT_TYPE == "1" ]]; then
  ARGS+=(-d "$DOMAIN")
  (( INCLUDE_WWW == 1 )) && ARGS+=(-d "www.$DOMAIN")
  echo "Requesting a certificate for $DOMAIN..."
  "$CERTBOT_BIN" "${ARGS[@]}"
  CERT_NAME=$DOMAIN
else
  echo "Requesting a short-lived certificate for $IP_ADDRESS..."
  "$CERTBOT_BIN" "${ARGS[@]}" --preferred-profile shortlived --ip-address "$IP_ADDRESS"
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
ExecStart=/snap/bin/certbot renew --quiet
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
