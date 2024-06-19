# DOCKER_NAME=jenkins-tap-test-bookworm
FROM docker.mgm.sipwise.com/sipwise-bookworm:latest

# Important! Update this no-op ENV variable when this Dockerfile
# is updated with the current date. It will force refresh of all
# of the base images and things like `apt-get update` won't be using
# old cached versions when the Dockerfile is built.
ENV REFRESHED_AT 2024-06-19

# we want to use jenkins-debian-glue from our own internal
# repository and not from Debian
RUN echo 'deb https://deb.sipwise.com/autobuild internal-bookworm main'  > /etc/apt/sources.list.d/internal.list

RUN apt-get update && apt-get install --assume-yes --no-install-recommends \
  binutils \
  file \
  jenkins-debian-glue \
  libperl-critic-perl \
  parallel \
  pycodestyle \
  ruby \
  shellcheck \
  xz-utils && \
  apt-get clean

# The package devscripts has a huge list of dependencies and
# we need checkbashisms script only, providing it manually
RUN mkdir /tmp/zzz && \
  cd /tmp/zzz && \
  apt-get download devscripts && \
  dpkg --fsys-tarfile devscripts_*.deb | tar -C / -p -xv ./usr/bin/checkbashisms && \
  rm -rf /tmp/zzz

COPY t/tap-tests-docker/perlcriticrc /root/.perlcriticrc

# Set LC_ALL, otherwise shellcheck before v0.4.7 fails:
# source/somefile: hGetContents: invalid argument (invalid byte sequence)
# https://github.com/koalaman/shellcheck/issues/324
RUN echo 'LC_ALL=C.UTF-8 SHELL=bash WORKSPACE=/code/ /usr/bin/tap_tool_dispatcher' >>/root/.bash_history

WORKDIR /code/

################################################################################
# Instructions for usage
# ----------------------
# When you want to build the base image from scratch
# (jump to the next section if you don't want to build yourself!):
# NOTE: run the following command from root folder of git repository:
#
# % docker build --tag="jenkins-tap-test-bookworm" -f t/tap-tests-docker/Dockerfile .
# % docker run --rm -i -t -v $(pwd):/code/source:rw jenkins-tap-test-bookworm:latest bash
#
# Use the existing docker image:
# % docker pull docker.mgm.sipwise.com/jenkins-tap-test-bookworm
# % docker run --rm -i -t -v $(pwd):/code/source:rw docker.mgm.sipwise.com/jenkins-tap-test-bookworm:latest bash
#
# Inside docker (the command is in history, just press UP button):
#   LC_ALL=C.UTF-8 SHELL=bash WORKSPACE=/code/ /usr/bin/tap_tool_dispatcher
#
################################################################################
