# ─────────────────────────────────────────────────────
# GLPI Dockerfile
# Base: php:8.1-apache (sudah include Apache + PHP)
# ─────────────────────────────────────────────────────
FROM php:8.1-apache
 
ARG GLPI_VERSION=10.0.18
 
# ── 1. Install LIBRARY SISTEM saja (bukan Apache/PHP) ─
#    php:8.1-apache sudah punya Apache & PHP.
#    apt hanya untuk .so / dev headers yang dibutuhkan
#    docker-php-ext-install di langkah berikutnya.
RUN apt-get update && apt-get install -y --no-install-recommends \
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
    git \
    && rm -rf /var/lib/apt/lists/*

# ── 2. Install PHP extensions ─────────────────────────
#    Cara yang benar di Docker PHP image
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure ldap \
    && docker-php-ext-install -j$(nproc) \
        gd \
        intl \
        ldap \
        mysqli \
        pdo_mysql \
        mbstring \
        zip \
        bz2 \
        curl \
        opcache \
        exif


# ── 2. Download dan ekstrak GLPI ─────────────────────
WORKDIR /var/www/html/apps
COPY apps/ /var/www/html/apps/

RUN curl -sS https://getcomposer.org/installer | php
RUN mv composer.phar /usr/local/bin/composer


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
    && chmod -R 755 /var/www/html/apps

    RUN composer install --no-dev --optimize-autoloader

# ── 8. Expose port & jalankan Apache di foreground ────
EXPOSE 80

# Cara yang benar start Apache di Docker (bukan service apache2 restart)
CMD ["apache2-foreground"]