ARG BASEPHP=7.4

FROM php:${BASEPHP}-fpm-buster as base

# install the PHP extensions we need
RUN set -eux; \
	\
	if command -v a2enmod; then \
		a2enmod rewrite; \
	fi; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	\
	apt-get update; \
	apt-get install -y --no-install-recommends \
		libfreetype6-dev \
		libjpeg-dev \
		libpng-dev \
		libpq-dev \
		libzip-dev \
	; \
	\
	docker-php-ext-configure gd \
		--with-freetype \
		--with-jpeg=/usr \
	; \
	\
	docker-php-ext-install -j "$(nproc)" \
		gd \
		opcache \
		pdo_mysql \
		pdo_pgsql \
		zip \
	; \
	\
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark; \
	ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
		| awk '/=>/ { print $3 }' \
		| sort -u \
		| xargs -r dpkg-query -S \
		| cut -d: -f1 \
		| sort -u \
		| xargs -rt apt-mark manual; \
	\
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /var/lib/apt/lists/*

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=60'; \
		echo 'opcache.fast_shutdown=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini

# https://github.com/drupal/drupal/blob/9.0.1/composer.lock#L4052-L4053
COPY --from=composer:1.10 /usr/bin/composer /usr/local/bin/

FROM base as drupalbase

## Templating binary
COPY --from=hairyhenderson/gomplate:v3.7.0-slim /gomplate /bin/gomplate

RUN curl -so /usr/local/bin/php-fpm-healthcheck \
	https://raw.githubusercontent.com/renatomefi/php-fpm-healthcheck/master/php-fpm-healthcheck &&\
	chmod +x /usr/local/bin/php-fpm-healthcheck &&\
	echo "pm.status_path = /status" >> /usr/local/etc/php-fpm.d/zz-docker.conf

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    git \
    vim \
    rsync \
	libfcgi-bin \
    openssh-client && \
    apt-get clean -y && \
    apt-get autoclean -y && \
    apt-get autoremove -y && \
    rm -rf /var/lib/{apt,dpkg,cache,log}/ && \
    rm -rf /var/lib/apt/lists/*

## Install drush
RUN composer global require drush/drush:^9.0 && \
    mv $HOME/.composer /usr/local/share/composer && \
    ln -s /usr/local/share/composer/vendor/drush/drush/drush /usr/local/bin/drush

## Install drupal console
RUN curl https://drupalconsole.com/installer -L -o /usr/local/bin/drupal && \
    chmod +x /usr/local/bin/drupal

## Set drush config
RUN mkdir -p /etc/drush/sites/
COPY assets/drush/drush.yml /etc/drush/drush.yml

COPY assets/ /assets

WORKDIR /var/www/html

EXPOSE 9000

ENTRYPOINT ["/assets/bin/docker-entrypoint.sh"]
CMD ["php-fpm","--fpm-config","/usr/local/etc/php-fpm.conf","-c","/usr/local/etc/php/php.ini"]

FROM drupalbase

ARG DRUPAL_VERSION=8.9.3

RUN set -eux; \
	export COMPOSER_HOME="$(mktemp -d)"; \
	composer create-project --no-interaction "drupal/recommended-project:${DRUPAL_VERSION}" ./; \
	chown -R www-data:www-data web/sites web/modules web/themes; \
	rm -rf "$COMPOSER_HOME"

RUN COMPOSER_MEMORY_LIMIT=-1 composer require drupal/s3fs --prefer-dist