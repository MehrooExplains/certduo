# CertDuo

**Interactive Let's Encrypt certificates for Linux domains and public IP addresses**

> 🇮🇷 **[رفتن مستقیم به راهنمای کامل فارسی](#راهنمای-فارسی)**
>
> 🇬🇧 **[Jump to the complete English guide](#english)**

---

## English

### Overview

CertDuo is an interactive Bash script that obtains free, publicly trusted TLS
certificates from [Let's Encrypt](https://letsencrypt.org/). It provides two
simple choices:

```text
1) Domain certificate
2) Certificate for this server's public IP
```

For a domain, CertDuo asks for the hostname and can optionally add `www`. For
an IP certificate, it automatically detects the server's public IPv4 address
and requests a certificate for that same address.

### Features

- Interactive domain/IP menu
- Optional `www` hostname for domain certificates
- Automatic public IPv4 detection
- Publicly trusted Let's Encrypt IP certificates
- HTTP-01 webroot validation without intentionally stopping the web server
- Automatic prerequisite checks and installation
- Automatic Nginx installation when no supported web server exists
- Certbot installation and updates through Snap
- Local webroot and TCP port 80 checks before issuance
- Automatic renewal and Nginx/Apache reload hooks
- Let's Encrypt staging mode for safe testing
- Support for Linux systems using `apt`, `dnf`, or `yum`

### How it works

1. Confirms that the script runs as root on a systemd-based server.
2. Detects `apt`, `dnf`, or `yum`.
3. Installs missing command-line and networking dependencies.
4. Reuses Nginx, Apache, or httpd when present. If none exists, installs Nginx.
5. Installs or updates Snap and Certbot 5.4 or newer.
6. Asks whether you need a domain or public-IP certificate.
7. Checks that the selected webroot is served on TCP port 80.
8. Requests the certificate using the ACME HTTP-01 challenge.
9. Configures automatic renewal and reloads the active supported web server
   after a successful renewal.

### Automatically installed prerequisites

Depending on what is already available, CertDuo may install:

- `curl` and CA certificates
- `iproute` or `iproute2`
- Snap (`snapd`)
- Certbot 5.4 or newer
- Nginx, only when Nginx, Apache, and httpd are all absent

Existing supported web servers are reused and are not replaced.

### Requirements outside the server

These cannot be configured reliably from inside the operating system:

- TCP port 80 must be allowed by the hosting firewall or security group.
- NAT/router port forwarding must direct TCP port 80 to this server.
- A domain's `A` record must point to this server's public IPv4 address.
- If `www` is selected, its DNS record must also point to this server.
- The public IP must be controlled by you and reachable from the internet.
- The selected webroot must be served by the intended virtual host.

Let's Encrypt validates from the public internet. A successful local test
cannot override an external firewall, DNS, NAT, proxy, or routing problem.

### Supported environment

- A systemd-based Linux server
- Root or `sudo` access
- A distribution with `apt`, `dnf`, or `yum`
- Internet access and a public IPv4 address
- Public inbound access to TCP port 80

CertDuo currently auto-detects IPv4 for IP certificates. It does not
automatically request an IPv6 certificate.

### Installation

```bash
git clone https://github.com/MehrooExplains/certduo.git
cd certduo
chmod +x certduo.sh
```

Test with Let's Encrypt staging first:

```bash
sudo ./certduo.sh --staging
```

Staging certificates are intentionally untrusted. Use them to verify DNS,
networking, webroot, and ACME validation without consuming production limits.

After a successful test, request a publicly trusted certificate:

```bash
sudo ./certduo.sh
```

### Option 1: domain certificate

Choose `1`, then provide:

- Your Let's Encrypt account email
- The website's real webroot, such as `/var/www/html`
- The domain without `http://`, `https://`, or a path
- Whether to include `www.your-domain.example`

All requested hostnames must already resolve to the server and be reachable
over plain HTTP on port 80.

### Option 2: public-IP certificate

Choose `2`. CertDuo uses `api.ipify.org` to detect the server's outgoing
public IPv4 address, displays it, and requests a certificate for that address.

Let's Encrypt requires IP certificates to use the `shortlived` profile. They
are valid for approximately six days, so automatic renewal must remain enabled.
CertDuo uses Certbot's `--ip-address` and
`--preferred-profile shortlived` options.

### Certificate locations

```text
# Domain
/etc/letsencrypt/live/YOUR_DOMAIN/fullchain.pem
/etc/letsencrypt/live/YOUR_DOMAIN/privkey.pem

# Public IP
/etc/letsencrypt/live/YOUR_PUBLIC_IP/fullchain.pem
/etc/letsencrypt/live/YOUR_PUBLIC_IP/privkey.pem
```

Never share the private key or commit it to a repository.

### Configure HTTPS

CertDuo obtains and renews certificates, but it does not rewrite your HTTPS
virtual-host configuration. Configure Nginx, Apache, your reverse proxy, or
your application to use the printed `fullchain.pem` and `privkey.pem` paths.

Certbot's web-server installer plugins do not currently install IP certificates
automatically, which is why CertDuo uses webroot mode.

### Automatic renewal

CertDuo uses Certbot's Snap renewal timer when available. Otherwise, it creates
a systemd timer that runs twice daily. A deploy hook reloads active services
named `nginx`, `apache2`, or `httpd` after a successful renewal.

```bash
sudo /snap/bin/certbot certificates
sudo /snap/bin/certbot renew --dry-run
systemctl list-timers | grep -E 'certbot|snap.certbot'
```

### Troubleshooting

#### Port 80 is not reachable

Allow inbound TCP port 80 in both the operating-system firewall and the hosting
provider's firewall/security group. Check NAT and port forwarding if applicable.

#### The webroot check fails

Make sure the virtual host serves files created under:

```text
WEBROOT/.well-known/acme-challenge/
```

A custom virtual host may use a different document root than `/var/www/html`.

#### Domain validation fails

```bash
dig +short example.com A
curl -I http://example.com/
```

The DNS result must be this server's public IP. Repeat for `www` if included.

#### IP detection is wrong

The server may be behind NAT, a proxy, or another outbound gateway. The detected
address must route inbound port 80 back to this server.

#### Snap or Certbot installation fails

Confirm that the distribution provides `snapd`, systemd is active, DNS works,
and outbound internet access is available. Some distributions require their
Snap package repository to be enabled first.

### Security

- Review scripts before running them as root.
- Use CertDuo only for domains and IP addresses you own or control.
- Never publish files from `/etc/letsencrypt/live/`.
- Keep renewal enabled, especially for six-day IP certificates.
- Keep the OS, web server, Snap, and Certbot updated.

### Official references

- [Let's Encrypt challenge types](https://letsencrypt.org/docs/challenge-types/)
- [IP and six-day certificates](https://letsencrypt.org/2026/01/15/6day-and-ip-general-availability.html)
- [IP certificates with Certbot](https://letsencrypt.org/2026/03/11/shorter-certs-certbot)

### License

CertDuo is released under the [MIT License](LICENSE).

---

## راهنمای فارسی

### معرفی

CertDuo یک اسکریپت تعاملی Bash برای دریافت گواهی رایگان و معتبر عمومی TLS از
[Let's Encrypt](https://letsencrypt.org/) است. هنگام اجرا دو گزینه ارائه می‌شود:

```text
1) Domain certificate
2) Certificate for this server's public IP
```

در حالت دامنه، نام دامنه از کاربر گرفته می‌شود و امکان افزودن `www` نیز وجود
دارد. در حالت IP، اسکریپت IPv4 عمومی سرور را خودکار تشخیص می‌دهد و برای همان
آدرس گواهی درخواست می‌کند.

### امکانات

- منوی تعاملی دامنه و IP
- امکان افزودن `www` به گواهی دامنه
- تشخیص خودکار IPv4 عمومی سرور
- دریافت گواهی معتبر عمومی Let's Encrypt برای IP
- اعتبارسنجی HTTP-01 به روش webroot بدون توقف عمدی وب‌سرور
- بررسی و نصب خودکار پیش‌نیازها
- نصب خودکار Nginx در صورت نبود وب‌سرور پشتیبانی‌شده
- نصب و به‌روزرسانی Certbot از طریق Snap
- بررسی محلی webroot و پورت ۸۰ پیش از صدور
- تمدید خودکار و reload کردن Nginx یا Apache
- حالت staging برای آزمایش امن
- پشتیبانی از سیستم‌های دارای `apt`، `dnf` یا `yum`

### نحوه کار

۱. اجرای اسکریپت با دسترسی root روی سیستم مبتنی بر systemd را بررسی می‌کند.

۲. مدیر بسته `apt`، `dnf` یا `yum` را تشخیص می‌دهد.

۳. ابزارهای خط فرمان و شبکه موردنیاز را نصب می‌کند.

۴. از Nginx، Apache یا httpd موجود استفاده می‌کند؛ در غیر این صورت Nginx را
نصب و فعال می‌کند.

۵. Snap و Certbot نسخه ۵.۴ یا جدیدتر را نصب یا به‌روزرسانی می‌کند.

۶. نوع گواهی دامنه یا IP را از کاربر می‌پرسد.

۷. سروشدن webroot روی پورت ۸۰ را آزمایش می‌کند.

۸. گواهی را با چالش ACME از نوع HTTP-01 درخواست می‌کند.

۹. تمدید خودکار و reload وب‌سرور پس از تمدید موفق را تنظیم می‌کند.

### پیش‌نیازهایی که خودکار نصب می‌شوند

بسته به وضعیت سرور، موارد زیر ممکن است نصب شوند:

- `curl` و گواهی‌های CA
- `iproute` یا `iproute2`
- Snap یا `snapd`
- Certbot نسخه ۵.۴ یا جدیدتر
- Nginx، فقط وقتی Nginx، Apache و httpd همگی وجود نداشته باشند

وب‌سرور پشتیبانی‌شده موجود استفاده می‌شود و با Nginx جایگزین نخواهد شد.

### پیش‌نیازهای خارج از سرور

- پورت TCP شماره ۸۰ باید در فایروال میزبان یا Security Group باز باشد.
- NAT و Port Forwarding روتر باید پورت ۸۰ را به همین سرور هدایت کنند.
- رکورد `A` دامنه باید به IPv4 عمومی همین سرور اشاره کند.
- در صورت انتخاب `www`، رکورد DNS آن نیز باید به همین سرور اشاره کند.
- IP عمومی باید تحت کنترل شما و از اینترنت قابل دسترسی باشد.
- webroot انتخابی باید توسط Virtual Host موردنظر سرو شود.

اعتبارسنجی Let's Encrypt از اینترنت عمومی انجام می‌شود. آزمایش محلی نمی‌تواند
مشکل فایروال خارجی، DNS، NAT، پراکسی یا مسیریابی را برطرف کند.

### محیط پشتیبانی‌شده

- سرور لینوکسی مبتنی بر systemd
- دسترسی `root` یا `sudo`
- توزیع دارای `apt`، `dnf` یا `yum`
- دسترسی اینترنت و IPv4 عمومی
- دسترسی عمومی به پورت TCP شماره ۸۰

نسخه فعلی برای گواهی IP فقط IPv4 را خودکار تشخیص می‌دهد و گواهی IPv6 را
به‌صورت خودکار درخواست نمی‌کند.

### نصب

```bash
git clone https://github.com/MehrooExplains/certduo.git
cd certduo
chmod +x certduo.sh
```

ابتدا با محیط آزمایشی اجرا کنید:

```bash
sudo ./certduo.sh --staging
```

گواهی staging عمداً مورد اعتماد مرورگر نیست و برای بررسی DNS، شبکه، webroot و
اعتبارسنجی بدون مصرف محدودیت صدور واقعی کاربرد دارد.

پس از آزمایش موفق، گواهی معتبر عمومی را دریافت کنید:

```bash
sudo ./certduo.sh
```

### گزینه ۱: گواهی دامنه

گزینه `1` را انتخاب و موارد زیر را وارد کنید:

- ایمیل حساب Let's Encrypt
- webroot واقعی وب‌سایت، مانند `/var/www/html`
- نام دامنه بدون `http://`، `https://` یا مسیر اضافی
- انتخاب افزودن یا اضافه‌نکردن `www`

تمام نام‌های درخواستی باید از قبل به سرور resolve شوند و روی HTTP پورت ۸۰
قابل دسترسی باشند.

### گزینه ۲: گواهی IP عمومی

گزینه `2` را انتخاب کنید. CertDuo با `api.ipify.org`، IPv4 عمومی خروجی
سرور را تشخیص می‌دهد و برای همان آدرس گواهی می‌گیرد.

گواهی IP در Let's Encrypt باید از پروفایل `shortlived` استفاده کند و تقریباً
شش روز اعتبار دارد؛ پس تمدید خودکار باید فعال بماند. اسکریپت از گزینه‌های
`--ip-address` و `--preferred-profile shortlived` استفاده می‌کند.

### مسیر فایل‌های گواهی

```text
# دامنه
/etc/letsencrypt/live/YOUR_DOMAIN/fullchain.pem
/etc/letsencrypt/live/YOUR_DOMAIN/privkey.pem

# IP عمومی
/etc/letsencrypt/live/YOUR_PUBLIC_IP/fullchain.pem
/etc/letsencrypt/live/YOUR_PUBLIC_IP/privkey.pem
```

کلید خصوصی را هرگز منتشر یا داخل Git ذخیره نکنید.

### تنظیم HTTPS

CertDuo گواهی را دریافت و تمدید می‌کند، اما تنظیم Virtual Host مربوط به HTTPS
را بازنویسی نمی‌کند. Nginx، Apache، Reverse Proxy یا برنامه خود را طوری تنظیم
کنید که از مسیرهای `fullchain.pem` و `privkey.pem` نمایش‌داده‌شده استفاده کند.

افزونه‌های نصب‌کننده وب‌سرور Certbot فعلاً گواهی IP را خودکار نصب نمی‌کنند؛ به
همین دلیل CertDuo از روش webroot استفاده می‌کند.

### تمدید خودکار

در صورت وجود، از تایمر Snap مربوط به Certbot استفاده می‌شود. در غیر این صورت
یک تایمر systemd ساخته می‌شود که روزانه دو بار اجرا خواهد شد. پس از تمدید موفق،
سرویس فعال `nginx`، `apache2` یا `httpd` reload می‌شود.

```bash
sudo /snap/bin/certbot certificates
sudo /snap/bin/certbot renew --dry-run
systemctl list-timers | grep -E 'certbot|snap.certbot'
```

### رفع اشکال

#### پورت ۸۰ در دسترس نیست

ورودی TCP پورت ۸۰ را در فایروال سیستم‌عامل و فایروال/Security Group میزبان باز
کنید. در صورت استفاده از NAT، Port Forwarding را نیز بررسی کنید.

#### آزمایش webroot شکست می‌خورد

Virtual Host باید فایل‌های مسیر زیر را سرو کند:

```text
WEBROOT/.well-known/acme-challenge/
```

ممکن است Document Root سفارشی با `/var/www/html` متفاوت باشد.

#### اعتبارسنجی دامنه شکست می‌خورد

```bash
dig +short example.com A
curl -I http://example.com/
```

نتیجه DNS باید IP عمومی همین سرور باشد. اگر `www` اضافه شده، آن را نیز بررسی کنید.

#### IP اشتباه تشخیص داده می‌شود

احتمال دارد سرور پشت NAT، پراکسی یا درگاه خروجی دیگری باشد. IP تشخیص‌داده‌شده
باید پورت ورودی ۸۰ را به همین سرور هدایت کند.

#### نصب Snap یا Certbot شکست می‌خورد

بررسی کنید توزیع بسته `snapd` را ارائه می‌دهد، systemd فعال است، DNS کار
می‌کند و سرور دسترسی خروجی اینترنت دارد. بعضی توزیع‌ها نیازمند فعال‌کردن مخزن
بسته Snap هستند.

### نکات امنیتی

- پیش از اجرای اسکریپت با root، محتوای آن را بررسی کنید.
- فقط برای دامنه‌ها و IPهای تحت مالکیت یا کنترل خود گواهی بگیرید.
- فایل‌های `/etc/letsencrypt/live/` را هرگز عمومی نکنید.
- تمدید خودکار، به‌خصوص برای گواهی شش‌روزه IP، باید فعال بماند.
- سیستم‌عامل، وب‌سرور، Snap و Certbot را به‌روز نگه دارید.

### مستندات رسمی

- [انواع چالش Let's Encrypt](https://letsencrypt.org/docs/challenge-types/)
- [گواهی‌های IP و شش‌روزه](https://letsencrypt.org/2026/01/15/6day-and-ip-general-availability.html)
- [دریافت گواهی IP با Certbot](https://letsencrypt.org/2026/03/11/shorter-certs-certbot)

### مجوز

CertDuo تحت [مجوز MIT](LICENSE) منتشر شده است.
