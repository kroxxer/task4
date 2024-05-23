FROM webdevops/php-nginx:8.2-alpine

RUN apk add --no-cache bash &&\
curl -sS 'https://dl.cloudsmith.io/public/symfony/stable/setup.alpine.sh' | bash &&\
apk add symfony-cli

WORKDIR /app
COPY . /app

ENV COMPOSER_ALLOW_SUPERUSER=1
RUN composer install
ENV PGSSLCERT /tmp/postgresql.crt

ENV WEB_DOCUMENT_ROOT=/app/public
ENV WEB_DOCUMENT_INDEX=index.php

EXPOSE 443

CMD ["symfony", "server:start"]