# ─────────────────────────────────────────────────────────────────────────────
# GLPI Dockerfile  |  Base: php:8.1-apache  |  GLPI: 10.0.x
# ─────────────────────────────────────────────────────────────────────────────
FROM php:8.1-apache

ARG GLPI_VERSION=10.0.18

# ── FIX #1 ── Allow Composer to run as root (required in Docker build context)
# Without COMPOSER_ALLOW_SUPERUSER=1 Composer exits with code 1/100 as root.
ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/tmp/composer

# ─────────────────────────────────────────────────────────────────────────────
# 1. System / native libraries
# ─────────────────────────────────────────────────────────────────────────────
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

# ─────────────────────────────────────────────────────────────────────────────
# 2. PHP extensions
#    ── FIX #2 ── Added: xml, simplexml, fileinfo
#    GLPI 10.x composer.json declares ext-xml, ext-simplexml, ext-fileinfo
#    as hard requirements.  Missing any one of them → Composer exits 100.
# ─────────────────────────────────────────────────────────────────────────────
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure ldap \
    && docker-php-ext-install -j"$(nproc)" \
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
        exif \
        xml \
        simplexml \
        fileinfo

# ─────────────────────────────────────────────────────────────────────────────
# 3. PHP.ini tweaks for GLPI production use
# ─────────────────────────────────────────────────────────────────────────────
RUN { \
        echo 'memory_limit = 256M'; \
        echo 'upload_max_filesize = 20M'; \
        echo 'post_max_size = 20M'; \
        echo 'max_execution_time = 600'; \
        echo 'session.cookie_httponly = On'; \
        echo 'opcache.enable = 1'; \
        echo 'opcache.memory_consumption = 256'; \
        echo 'opcache.interned_strings_buffer = 16'; \
        echo 'opcache.max_accelerated_files = 10000'; \
        echo 'opcache.revalidate_freq = 0'; \
    } > /usr/local/etc/php/conf.d/glpi.ini

# ─────────────────────────────────────────────────────────────────────────────
# 4. Composer  ── FIX #3 ── install directly into /usr/local/bin (cleaner)
# ─────────────────────────────────────────────────────────────────────────────
RUN curl -sS https://getcomposer.org/installer \
    | php -- --install-dir=/usr/local/bin --filename=composer \
    && composer --version

# ─────────────────────────────────────────────────────────────────────────────
# 5. Copy GLPI application
# ─────────────────────────────────────────────────────────────────────────────
WORKDIR /var/www/html/apps
COPY apps/ /var/www/html/apps/

# ─────────────────────────────────────────────────────────────────────────────
# 6. Install PHP dependencies via Composer
#    ── FIX #4 ── php -d memory_limit=-1   → prevents OOM on large dep trees
#    ── FIX #5 ── --no-scripts             → post-install scripts (cache clear,
#                                           asset copy) fail in build context;
#                                           run manually or at container start
#    ── FIX #6 ── --no-progress            → removes ANSI progress output that
#                                           clutters docker build logs
#
#    NOTE: Run BEFORE chown so Composer writes vendor/ as root (allowed),
#          then chown covers vendor/ in the same pass below.
# ─────────────────────────────────────────────────────────────────────────────
RUN php -d memory_limit=-1 /usr/local/bin/composer install \
        --no-dev \
        --optimize-autoloader \
        --no-interaction \
        --no-scripts \
        --no-progress \
        --verbose

# ─────────────────────────────────────────────────────────────────────────────
# 7. Apache VirtualHost + mod_rewrite
#    ── FIX #7 ── a2enmod rewrite is required for GLPI's .htaccess URL rules
# ─────────────────────────────────────────────────────────────────────────────
RUN a2enmod rewrite

RUN { \
        echo '<VirtualHost *:80>'; \
        echo '    ServerName localhost'; \
        echo '    DocumentRoot /var/www/html/apps'; \
        echo ''; \
        echo '    <Directory /var/www/html/apps>'; \
        echo '        Options -Indexes +FollowSymLinks'; \
        echo '        AllowOverride All'; \
        echo '        Require all granted'; \
        echo '    </Directory>'; \
        echo ''; \
        echo '    ErrorLog  ${APACHE_LOG_DIR}/glpi_error.log'; \
        echo '    CustomLog ${APACHE_LOG_DIR}/glpi_access.log combined'; \
        echo '</VirtualHost>'; \
    } > /etc/apache2/sites-enabled/000-default.conf

# ─────────────────────────────────────────────────────────────────────────────
# 8. Permissions  ── FIX #8 ── use find instead of -R for granular control
#    dirs → 755 (rwxr-xr-x)  |  files → 644 (rw-r--r--)
#    vendor/ is now already owned by root from step 6, chown covers it here
# ─────────────────────────────────────────────────────────────────────────────
RUN chown -R www-data:www-data /var/www/html/apps \
    && find /var/www/html/apps -type d -exec chmod 755 {} \; \
    && find /var/www/html/apps -type f -exec chmod 644 {} \;

# ─────────────────────────────────────────────────────────────────────────────
# 9. Expose & start Apache
# ─────────────────────────────────────────────────────────────────────────────
EXPOSE 80
CMD ["apache2-foreground"]