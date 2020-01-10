FROM ubuntu:bionic-20180526

USER root

COPY bin/bootstrap.sh /var/tmp/bootstrap.sh

RUN /var/tmp/bootstrap.sh

COPY --chown=app Gemfile Gemfile.lock polly.gemspec /var/tmp/polly/
COPY --chown=app lib/polly.rb /var/tmp/polly/lib/polly.rb

WORKDIR /var/tmp/polly

USER app

RUN bundle install --path=vendor/bundle

COPY . /var/tmp/polly/

RUN bundle exec rake build

USER root

RUN gem install pkg/*gem && \
    gem list && \
    which polly && polly help

COPY config/apache.conf /etc/apache2/sites-available/000-default.conf
COPY config/nginx-apt-proxy.conf /etc/nginx/conf.d/
COPY config/git-repo-template /usr/share/git-core/templates/
COPY config/Procfile.init /var/lib/polly/

USER app
