#!/bin/sh
set -eu

MAX_CHILDREN=${PHP_FPM_POOL_MAX_CHILDREN:-5}
PHP_FPM_POOL_CFG=/usr/local/etc/php-fpm.d/www.conf

echo "set php fpm max children to value ${MAX_CHILDREN} (default: 5)"
sed -i "s/^pm.max_children = .*/pm.max_children = ${MAX_CHILDREN}/" $PHP_FPM_POOL_CFG
