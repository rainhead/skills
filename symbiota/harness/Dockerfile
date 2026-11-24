FROM php:8.2-apache
RUN apt-get update && apt-get install -y libzip-dev libpng-dev libjpeg-dev libfreetype6-dev libonig-dev libxml2-dev libcurl4-openssl-dev unzip curl && docker-php-ext-configure gd --with-jpeg --with-freetype && docker-php-ext-install mysqli zip gd mbstring xml curl && a2enmod rewrite && rm -rf /var/lib/apt/lists/*
RUN printf 'upload_max_filesize=200M\npost_max_size=200M\nmemory_limit=1G\nmax_execution_time=600\nmax_input_vars=10000\nallow_url_fopen=On\n' > /usr/local/etc/php/conf.d/sym.ini
RUN printf 'Alias /sym /var/www/html\n<Directory /var/www/html>\nAllowOverride All\nRequire all granted\n</Directory>\n' > /etc/apache2/conf-enabled/sym.conf
