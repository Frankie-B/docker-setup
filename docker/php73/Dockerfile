FROM php:7.3-fpm-bullseye
RUN sed -i 's/main/main contrib non-free/g' /etc/apt/sources.list
RUN useradd -u 1000 -s /bin/bash web
RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y apt-utils sudo nano nullmailer git git-flow lsb-release apt-transport-https ca-certificates \
mariadb-client rsync build-essential gnupg2 python2 python-is-python2
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y zlib1g-dev libpng-dev libonig-dev libffi-dev libicu-dev libxml2-dev \
libjpeg-dev libfreetype6-dev libjpeg62-turbo-dev libpng-dev libzip-dev libxslt-dev libpcre3-dev
# unixodbc-dev
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends libmagickwand-dev autoconf pkg-config libssl-dev
RUN echo 'web ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
RUN echo 'Version 1.0.0' > /etc/xcom_docker_version
RUN echo mailtrap > /etc/nullmailer/remotes

# install modules
RUN pecl install xdebug-3.1.6
RUN pecl install imagick-3.7.0

# mssql stuff
#RUN pecl install sqlsrv-5.8.1
#RUN pecl install pdo_sqlsrv-5.8.1
#RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
#RUN curl https://packages.microsoft.com/config/debian/11/prod.list > /etc/apt/sources.list.d/mssql-release.list
#RUN sudo apt-get update
#RUN ACCEPT_EULA=Y apt-get -y install msodbcsql17 mssql-tools

RUN docker-php-ext-configure gd --with-freetype-dir=/usr --with-jpeg-dir=/usr --with-png-dir=/usr
RUN docker-php-ext-install -j$(nproc) gd opcache pdo_mysql mysqli mbstring bcmath calendar exif fileinfo gettext intl soap xsl sockets zip
# other extensions we dont need right now
# mysqli pcntl hmop sockets sysvmsg sysvmsg sysvshm sysvsem ffi

RUN docker-php-ext-enable xdebug
RUN docker-php-ext-enable imagick

ADD conf.d/xdebug.ini "$PHP_INI_DIR/conf.d/docker-php-ext-xdebug.ini"
#ADD conf.d/sqlsrv.ini "$PHP_INI_DIR/conf.d/sqlsrv.ini"
#ADD conf.d/pdo_sqlsrv.ini "$PHP_INI_DIR/conf.d/pdo_sqlsrv.ini"

ADD run.sh /run.sh
RUN chmod +x /run.sh

#USER web
