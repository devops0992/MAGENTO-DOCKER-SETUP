FROM php:8.1-fpm-alpine

ARG TEST_USER=test-ssh
ARG TEST_GROUP=clp
ARG TEST_USER_ID=1000
ARG TEST_GROUP_ID=1001
ARG MAGENTO_VERSION=2.4.6

# Install packages
RUN apk add --no-cache \
    git \
    curl \
    wget \
    unzip \
    zip \
    bash \
    mysql-client \
    libzip-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    icu-dev \
    libxslt-dev \
    oniguruma-dev \
    linux-headers

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install -j$(nproc) \
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
    sockets

# Install Composer
COPY --from=composer:2.6 /usr/bin/composer /usr/local/bin/composer

# Create user
RUN addgroup -g ${TEST_GROUP_ID} ${TEST_GROUP} && \
    adduser -D -u ${TEST_USER_ID} -G ${TEST_GROUP} ${TEST_USER}

WORKDIR /var/www/html

# Download Magento source
RUN git clone --depth 1 --branch ${MAGENTO_VERSION} \
    https://github.com/magento/magento2.git .

# PHP settings
RUN echo "memory_limit=2G" > /usr/local/etc/php/conf.d/magento.ini && \
    echo "max_execution_time=300" >> /usr/local/etc/php/conf.d/magento.ini && \
    echo "upload_max_filesize=64M" >> /usr/local/etc/php/conf.d/magento.ini && \
    echo "post_max_size=64M" >> /usr/local/etc/php/conf.d/magento.ini && \
    echo "date.timezone=UTC" >> /usr/local/etc/php/conf.d/magento.ini

# Create Magento writable directories
RUN mkdir -p \
    var \
    pub/static \
    pub/media \
    generated

# Permissions
RUN chown -R ${TEST_USER}:${TEST_GROUP} /var/www/html

USER ${TEST_USER}

EXPOSE 9000

CMD ["php-fpm"]
