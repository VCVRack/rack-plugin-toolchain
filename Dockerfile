FROM ubuntu:20.04
ENV LANG C.UTF-8

# User to build toolchains and plugins
RUN groupadd -g 1000 build
RUN useradd --create-home --uid 1000 --gid 1000 --shell /bin/bash build

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends make

WORKDIR /home/build

COPY Makefile /home/build/Makefile

# Install dependencies for building toolchains and plugins
RUN make dep-ubuntu

USER build
COPY MacOSX10.13.sdk.tar.xz /home/build/MacOSX10.13.sdk.tar.xz

RUN make toolchain-all

RUN rm /home/build/MacOSX10.13.sdk.tar.xz
RUN rm /home/build/build.log
