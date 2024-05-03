FROM php:8.3-fpm-alpine

RUN set -o errexit -o nounset -o pipefail -o xtrace; \
    \
    # Install system packages.
    apk update; \
    apk upgrade; \
    apk \
        add --no-cache \
            aspell-dev \
            autoconf \
            bash \
            build-base \
            bzip2 \
            bzip2-dev \
            curl \
            ffmpeg \
            freetype-dev \
            git \
            hiredis-dev \
            icu \
            imagemagick-c++ \
            imagemagick-dev \
            libaio-dev \
            libbz2 \
            libjpeg-turbo-dev \
            libmcrypt-dev \
            libpng \
            libpng-dev \
            librdkafka-dev \
            libstdc++ \
            libtool \
            libwebp \
            libxml2-dev \
            libxslt-dev \
            libzip \
            libzip-dev \
            linux-headers \
            make \
            nano \
            oniguruma \
            openldap-dev \
            openssh \
            postgresql-dev \
            unzip \
            wget \
            yaml-dev \
            zip \
            zlib-dev; \
    \
    # Clean up.
    rm -fr /tmp/* /var/tmp/*

# Retrieve the script used to install PHP extensions from the source container.
COPY --from=mlocati/php-extension-installer:2.1.10 /usr/bin/install-php-extensions /usr/local/bin/

RUN set -o errexit -o nounset -o pipefail -o xtrace; \
    \
    # Install PHP extensions.
    install-php-extensions \
        apcu \
        bcmath \
        gd \
        igbinary \
        intl \
        ldap \
        opcache \
        pcntl \
        pdo_pgsql \
        redis \
        sockets \
        sqlsrv \
        xdebug \
        zip


COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
RUN set -o errexit -o nounset -o pipefail -o xtrace; \
    \
    composer --global config repos.packagist composer 'https://mirrors.tencent.com/composer/'
ENV COMPOSER_ALLOW_SUPERUSER=1
WORKDIR /var/www/html

FROM nginx:1.25.5-alpine-slim

ENV NJS_VERSION   0.8.4
ENV NJS_RELEASE   2

RUN set -x \
    && apkArch="$(cat /etc/apk/arch)" \
    && nginxPackages=" \
        nginx=${NGINX_VERSION}-r${PKG_RELEASE} \
        nginx-module-xslt=${NGINX_VERSION}-r${PKG_RELEASE} \
        nginx-module-geoip=${NGINX_VERSION}-r${PKG_RELEASE} \
        nginx-module-image-filter=${NGINX_VERSION}-r${PKG_RELEASE} \
        nginx-module-njs=${NGINX_VERSION}.${NJS_VERSION}-r${NJS_RELEASE} \
    " \
# install prerequisites for public key and pkg-oss checks
    && apk add --no-cache --virtual .checksum-deps \
        openssl \
    && case "$apkArch" in \
        x86_64|aarch64) \
# arches officially built by upstream
            apk add -X "https://nginx.org/packages/mainline/alpine/v$(egrep -o '^[0-9]+\.[0-9]+' /etc/alpine-release)/main" --no-cache $nginxPackages \
            ;; \
        *) \
# we're on an architecture upstream doesn't officially build for
# let's build binaries from the published packaging sources
            set -x \
            && tempDir="$(mktemp -d)" \
            && chown nobody:nobody $tempDir \
            && apk add --no-cache --virtual .build-deps \
                gcc \
                libc-dev \
                make \
                openssl-dev \
                pcre2-dev \
                zlib-dev \
                linux-headers \
                libxslt-dev \
                gd-dev \
                geoip-dev \
                libedit-dev \
                bash \
                alpine-sdk \
                findutils \
            && su nobody -s /bin/sh -c " \
                export HOME=${tempDir} \
                && cd ${tempDir} \
                && curl -f -O https://hg.nginx.org/pkg-oss/archive/93ac6e194ad0.tar.gz \
                && PKGOSSCHECKSUM=\"d56d10fbc6a1774e0a000b4322c5f847f8dfdcc3035b21cfd2a4a417ecce46939f39ff39ab865689b60cf6486c3da132aa5a88fa56edaad13d90715affe2daf0 *93ac6e194ad0.tar.gz\" \
                && if [ \"\$(openssl sha512 -r 93ac6e194ad0.tar.gz)\" = \"\$PKGOSSCHECKSUM\" ]; then \
                    echo \"pkg-oss tarball checksum verification succeeded!\"; \
                else \
                    echo \"pkg-oss tarball checksum verification failed!\"; \
                    exit 1; \
                fi \
                && tar xzvf 93ac6e194ad0.tar.gz \
                && cd pkg-oss-93ac6e194ad0 \
                && cd alpine \
                && make module-geoip module-image-filter module-njs module-xslt \
                && apk index -o ${tempDir}/packages/alpine/${apkArch}/APKINDEX.tar.gz ${tempDir}/packages/alpine/${apkArch}/*.apk \
                && abuild-sign -k ${tempDir}/.abuild/abuild-key.rsa ${tempDir}/packages/alpine/${apkArch}/APKINDEX.tar.gz \
                " \
            && cp ${tempDir}/.abuild/abuild-key.rsa.pub /etc/apk/keys/ \
            && apk del --no-network .build-deps \
            && apk add -X ${tempDir}/packages/alpine/ --no-cache $nginxPackages \
            ;; \
    esac \
# remove checksum deps
    && apk del --no-network .checksum-deps \
# if we have leftovers from building, let's purge them (including extra, unnecessary build deps)
    && if [ -n "$tempDir" ]; then rm -rf "$tempDir"; fi \
    && if [ -f "/etc/apk/keys/abuild-key.rsa.pub" ]; then rm -f /etc/apk/keys/abuild-key.rsa.pub; fi \
# Bring in curl and ca-certificates to make registering on DNS SD easier
    && apk add --no-cache curl ca-certificates
WORKDIR /www
CMD docker compose -f ./compose.yaml up -d

