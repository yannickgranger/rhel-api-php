FROM registry.access.redhat.com/ubi8/ubi:8.10-1184.1741863532 AS venus_php_base

ENV PHP_INI_DIR=/usr/local/etc/php
WORKDIR /var/www/html

# Install EPEL, Remi, PHP 8.3, Apache, and configure PHP-FPM and Apache
RUN dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm && \
    dnf install -y https://rpms.remirepo.net/enterprise/remi-release-$(rpm -E %rhel).rpm && \
    dnf module reset php -y && \
    dnf module enable php:remi-8.3 -y && \
    dnf update -y && \
    dnf install -y httpd php83 php83-php-fpm php83-php-pecl-apcu php83-php-bcmath php83-php-gd \
    php83-php-intl php83-php-mbstring php83-php-opcache php83-php-pdo php83-php-soap php83-php-sodium \
    php83-php-xml php83-php-pecl-redis6 php83-php-pecl-zip && \
    sed -i -e 's/;listen = 127.0.0.1:9000/listen = \/run\/php-fpm\/www.sock/g' \
           -e 's/;user = apache/user = apache/g' \
           -e 's/;group = apache/group = apache/g' \
           /etc/opt/remi/php83/php-fpm.d/www.conf && \
    sed -i -e 's/^#LoadModule\s*proxy_module/LoadModule proxy_module/' \
           -e 's/^#LoadModule\s*proxy_fcgi_module/LoadModule proxy_fcgi_module/' \
           /etc/httpd/conf.modules.d/00-proxy.conf && \
    echo "ServerName localhost" >> /etc/httpd/conf/httpd.conf && \
    mkdir -p /run/php-fpm && \
    chown -R apache:apache /var/www/html /run/php-fpm && \
    chmod 775 /run/php-fpm && \
    dnf clean all

# Link php.ini file and copy apache config files
COPY ./.docker/php/venus.prod.ini "$PHP_INI_DIR"/php.ini
COPY .docker/apache/mod_proxy_fcgi.conf /etc/httpd/conf.d/
COPY .docker/apache/vhost.conf /etc/httpd/conf.d/

EXPOSE 80 443

# Start Apache and PHP-FPM
CMD ["/bin/bash", "-c", "/opt/remi/php83/root/usr/sbin/php-fpm -F & /usr/sbin/httpd -D FOREGROUND"]

FROM venus_php_base AS venus_php

ENV COMPOSER_ALLOW_SUPERUSER=1
COPY . ./

# App config
COPY --from=composer:2.2 /usr/bin/composer /usr/bin/composer

