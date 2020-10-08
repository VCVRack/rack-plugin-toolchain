# TODO upgrade to recent Ubuntu version
FROM ubuntu:16.04
ENV LANG C.UTF-8

# User to build toolchains and plugins
RUN groupadd -g 1000 build
RUN useradd --create-home --uid 1000 --gid 1000 --shell /bin/bash build

USER build
WORKDIR /home/build

RUN make toolchain-linux
RUN make toolchain-windows
RUN make toolchain-mac

# TODO untested