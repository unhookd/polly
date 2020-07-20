#!/bin/bash

set -e

export  DEBIAN_FRONTEND=noninteractive
export  LC_ALL=C.UTF-8
export  LANG=en_US
export  LANGUAGE=en_US
export  ACCEPT_EULA=y
apt-get update; apt-get install -y locales locales-all; apt-get clean; rm -rf /var/lib/apt/lists/*
locale-gen --purge en_US
/bin/echo -e "LANG=$LANG\nLANGUAGE=$LANGUAGE\n" | tee /etc/default/locale
locale-gen $LANGUAGE
dpkg-reconfigure locales
apt-get update; apt-get install -y openssh-client git curl apt-transport-https aptitude ca-certificates apt-utils software-properties-common docker.io containerd build-essential libyaml-dev ruby2* libruby2* ruby-bundler rubygems-integration rake; apt-get clean; rm -rf /var/lib/apt/lists/*

export SSH_AUTH_SOCK=/tmp/ssh-auth.sock
#ssh-keyscan github.com >> ~/.ssh/known_hosts
ssh-agent -a $SSH_AUTH_SOCK > /dev/null

useradd --uid 1001 --home-dir /home/app --create-home --shell /bin/bash app
chown -R app /home/app
groupadd --gid 134 docker-extra
adduser app docker-extra
adduser app docker
chown -R app /home/app
su app -s /bin/test -- -w $SSH_AUTH_SOCK || (chmod g+w $SSH_AUTH_SOCK && chgrp 1001 $SSH_AUTH_SOCK && chgrp 1001 $(dirname $SSH_AUTH_SOCK) && chmod g+x $(dirname $SSH_AUTH_SOCK) && su app -s /bin/test -- -w $SSH_AUTH_SOCK)
test -z $DOCKER_CERT_PATH || (chown -R 1001 $(dirname $DOCKER_CERT_PATH))
su app -s /bin/bash -c 'bundle config set --local path /home/app/vendor/bundle && bundle config set --local jobs 4 && bundle config set --local retry 3 && bundle config set --local deploment true && bundle config set --local without development && bundle install'
su app -w SSH_AUTH_SOCK,DOCKER_CERT_PATH,DOCKER_HOST,DOCKER_MACHINE_NAME,DOCKER_TLS_VERIFY,NO_PROXY -s bin/polly -- build
