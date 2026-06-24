# ─────────────────────────────────────────────────────
# GLPI Dockerfile
# Base: php:8.1-apache (sudah include Apache + PHP)
# ─────────────────────────────────────────────────────
FROM php:7.2-apache

# Versi GLPI yang akan diinstall
ARG GLPI_VERSION=9.5.13

# ── 1. Install dependency sistem ──────────────────────
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    libbz2-dev \
    libldap2-dev \
    libicu-dev \
    libxml2-dev \
    libcurl4-openssl-dev \
    libonig-dev \
    unzip \
    curl \
    && rm -rf /var/lib/apt/lists/*

# ── 2. Install PHP extensions ─────────────────────────
# (Cara yang benar di Docker PHP image: docker-php-ext-install)
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure ldap \
    && docker-php-ext-install -j$(nproc) \
        gd \
        intl \
        ldap \
        mysqli \
        pdo_mysql \
        dom \
        mbstring \
        zip \
        bz2 \
        curl \
        opcache \
        xml \
        xmlrpc \
        exif

# Install APCu (via PECL karena tidak ada di ext-install)
RUN pecl install apcu && docker-php-ext-enable apcu

# ── 3. Konfigurasi PHP ────────────────────────────────
RUN { \
    echo 'memory_limit = 256M'; \
    echo 'upload_max_filesize = 20M'; \
    echo 'post_max_size = 20M'; \
    echo 'max_execution_time = 300'; \
    echo 'date.timezone = Asia/Jakarta'; \
    echo 'session.cookie_httponly = On'; \
} > /usr/local/etc/php/conf.d/glpi.ini

# ── 4. Aktifkan modul Apache ──────────────────────────
RUN a2enmod rewrite headers

# ── 5. Download & install GLPI ────────────────────────
RUN curl -L \
    "https://github.com/glpi-project/glpi/releases/download/${GLPI_VERSION}/glpi-${GLPI_VERSION}.tgz" \
    -o /tmp/glpi.tgz \
    && tar -xzf /tmp/glpi.tgz -C /var/www/html/ \
    && rm /tmp/glpi.tgz

# ── 6. Konfigurasi Apache VirtualHost ─────────────────
RUN echo '<VirtualHost *:80>\n\
    DocumentRoot /var/www/html/glpi\n\
    \n\
    <Directory /var/www/html/glpi>\n\
        Options Indexes FollowSymLinks\n\
        AllowOverride All\n\
        Require all granted\n\
    </Directory>\n\
    \n\
    ErrorLog ${APACHE_LOG_DIR}/glpi_error.log\n\
    CustomLog ${APACHE_LOG_DIR}/glpi_access.log combined\n\
</VirtualHost>' > /etc/apache2/sites-enabled/000-default.conf

# ── 7. Set permission folder GLPI ─────────────────────
RUN chown -R www-data:www-data /var/www/html/glpi \
    && chmod -R 755 /var/www/html/glpi \
    && chmod -R 777 /var/www/html/glpi/files \
    && chmod -R 777 /var/www/html/glpi/config \
    && chmod -R 777 /var/www/html/glpi/marketplace

# ── 8. Expose port & jalankan Apache di foreground ────
EXPOSE 80

# Cara yang benar start Apache di Docker (bukan service apache2 restart)
CMD ["apache2-foreground"]