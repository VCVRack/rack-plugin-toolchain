FROM archlinux:base-20230709.0.163418
ENV LANG C.UTF-8

ARG JOBS

# Create unprivileged user to build toolchains and plugins
RUN groupadd -g 1000 build
RUN useradd --create-home --uid 1000 --gid 1000 --shell /bin/bash build

# Install make to run make
ENV DEBIAN_FRONTEND=noninteractive
RUN pacman -Suy --noconfirm && pacman -S make --noconfirm

# Create toolchain directory
USER build
RUN mkdir -p /home/build/rack-plugin-toolchain
WORKDIR /home/build/rack-plugin-toolchain

COPY Makefile /home/build/rack-plugin-toolchain/

# Install dependencies for building toolchains and plugins
USER root
RUN make dep-arch-linux

# Clean up files to free up space
RUN pacman -Sc --noconfirm

USER build
COPY MacOSX11.1.sdk.tar.* /home/build/rack-plugin-toolchain/

# Build toolchains
RUN JOBS=$JOBS make toolchain-mac
RUN JOBS=$JOBS make toolchain-win
RUN JOBS=$JOBS make toolchain-lin

RUN rm MacOSX11.1.sdk.tar.*
