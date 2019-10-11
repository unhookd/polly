#!/bin/bash

set -exo pipefail

export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C.UTF-8
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8
#NOTE: this is here for msodbcsql17 package
export ACCEPT_EULA=y

apt-get update && \
  apt install -y locales locales-all

locale-gen --purge en_US.UTF-8 && /bin/echo -e  "LANG=$LANG\nLANGUAGE=$LANGUAGE\n" | tee /etc/default/locale \
  && locale-gen $LANGUAGE \
  && dpkg-reconfigure locales

#apt-add-repository ppa:brightbox/ruby-ng
#apt-get update \
#  && apt-get upgrade --no-install-recommends -y \
#  && apt-get install --no-install-recommends -y \

apt-get update \
&& apt-get upgrade --no-install-recommends -y --force-yes \
&& apt-get install --no-install-recommends -y --force-yes \
     git curl apt-transport-https aptitude ca-certificates apt-utils software-properties-common libyaml-dev  \
       apache2 apache2-utils \
       vim vim-common vim-runtime vim-tiny \
       nginx \
       jq \
       strace \
       ruby2* ruby2*-dev libruby2* ruby-bundler rubygems-integration build-essential \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

a2enmod dav dav_fs headers rewrite

mkdir -p /var/run/apache2; chown www-data /var/run/apache2
mkdir -p /usr/local/apache; chown www-data /usr/local/apache
mkdir -p /var/lock/apache2; chown www-data /var/lock/apache2
mkdir -p /var/log/apache2; chown www-data /var/log/apache2
mkdir -p /var/tmp; chown www-data /var/tmp

htpasswd -cb /etc/apache2/webdav.password guest guest
chown root:www-data /etc/apache2/webdav.password
chmod 640 /etc/apache2/webdav.password

echo "Listen 8080" | tee /etc/apache2/ports.conf

id app || useradd -G sudo --home-dir /home/app --create-home --shell /bin/bash app
mkdir -p /home/app/current && chown app. /home/app/current
