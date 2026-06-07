# Multi-stage build for PHP-FPM with Magento 2

# Stage 1: Composer stage
FROM composer:2.6 AS composer

ARG MAGENTO_VERSION=2.4.6

WORKDIR /tmp

# Create composer.json for Magento 2
RUN echo '{\n\
  "name": "magento/project-community-edition",\n\
  "description": "Magento 2 Community Edition",\n\
  "type": "project",\n\
  "license": "Open Software License (OSL 3.0)",\n\
  "require": {\n\
    "magento/product-community-edition": "'${MAGENTO_VERSION}'"\n\
  },\n\
  "require-dev": {\n\
    "phpstan/phpstan": "^1.0"\n\
  },\n\
  "config": {\n\
    "allow-plugins": {\n\
      "dealerdirect/phpcodesniffer-composer-installer": true,\n\
      "magento/*": true\n\
    }\n\
  }\n\
}' > composer.json

# Install Magento via Composer
RUN composer install --no-dev --optimize-autoloader

# Stage 2: Runtime stage
FROM php:8.1-fpm-alpine

ARG MAGENTO_VERSION=2.4.6

# Install system dependencies
RUN apk add --no-cache \
    libzip-dev \
    zip \
    unzip \
    git \
    curl \
    wget \
    mysql-client \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    icu-dev \
    libxslt-dev \
    imagemagick-dev \
    libmemcached-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure intl \
    && docker-php-ext-install -j$(nproc) \
    gd \
    mysqli \
    pdo \
    pdo_mysql \
    intl \
    xsl \
    zip \
    soap \
    bcmath \
    opcache \
    && pecl install memcached \
    && docker-php-ext-enable memcached \
    && apk del autoconf automake build-base libtool pkgconfig re2c

# Install Composer
COPY --from=composer /usr/bin/composer /usr/bin/composer

# Create application user
ARG TEST_USER=test-ssh
ARG TEST_GROUP=clp
ARG TEST_USER_ID=1000
ARG TEST_GROUP_ID=1001

RUN addgroup -g ${TEST_GROUP_ID} ${TEST_GROUP} && \
    adduser -D -u ${TEST_USER_ID} -G ${TEST_GROUP} ${TEST_USER}

# Set working directory
WORKDIR /var/www/html

# Copy Magento from composer stage
COPY --from=composer --chown=${TEST_USER}:${TEST_GROUP} /tmp/vendor ./vendor
COPY --from=composer --chown=${TEST_USER}:${TEST_GROUP} /tmp/composer.* ./

# Download Magento source (sample data will be installed separately)
RUN git clone --depth 1 --branch ${MAGENTO_VERSION} https://github.com/magento/magento2.git . || \
    curl -fsSL https://github.com/magento/magento2/archive/${MAGENTO_VERSION}.tar.gz | tar xz --strip-components=1

# PHP Configuration for Magento
RUN echo 'memory_limit = 2G' > /usr/local/etc/php/conf.d/magento.ini && \
    echo 'max_execution_time = 300' >> /usr/local/etc/php/conf.d/magento.ini && \
    echo 'upload_max_filesize = 64M' >> /usr/local/etc/php/conf.d/magento.ini && \
    echo 'post_max_size = 64M' >> /usr/local/etc/php/conf.d/magento.ini && \
    echo 'always_populate_raw_post_data = -1' >> /usr/local/etc/php/conf.d/magento.ini && \
    echo 'date.timezone = UTC' >> /usr/local/etc/php/conf.d/magento.ini

# OPcache configuration
RUN echo '[opcache]' > /usr/local/etc/php/conf.d/opcache.ini && \
    echo 'opcache.enable=1' >> /usr/local/etc/php/conf.d/opcache.ini && \
    echo 'opcache.memory_consumption=256' >> /usr/local/etc/php/conf.d/opcache.ini && \
    echo 'opcache.interned_strings_buffer=8' >> /usr/local/etc/php/conf.d/opcache.ini && \
    echo 'opcache.max_accelerated_files=10000' >> /usr/local/etc/php/conf.d/opcache.ini && \
    echo 'opcache.revalidate_freq=2' >> /usr/local/etc/php/conf.d/opcache.ini

# Set permissions
RUN mkdir -p var pub/media pub/static generated && \
    chown -R ${TEST_USER}:${TEST_GROUP} /var/www/html && \
    find /var/www/html -type f -exec chmod 640 {} \; && \
    find /var/www/html -type d -exec chmod 750 {} \;

# Create entrypoint script
RUN echo '#!/bin/sh\n\
if [ ! -f /var/www/html/app/etc/env.php ]; then\n\
  php bin/magento setup:install \\\n\
    --base-url=${MAGENTO_BASE_URL} \\\n\
    --base-url-secure=${MAGENTO_BASE_SECURE_URL} \\\n\
    --db-host=${MYSQL_HOST} \\\n\
    --db-name=${MYSQL_DATABASE} \\\n\
    --db-user=${MYSQL_USER} \\\n\
    --db-password=${MYSQL_PASSWORD} \\\n\
    --admin-firstname=Admin \\\n\
    --admin-lastname=User \\\n\
    --admin-email=admin@test.dyna.com \\\n\
    --admin-user=admin \\\n\
    --admin-password=Admin@123456 \\\n\
    --language=en_US \\\n\
    --currency=USD \\\n\
    --timezone=UTC \\\n\
    --search-engine=elasticsearch7 \\\n\
    --elasticsearch-host=${ELASTICSEARCH_HOST} \\\n\
    --elasticsearch-port=${ELASTICSEARCH_PORT}\n\
fi\n\
\n\
exec php-fpm\n\
' > /usr/local/bin/docker-entrypoint.sh && \
    chmod +x /usr/local/bin/docker-entrypoint.sh

USER ${TEST_USER}

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
