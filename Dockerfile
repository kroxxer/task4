FROM webdevops/php-nginx:8.2-alpine

ENV COMPOSER_ALLOW_SUPERUSER=1
ENV PGSSLCERT /tmp/postgresql.crt

RUN apk add --no-cache bash &&\
curl -sS 'https://dl.cloudsmith.io/public/symfony/stable/setup.alpine.sh' | bash &&\
apk add symfony-cli

ENV WEB_DOCUMENT_ROOT=/app/public
ENV WEB_DOCUMENT_INDEX=index.php

WORKDIR /app
COPY . /app

RUN composer install

EXPOSE 443

CMD ["symfony", "server:start"]