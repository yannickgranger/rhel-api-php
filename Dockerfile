FROM alpine:latest AS app_copy

WORKDIR /var/www/html

COPY composer.json composer.lock symfony.lock .env src public config bin ./

# use the builder container at begining of Dockerfile if you need a specific build
# extension json is a fake example because it is packaged in php8.3

#FROM registry.access.redhat.com/ubi8/ubi:8.10-1184.1741863532 AS php_pecl_builder
#
#WORKDIR /tmp
#RUN dnf update -y && \
#    dnf install gcc make automake autoconf libtool binutils pkgconfig glibc-headers -y && \
#    dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm && \
#    dnf install -y https://rpms.remirepo.net/enterprise/remi-release-$(rpm -E %rhel).rpm && \
#    dnf install -y php-devel php-pear php83
#
#RUN ln -s /usr/bin/php83 /usr/local/bin/php
#RUN /opt/remi/php83/root/usr/bin/pecl install json
#RUN mkdir /extensions
#RUN find /usr/lib64/php/8.3/modules/ -name "json.so" -exec cp {} /extensions \;
#RUN find /etc/opt/remi/php83/php.d -name "*.ini" -exec cp {} /extensions \;

FROM registry.access.redhat.com/ubi8/ubi:8.10-1184.1741863532 AS venus_php_base

ENV PHP_INI_DIR=/usr/local/etc/php
WORKDIR /var/www/html

# Install EPEL, Remi, PHP 8.3, Apache, and configure PHP-FPM and Apache
RUN dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm && \
    dnf install -y https://rpms.remirepo.net/enterprise/remi-release-$(rpm -E %rhel).rpm && \
    dnf module reset php -y && \
    dnf module enable php:remi-8.3 -y && \
    dnf update -y && \
    dnf install -y httpd php-gettext php83 php83-php-fpm php83-php-pecl-apcu php83-php-bcmath php83-php-gd \
    php83-php-intl php83-php-mbstring php83-php-opcache php83-php-pdo php83-php-soap php83-php-sodium \
    php83-php-xml php83-php-pecl-redis6 php83-php-pecl-zip acl dcmtk && \
    sed -i -e 's/;listen = 127.0.0.1:9000/listen = \/run\/php-fpm\/www.sock/g' \
           -e 's/;user = apache/user = apache/g' \
           -e 's/;group = apache/group = apache/g' \
           /etc/opt/remi/php83/php-fpm.d/www.conf && \
    sed -i -e 's/^#LoadModule\s*proxy_module/LoadModule proxy_module/' \
           -e 's/^#LoadModule\s*proxy_fcgi_module/LoadModule proxy_fcgi_module/' \
           /etc/httpd/conf.modules.d/00-proxy.conf && \
    echo "ServerName localhost" >> /etc/httpd/conf/httpd.conf && \
    mkdir -p /run/php-fpm /var/www/html/var/log /var/www/html/var/cache && \
    chown -R apache:apache /run/php-fpm && \
    chmod 775 /run/php-fpm && \
    dnf clean all

# Link php.ini file and copy apache config files
COPY ./.docker/php/venus.prod.ini "$PHP_INI_DIR"/php.ini
COPY .docker/apache/mod_proxy_fcgi.conf /etc/httpd/conf.d/
COPY .docker/apache/vhost.conf /etc/httpd/conf.d/

FROM venus_php_base AS venus_php

WORKDIR /var/www/html
ENV COMPOSER_ALLOW_SUPERUSER=1
COPY --from=app_copy /var/www/html/ ./

# App config
COPY --from=composer:2.2 /usr/bin/composer /usr/bin/composer

RUN ln -s /usr/bin/php83 /usr/local/bin/php
RUN composer install --no-dev --no-scripts --no-autoloader && composer dump-autoload --optimize

# Symfony CLI
RUN curl -1sLf 'https://dl.cloudsmith.io/public/symfony/stable/setup.rpm.sh' | bash && \
    dnf install symfony-cli php83-php-pecl-xdebug3 -y

# xdebug
# Copy compiled extensions and config files from php_pecl_builder
#COPY --from=php_pecl_builder /extensions/xdebug.so /usr/lib64/php/8.3/modules/
#COPY --from=php_pecl_builder /extensions/xdebug.ini /etc/opt/remi/php83/php.d/
RUN setfacl -m u:apache:rwx /tmp /var/www/html/var /var/www/html/var/log /var/www/html/var/cache

EXPOSE 80 443

# Start Apache and PHP-FPM
CMD ["/bin/bash", "-c", "/opt/remi/php83/root/usr/sbin/php-fpm -F & /usr/sbin/httpd -D FOREGROUND"]
