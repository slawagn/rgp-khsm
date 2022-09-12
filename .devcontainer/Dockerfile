FROM ruby:2.4

RUN apt-get update &&   \
    apt-get install -y  \
      sudo

RUN useradd             \
      --create-home     \
      --groups sudo     \
      --shell /bin/bash \
      code
RUN adduser code sudo
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
USER code

WORKDIR /workspaces/khsm

RUN sudo apt-get install -y  \
      nodejs                 \
      npm
RUN sudo npm install --global yarn

COPY Gemfile Gemfile.lock ./
RUN bundle install
