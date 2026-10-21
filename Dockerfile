# Base independente do ciclo de atualização da imagem oficial wordpress no Docker Hub
# Para atualizar: altere PHP_VERSION ou WP_VERSION abaixo e faça push com a nova tag
ARG PHP_VERSION=8.2.35
ARG WP_VERSION=7.1.3
FROM php:${PHP_VERSION}-apache

LABEL maintainer="Edidesk <contato@edidesk.com.br>"
LABEL description="WordPress customizado com configurações de PHP otimizadas - Edidesk"

# Dependências persistentes do sistema
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ghostscript \
        libheif-plugin-aomenc \
        libheif-plugin-x265 \
    ; \
    rm -rf /var/lib/apt/lists/*

# Extensões PHP necessárias para WordPress
RUN set -ex; \
    savedAptMark="$(apt-mark showmanual)"; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        libavif-dev \
        libfreetype6-dev \
        libicu-dev \
        libjpeg-dev \
        libmagickwand-dev \
        libpng-dev \
        libwebp-dev \
        libzip-dev \
    ; \
    docker-php-ext-configure gd \
        --with-avif \
        --with-freetype \
        --with-jpeg \
        --with-webp \
    ; \
    docker-php-ext-install -j "$(nproc)" \
        bcmath \
        exif \
        gd \
        intl \
        mysqli \
        zip \
    ; \
    pecl install imagick-3.8.1; \
    docker-php-ext-enable imagick; \
    rm -r /tmp/pear; \
    apt-mark auto '.*' > /dev/null; \
    apt-mark manual $savedAptMark; \
    ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
        | awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
        | sort -u \
        | xargs -r dpkg-query --search \
        | cut -d: -f1 \
        | sort -u \
        | xargs -rt apt-mark manual; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/*

# OPcache
RUN set -eux; \
    { \
        echo 'opcache.memory_consumption=128'; \
        echo 'opcache.interned_strings_buffer=8'; \
        echo 'opcache.max_accelerated_files=4000'; \
        echo 'opcache.revalidate_freq=2'; \
    } > "$PHP_INI_DIR/conf.d/opcache-recommended.ini"

# Log de erros
RUN set -eux; \
    { \
        echo 'error_reporting = E_ERROR | E_WARNING | E_PARSE | E_CORE_ERROR | E_CORE_WARNING | E_COMPILE_ERROR | E_COMPILE_WARNING | E_RECOVERABLE_ERROR'; \
        echo 'display_errors = Off'; \
        echo 'display_startup_errors = Off'; \
        echo 'log_errors = On'; \
        echo 'error_log = /dev/stderr'; \
        echo 'log_errors_max_len = 1024'; \
        echo 'ignore_repeated_errors = On'; \
        echo 'ignore_repeated_source = Off'; \
        echo 'html_errors = Off'; \
    } > "$PHP_INI_DIR/conf.d/error-logging.ini"

# Apache: rewrite, expires, remoteip (necessário atrás de proxy/Traefik)
RUN set -eux; \
    a2enmod rewrite expires; \
    a2enmod remoteip; \
    { \
        echo 'RemoteIPHeader X-Forwarded-For'; \
        echo 'RemoteIPInternalProxy 10.0.0.0/8'; \
        echo 'RemoteIPInternalProxy 172.16.0.0/12'; \
        echo 'RemoteIPInternalProxy 192.168.0.0/16'; \
        echo 'RemoteIPInternalProxy 169.254.0.0/16'; \
        echo 'RemoteIPInternalProxy 127.0.0.0/8'; \
    } > /etc/apache2/conf-available/remoteip.conf; \
    a2enconf remoteip; \
    find /etc/apache2 -type f -name '*.conf' -exec sed -ri 's/([[:space:]]*LogFormat[[:space:]]+"[^"]*)(%)h([^"]*")/\1%a\3/g' '{}' +

# Download e verificação do WordPress
ARG WP_VERSION
RUN set -eux; \
    version="${WP_VERSION}"; \
    sha1='491a78c7676b15dffcc69130c6054b8f49228a91'; \
    curl -o wordpress.tar.gz -fL "https://wordpress.org/wordpress-$version.tar.gz"; \
    echo "$sha1 *wordpress.tar.gz" | sha1sum -c -; \
    tar -xzf wordpress.tar.gz -C /usr/src/; \
    rm wordpress.tar.gz; \
    [ ! -e /usr/src/wordpress/.htaccess ]; \
    { \
        echo '# BEGIN WordPress'; \
        echo ''; \
        echo 'RewriteEngine On'; \
        echo 'RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]'; \
        echo 'RewriteBase /'; \
        echo 'RewriteRule ^index\.php$ - [L]'; \
        echo 'RewriteCond %{REQUEST_FILENAME} !-f'; \
        echo 'RewriteCond %{REQUEST_FILENAME} !-d'; \
        echo 'RewriteRule . /index.php [L]'; \
        echo ''; \
        echo '# END WordPress'; \
    } > /usr/src/wordpress/.htaccess; \
    chown -R www-data:www-data /usr/src/wordpress; \
    mkdir wp-content; \
    for dir in /usr/src/wordpress/wp-content/*/ cache; do \
        dir="$(basename "${dir%/}")"; \
        mkdir "wp-content/$dir"; \
    done; \
    chown -R www-data:www-data wp-content; \
    chmod -R 1777 wp-content

VOLUME /var/www/html

# Arquivos de configuração e entrypoint do WordPress (fonte oficial)
ADD https://raw.githubusercontent.com/docker-library/wordpress/master/wp-config-docker.php /usr/src/wordpress/wp-config-docker.php
ADD https://raw.githubusercontent.com/docker-library/wordpress/master/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chown www-data:www-data /usr/src/wordpress/wp-config-docker.php \
    && chmod +x /usr/local/bin/docker-entrypoint.sh \
    && ln -svfT docker-entrypoint.sh /usr/local/bin/docker-ensure-installed.sh

# Configurações customizadas de PHP (inclui mitigações para CVE-2026-109618 e CVE-2026-109619)
RUN mkdir -p /usr/local/etc/php/conf.d
COPY custom-php.ini /usr/local/etc/php/conf.d/custom-php.ini

RUN chown -R www-data:www-data /var/www/html

EXPOSE 80

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
