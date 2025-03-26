#!/bin/bash
set -e

# Start PHP-FPM
/usr/sbin/php-fpm --nodaemonize --fpm-config /etc/php-fpm.conf &

# Start Apache in the foreground
exec /usr/sbin/httpd -D FOREGROUND