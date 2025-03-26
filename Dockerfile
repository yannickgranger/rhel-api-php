# Dockerfile
FROM registry.access.redhat.com/ubi8/ubi:8.10-1184.1741863532 AS venus_php

ENV PHP_INI_DIR=/usr/local/etc/php
WORKDIR /var/www/html

# Install EPEL Repository
RUN dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm

# Install Remi Repository (for PHP 8.3) - You might need to adjust this
RUN dnf install -y https://rpms.remirepo.net/enterprise/remi-release-$(rpm -E %rhel).rpm
RUN dnf module reset php -y
RUN dnf module enable php:remi-8.3 -y

# Link php.ini file
COPY ./.docker/php/venus.prod.ini "$PHP_INI_DIR"/php.ini

# Install Apache and PHP-FPM
RUN dnf update -y && dnf install -y httpd \
    php83-php-fpm php83 php83-php-bcmath php83-php-gd php83-php-intl \
    php83-php-mbstring php83-php-opcache php83-php-xml

# Configure PHP-FPM
RUN #sed -i -e 's/;listen = 127.0.0.1:9000/listen = \/run\/php-fpm\/www.sock/g' \
           -e 's/;user = apache/user = apache/g' \
           -e 's/;group = apache/group = apache/g' /etc/opt/remi/php83/php-fpm.d/www.conf

# Configure Apache to use PHP-FPM (mod_proxy_fcgi)
# Ensure mod_proxy and mod_proxy_fcgi are enabled
RUN sed -i -e 's/^#LoadModule\s*proxy_module/LoadModule proxy_module/' \
           -e 's/^#LoadModule\s*proxy_fcgi_module/LoadModule proxy_fcgi_module/' /etc/httpd/conf.modules.d/00-proxy.conf
 \
# Copy the Virtual Host configuration file
RUN echo "ServerName localhost" >> /etc/httpd/conf/httpd.conf
COPY .docker/apache/mod_proxy_fcgi.conf /etc/httpd/conf.d/
COPY .docker/apache/vhost.conf /etc/httpd/conf.d/

# Set Permissions
RUN mkdir -p /run/php-fpm
RUN chown -R apache:apache /var/www/html /run/php-fpm
RUN chmod 775 /run/php-fpm

COPY . ./

EXPOSE 80 443

# Start Apache and PHP-FPM
CMD ["/bin/bash", "-c", "/opt/remi/php83/root/usr/sbin/php-fpm -F & /usr/sbin/httpd -D FOREGROUND"]