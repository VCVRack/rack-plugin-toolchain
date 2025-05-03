FROM ubuntu:24.04
ENV LANG=C.UTF-8

ARG JOBS
ARG MACOS_SDK_VERSION

# Install make and sudo to bootstrap
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        make \
        sudo \
		ca-certificates \
		git \
		build-essential \
		autoconf \
		automake \
		bison \
		flex \
		gawk \
		libtool-bin \
		libncurses5-dev \
		unzip \
		zip \
		jq \
		libgl-dev \
		libglu-dev \
		git \
		wget \
		curl \
		cmake \
		nasm \
		xz-utils \
		file \
		python3 \
		libxml2-dev \
		libssl-dev \
		texinfo \
		help2man \
		libz-dev \
		rsync \
		xxd \
		perl \
		coreutils \
		zstd \
		markdown \
		libarchive-tools \
		gettext \
        libgmp-dev \
        libmpfr-dev
RUN echo "%sudo ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Create unprivileged user to build toolchains and plugins
RUN useradd --non-unique --create-home --uid 1000 --gid 1000 --shell /bin/bash build
RUN usermod -aG sudo build

# Switch user from root
USER build

# Create toolchain directory
RUN mkdir -p /home/build/rack-plugin-toolchain
WORKDIR /home/build/rack-plugin-toolchain

COPY Makefile /home/build/rack-plugin-toolchain/

# Clean up files to free up space
USER root
RUN rm -rf /var/lib/apt/lists/*

USER build
COPY MacOSX${MACOS_SDK_VERSION}.sdk.tar.* /home/build/rack-plugin-toolchain/

# Build toolchains
RUN JOBS=$JOBS make toolchain-mac
RUN JOBS=$JOBS make toolchain-win
RUN JOBS=$JOBS make toolchain-lin

RUN JOBS=$JOBS make cppcheck

RUN JOBS=$JOBS make rack-sdk-all

RUN rm MacOSX12.3.sdk.tar.*
