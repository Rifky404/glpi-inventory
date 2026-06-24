# ─────────────────────────────────────────────────────
# GLPI Dockerfile
# Base: php:8.1-apache (sudah include Apache + PHP)
# ─────────────────────────────────────────────────────
FROM php:7.2-apache

# Versi GLPI yang akan diinstall
ARG GLPI_VERSION=9.5.13

# ── 1. Install dependency sistem ──────────────────────
RUN apt-get update && apt-get install -y \
    apache2 \
    libapache2-mod-php \
    php-mysql \
    php-curl \
    php-gd \
    php-intl \
    php-mbstring \
    php-xml \
    php-zip \
    unzip \
    wget \
    && rm -rf /var/lib/apt/lists/*

# ── 2. Download dan ekstrak GLPI ─────────────────────
WORKDIR /var/www/html
COPY apps/ /var/www/html/apps/

# ── 6. Konfigurasi Apache VirtualHost ─────────────────
RUN echo '<VirtualHost *:80>\n\
    DocumentRoot /var/www/html/apps\n\
    \n\
    <Directory /var/www/html/apps>\n\
        Options Indexes FollowSymLinks\n\
        AllowOverride All\n\
        Require all granted\n\
    </Directory>\n\
    \n\
    ErrorLog ${APACHE_LOG_DIR}/glpi_error.log\n\
    CustomLog ${APACHE_LOG_DIR}/glpi_access.log combined\n\
</VirtualHost>' > /etc/apache2/sites-enabled/000-default.conf

# ── 7. Set permission folder GLPI ─────────────────────
RUN chown -R www-data:www-data /var/www/html/apps \
    && chmod -R 755 /var/www/html/apps \
    && chmod -R 777 /var/www/html/apps/files \
    && chmod -R 777 /var/www/html/apps/config \
    && chmod -R 777 /var/www/html/apps/marketplace

# ── 8. Expose port & jalankan Apache di foreground ────
EXPOSE 80

# Cara yang benar start Apache di Docker (bukan service apache2 restart)
CMD ["apache2-foreground"]