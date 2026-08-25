# CertDuo

[English](#english) | [فارسی](#فارسی)

## English

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
git clone https://github.com/MehrooExplains/certduo.git
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

---

## فارسی

CertDuo یک اسکریپت تعاملی برای سرورهای لینوکسی است که از طریق Let's Encrypt
گواهی TLS رایگان و معتبر عمومی دریافت می‌کند. این اسکریپت می‌تواند برای نام
دامنه یا IP عمومی خود سرور گواهی صادر کند.

### امکانات

- منوی تعاملی ساده با دو گزینه دامنه و IP
- دریافت گواهی برای دامنه و در صورت تمایل زیردامنه `www`
- تشخیص خودکار IPv4 عمومی سرور
- دریافت گواهی کوتاه‌مدت Let's Encrypt برای IP
- اعتبارسنجی به روش webroot بدون متوقف‌کردن وب‌سرور
- تنظیم تمدید خودکار گواهی‌ها
- بارگذاری مجدد خودکار Nginx یا Apache پس از تمدید موفق
- امکان اجرای آزمایشی با محیط staging سرویس Let's Encrypt

### پیش‌نیازها

- سرور لینوکسی مبتنی بر systemd
- دسترسی `root` یا `sudo`
- بازبودن پورت ۸۰ سرور روی اینترنت
- نصب و فعال‌بودن Nginx، Apache یا وب‌سروری که مسیر webroot انتخابی را سرو کند
- برای گواهی دامنه، رکورد DNS دامنه باید از قبل به همین سرور اشاره کند
- برای گواهی IP، سرور باید IPv4 عمومی و تحت کنترل شما داشته باشد

درصورتی‌که Certbot نصب نباشد، CertDuo آن را از طریق Snap نصب می‌کند. دریافت
گواهی IP به Certbot نسخه ۵.۴ یا جدیدتر نیاز دارد.

### نصب

```bash
git clone https://github.com/MehrooExplains/certduo.git
cd certduo
chmod +x certduo.sh
```

پیشنهاد می‌شود ابتدا صدور گواهی را در محیط آزمایشی بررسی کنید:

```bash
sudo ./certduo.sh --staging
```

پس از موفقیت آزمایش، گواهی معتبر عمومی را دریافت کنید:

```bash
sudo ./certduo.sh
```

در زمان اجرا، منوی زیر نمایش داده می‌شود:

```text
1) Domain certificate
2) Certificate for this server's public IP
```

- با انتخاب گزینه ۱، اسکریپت نام دامنه را از شما می‌پرسد.
- با انتخاب گزینه ۲، IP عمومی سرور به‌صورت خودکار شناسایی می‌شود و گواهی برای
  همان IP درخواست خواهد شد.

فایل‌های گواهی پس از صدور در مسیر `/etc/letsencrypt/live/` ذخیره می‌شوند.

### نکته مهم درباره گواهی IP

گواهی‌های IP صادرشده توسط Let's Encrypt کوتاه‌مدت هستند و تقریباً شش روز
اعتبار دارند. CertDuo تمدید خودکار را فعال می‌کند؛ بنابراین سرویس تمدید نباید
غیرفعال شود و پورت ۸۰ نیز باید برای اعتبارسنجی‌های بعدی در دسترس باقی بماند.

### مجوز

این پروژه تحت مجوز MIT منتشر شده است.
