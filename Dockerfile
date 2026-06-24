FROM php:8.1-apache

ARG GLPI_VERSION=10.0.18

ENV DEBIAN_FRONTEND=noninteractive

# Install packages
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libicu-dev \
    libldap2-dev \
    libzip-dev \
    libbz2-dev \
    libxml2-dev \
    unzip \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Configure PHP extensions
RUN docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        gd \
        intl \
        ldap \
        mysqli \
        pdo_mysql \
        mbstring \
        zip \
        bz2 \
        exif

# PHP settings
RUN { \
    echo "memory_limit=256M"; \
    echo "upload_max_filesize=100M"; \
    echo "post_max_size=100M"; \
    echo "max_execution_time=600"; \
    } > /usr/local/etc/php/conf.d/glpi.ini

# Apache rewrite
RUN a2enmod rewrite

# GLPI files
WORKDIR /var/www/html
COPY apps/ .

# Permissions
RUN chown -R www-data:www-data /var/www/html \
    && find /var/www/html -type d -exec chmod 755 {} \; \
    && find /var/www/html -type f -exec chmod 644 {} \;

# Apache VirtualHost
RUN printf '%s\n' \
'<VirtualHost *:80>' \
'    ServerName localhost' \
'    DocumentRoot /var/www/html' \
'    <Directory /var/www/html>' \
'        AllowOverride All' \
'        Require all granted' \
'    </Directory>' \
'</VirtualHost>' \
> /etc/apache2/sites-enabled/000-default.conf

EXPOSE 80

CMD ["apache2-foreground"]