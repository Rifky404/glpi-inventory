FROM php:7.4

# Update repository
RUN apt update && apt install -y \
apache2 mariadb-server \
php7.4 php7.4-cli php7.4-common \
php7.4-curl php7.4-gd php7.4-intl \
php7.4-ldap php7.4-mysql php7.4-xml \
php7.4-mbstring php7.4-zip php7.4-bz2 \
php7.4-apcu

# Set working directory
WORKDIR /home/$USER/glpi-inventory


# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy project
COPY apps/ /home/$USER/glpi-inventory

RUN chown -R www-data:www-data var/www/html/glpi &&\
    chmod -R 755 var/www/html/glpi\
    chmod -R 755 /var/www/html/glpi && \
    chmod -R 777 /var/www/html/glpi/files && \
    chmod -R 777 /var/www/html/glpi/config

RUN a2enmod rewrite && \
    a2enmod headers && \
    service apache2 restart

