FROM ubuntu:20.04
ENV LANG C.UTF-8

# User to build toolchains and plugins
RUN groupadd -g 1000 build
RUN useradd --create-home --uid 1000 --gid 1000 --shell /bin/bash build

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends make

USER build
RUN mkdir -p /home/build/rack-plugin-toolchain
WORKDIR /home/build/rack-plugin-toolchain

COPY Makefile /home/build/rack-plugin-toolchain/

# Install dependencies for building toolchains and plugins
USER root
RUN make dep-ubuntu
RUN rm -rf /var/lib/apt/lists/*

USER build
COPY MacOSX10.13.sdk.tar.* /home/build/rack-plugin-toolchain/

RUN make toolchain-mac
RUN make toolchain-win
RUN make toolchain-lin

RUN rm MacOSX10.13.sdk.tar.*
