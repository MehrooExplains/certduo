# CertDuo

CertDuo is an interactive Linux script that obtains a free, publicly trusted
TLS certificate from Let's Encrypt for either a domain name or the server's own
public IPv4 address.

## Features

- Simple two-option interactive menu
- Domain certificates, with optional `www` support
- Automatic detection of the server's public IPv4 address
- Short-lived Let's Encrypt IP certificates
- Webroot validation without stopping the web server
- Automatic renewal and Nginx/Apache reload hook
- Optional Let's Encrypt staging mode for safe testing

## Requirements

- A Linux server using systemd
- Root or `sudo` access
- Port 80 reachable from the public internet
- Nginx, Apache, or another HTTP server serving the selected webroot
- For domain certificates, DNS must already point to this server
- For IP certificates, a public IPv4 address controlled by you

CertDuo installs Certbot through Snap when it is not already available. IP
certificate support requires Certbot 5.4 or newer.

## Installation

```bash
git clone https://github.com/YOUR_USERNAME/certduo.git
cd certduo
chmod +x certduo.sh
```

Test first with Let's Encrypt staging:

```bash
sudo ./certduo.sh --staging
```

Then request a publicly trusted certificate:

```bash
sudo ./certduo.sh
```

The script asks you to choose:

```text
1) Domain certificate
2) Certificate for this server's public IP
```

Certificates are stored under `/etc/letsencrypt/live/`.

## Important note about IP certificates

Let's Encrypt IP certificates are short-lived and valid for approximately six
days. CertDuo configures automatic renewal because manual renewal is not
practical or safe.

## License

MIT
