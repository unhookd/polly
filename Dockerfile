# syntax=docker/dockerfile:1.0.0-experimental
FROM ubuntu:bionic-20180526 AS build 
ENV DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8 LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8 ACCEPT_EULA=y
RUN set -ex; apt-get update; apt install -y locales locales-all; apt-get clean; rm -rf /var/lib/apt/lists/*
RUN set -ex; locale-gen --purge en_US.UTF-8
RUN set -ex; /bin/echo -e "LANG=$LANG\nLANGUAGE=$LANGUAGE\n" | tee /etc/default/locale
RUN set -ex; locale-gen $LANGUAGE
RUN set -ex; dpkg-reconfigure locales
RUN set -ex; apt-get update; apt install -y git curl apt-transport-https aptitude ca-certificates apt-utils software-properties-common; apt-get clean; rm -rf /var/lib/apt/lists/*
RUN set -ex; touch /a
# Generated 2020-01-28 06:11:45 -0500
# syntax=docker/dockerfile:1.0.0-experimental
FROM build AS deploy 
RUN set -ex; useradd --home-dir /home/app --create-home --shell /bin/bash app
RUN set -ex; apt-add-repository ppa:brightbox/ruby-ng
RUN set -ex; apt-get update; apt install -y build-essential libyaml-dev ruby2.6*-dev libruby2* ruby-bundler rubygems-integration ruby2.6* rake; apt-get clean; rm -rf /var/lib/apt/lists/*
COPY --chown=app . /home/app/current
USER app
WORKDIR /home/app/current
RUN set -ex; bundle install --path=vendor/bundle --jobs=4 --retry=3 --deployment --without "development"
RUN set -ex; bundle exec rake build
USER root
RUN set -ex; ln -fs /home/app/current/bin/polly /usr/local/bin/polly
# Generated 2020-01-28 06:11:45 -0500
# syntax=docker/dockerfile:1.0.0-experimental
FROM deploy AS test 
USER app
WORKDIR /home/app/current
RUN set -ex; bundle install --path=vendor/bundle --jobs=4 --retry=3 --deployment --with "development"
USER root
USER app
WORKDIR /home/app/current
# Generated 2020-01-28 06:11:45 -0500
