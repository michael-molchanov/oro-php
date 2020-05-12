FROM php:7.4-fpm-alpine

LABEL maintainer "Michael Molchanov <mmolchanov@adyax.com>"

USER root

# SSH config.
RUN mkdir -p /root/.ssh
ADD config/ssh /root/.ssh/config
RUN chown root:root /root/.ssh/config && chmod 600 /root/.ssh/config

RUN set -eux; apk add --no-cache --update --virtual .composer-rundeps \
  autoconf \
  automake \
  bash \
  build-base \
  bzip2 \
  ca-certificates \
  coreutils \
  curl \
  freetype \
  fuse \
  gawk \
  git \
  git-lfs \
  gmp \
  gmp-dev \
  grep \
  gzip \
  icu \
  jq \
  libbz2 \
  libffi \
  libffi-dev \
  libjpeg-turbo \
  libmcrypt \
  libpq \
  libpng \
  libtool \
  libxml2 \
  libxslt \
  libzip \
  make \
  mercurial \
  mysql-client \
  nasm \
  oniguruma \
  openssh \
  openssh-client \
  libressl \
  libressl-dev \
  patch \
  procps \
  postgresql-client \
  rsync \
  sqlite \
  strace \
  subversion \
  tar \
  tini \
  unzip \
  wget \
  zip \
  zlib

# Set the MozJpeg version.
ENV MOZJPEG_VERSION 3.3.1

# Install MozJpeg.
RUN curl -fsSL -o mozjpeg.tar.gz "https://github.com/mozilla/mozjpeg/archive/v${MOZJPEG_VERSION}.tar.gz" \
  && tar -zxf mozjpeg.tar.gz \
  && cd "mozjpeg-${MOZJPEG_VERSION}" \
  && autoreconf -fiv \
  && ./configure --prefix=/usr \
  && make install\
  && cd .. \
  && rm -rf "mozjpeg-${MOZJPEG_VERSION}"

# PHP modules.
RUN set -xe \
  && apk add --no-cache --update --virtual .build-deps \
    $PHPIZE_DEPS \
    curl-dev \
    libedit-dev \
    libxml2-dev \
    sqlite-dev \
    freetype-dev \
    libjpeg-turbo-dev \
    libmcrypt-dev \
    libpng-dev \
    bzip2-dev \
    libstdc++ \
    libxslt-dev \
    libzip-dev \
    libxml2-dev \
    icu-dev \
    oniguruma-dev \
    openldap-dev \
    postgresql-dev \
    zlib-dev \
  && export CFLAGS="$PHP_CFLAGS" \
    CPPFLAGS="$PHP_CPPFLAGS" \
    LDFLAGS="$PHP_LDFLAGS" \
  && docker-php-source extract \
  && cd /usr/src/php \
  && docker-php-ext-install bcmath zip bz2 gmp mbstring pcntl xsl mysqli pgsql pdo_mysql pdo_pgsql intl soap \
  && docker-php-ext-configure gd --with-freetype=/usr/include/ --with-jpeg=/usr/include/ \
  && docker-php-ext-install gd \
  && docker-php-ext-configure ldap --with-libdir=lib/ \
  && docker-php-ext-install ldap \
  && git clone --branch="develop" https://github.com/phpredis/phpredis.git /usr/src/php/ext/redis \
  && docker-php-ext-install redis \
  && php -m && php -r "new Redis();" \
  && pecl install channel://pecl.php.net/mcrypt-1.0.3 \
  && docker-php-ext-install sockets \
  && docker-php-source delete \
  && runDeps="$( \
    scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
      | tr ',' '\n' \
      | sort -u \
      | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
    )" \
  && apk add --no-cache --update --virtual .composer-phpext-rundeps $runDeps \
  && apk del .build-deps

RUN printf "# composer php cli ini settings\n\
date.timezone=UTC\n\
memory_limit=-1\n\
" > $PHP_INI_DIR/php-cli.ini

ENV COMPOSER_ALLOW_SUPERUSER 1
ENV COMPOSER_HOME /tmp
ENV COMPOSER_VERSION 1.10.6

RUN set -eux; \
  curl --silent --fail --location --retry 3 --output /tmp/installer.php --url https://raw.githubusercontent.com/composer/getcomposer.org/cb19f2aa3aeaa2006c0cd69a7ef011eb31463067/web/installer; \
  php -r " \
    \$signature = '48e3236262b34d30969dca3c37281b3b4bbe3221bda826ac6a9a62d6444cdb0dcd0615698a5cbe587c3f0fe57a54d8f5'; \
    \$hash = hash('sha384', file_get_contents('/tmp/installer.php')); \
    if (!hash_equals(\$signature, \$hash)) { \
      unlink('/tmp/installer.php'); \
      echo 'Integrity check failed, installer is either corrupt or worse.' . PHP_EOL; \
      exit(1); \
    }"; \
  php /tmp/installer.php --no-ansi --install-dir=/usr/bin --filename=composer --version=${COMPOSER_VERSION}; \
  composer --ansi --version --no-interaction; \
  rm -f /tmp/installer.php; \
  find /tmp -type d -exec chmod -v 1777 {} +

# Add composer downloads optimisation.
RUN composer global require hirak/prestissimo

# Set the Drush version.
ENV DRUSH_VERSION 10.2.2
RUN composer global require "drush/drush:$DRUSH_VERSION"

# Install Drush launcher with the phar file.
ENV DRUSH_LAUNCHER_FALLBACK=/tmp/vendor/drush/drush/drush
RUN curl -fsSL -o /usr/local/bin/drush "https://github.com/drush-ops/drush-launcher/releases/latest/download/drush.phar" && \
  chmod +x /usr/local/bin/drush

# Test your install.
RUN drush core-status

# Add git-secret package from edge testing
RUN apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/testing git-secret

# Install dependencies.
RUN apk add --update --no-cache \
  bash \
  binutils \
  ca-certificates \
  coreutils \
  curl \
  findutils \
  gcc \
  g++ \
  gifsicle \
  grep \
  libgcc \
  libjpeg-turbo-utils \
  libuv \
  libuv-dev \
  linux-headers \
  make \
  nasm \
  ncurses \
  openssl \
  optipng \
  python2 \
  util-linux \
  zlib-dev \
  && rm -rf /var/cache/apk/*

# Install nodejs and grunt.
RUN apk add --update --no-cache libuv nodejs-current npm nodejs-current-dev yarn \
  && rm -rf /var/cache/apk/* \
  && npm install -g gulp-cli grunt-cli bower \
  && node --version \
  && npm --version \
  && grunt --version \
  && gulp --version \
  && bower --version \
  && yarn versions

# Install compass.
RUN apk add --update --no-cache ruby ruby-dev \
  && rm -rf /var/cache/apk/* \
  && gem install --no-document compass

