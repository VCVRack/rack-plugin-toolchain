# Installation path for executables
LOCAL_DIR := $(PWD)/local
# Local programs should have higher path priority than system-installed programs
export PATH := $(LOCAL_DIR)/bin:$(PATH)


all: toolchain-all


# Toolchain build


crosstool-ng := $(LOCAL_DIR)/bin/ct-ng
$(crosstool-ng):
	wget -c "http://crosstool-ng.org/download/crosstool-ng/crosstool-ng-1.24.0.tar.xz"
	tar -xf crosstool-ng-1.24.0.tar.xz
	rm crosstool-ng-1.24.0.tar.xz
	cd crosstool-ng-1.24.0 && ./bootstrap
	cd crosstool-ng-1.24.0 && ./configure --prefix="$(LOCAL_DIR)"
	cd crosstool-ng-1.24.0 && make
	cd crosstool-ng-1.24.0 && make install
	rm -rf crosstool-ng-1.24.0


toolchain-lin := $(LOCAL_DIR)/x86_64-ubuntu16.04-linux-gnu
toolchain-lin: $(toolchain-lin)
$(toolchain-lin): $(crosstool-ng)
	ct-ng x86_64-ubuntu16.04-linux-gnu
	CT_PREFIX="$(LOCAL_DIR)" ct-ng build
	rm -rf .build .config build.log
	# HACK Copy GL include dir to toolchain sysroot
	chmod +w $(toolchain-lin)/x86_64-ubuntu16.04-linux-gnu/sysroot/usr/include
	cp -r /usr/include/GL $(toolchain-lin)/x86_64-ubuntu16.04-linux-gnu/sysroot/usr/include/
	chmod -w $(toolchain-lin)/x86_64-ubuntu16.04-linux-gnu/sysroot/usr/include


toolchain-win := $(LOCAL_DIR)/x86_64-w64-mingw32
toolchain-win: $(toolchain-win)
$(toolchain-win): $(crosstool-ng)
	ct-ng x86_64-w64-mingw32
	CT_PREFIX="$(LOCAL_DIR)" ct-ng build
	rm -rf .build .config build.log


toolchain-mac := $(LOCAL_DIR)/osxcross
toolchain-mac: $(toolchain-mac)
MAC_CLANG_VERSION := 10.0.1
MAC_BINUTILS_VERSION := 2.35
# Binaries from ./build.sh must be available in order to run ./build_binutils.sh
$(toolchain-mac): export PATH := $(LOCAL_DIR)/osxcross/bin:$(PATH)
$(toolchain-mac):
	# Download osxcross
	git clone "https://github.com/tpoechtrager/osxcross.git" osxcross
	cd osxcross && git checkout a791ad4fca685ea9fceb520b77db586881cd3f3d

	# Build clang
	cd osxcross && UNATTENDED=1 DISABLE_BOOTSTRAP=1 INSTALLPREFIX="$(LOCAL_DIR)" CLANG_VERSION=$(MAC_CLANG_VERSION) OCDEBUG=1 ./build_clang.sh
	cd osxcross/build/llvm-$(MAC_CLANG_VERSION).src/build && make install

	# Build osxcross
	cp MacOSX10.13.sdk.tar.* osxcross/tarballs/
	cd osxcross && UNATTENDED=1 TARGET_DIR="$(LOCAL_DIR)/osxcross" ./build.sh

	# Build Mac version of binutils and build LLVM gold
	cd osxcross && BINUTILS_VERSION=$(MAC_BINUTILS_VERSION) TARGET_DIR="$(LOCAL_DIR)/osxcross" ./build_binutils.sh
	cd osxcross/build/llvm-$(MAC_CLANG_VERSION).src/build && cmake .. -DLLVM_BINUTILS_INCDIR=$(PWD)/osxcross/build/binutils-$(MAC_BINUTILS_VERSION)/include && make install

	rm -rf osxcross


rack-sdk := Rack-SDK
rack-sdk: $(rack-sdk)
$(rack-sdk):
	wget -c "https://vcvrack.com/downloads/Rack-SDK-1.1.6.zip"
	unzip Rack-SDK-1.1.6.zip
	rm Rack-SDK-1.1.6.zip
RACK_DIR := $(PWD)/$(rack-sdk)


toolchain-all: toolchain-lin toolchain-win toolchain-mac rack-sdk


toolchain-clean:
	rm -rf local osxcross $(rack-sdk)


# Plugin build


PLUGIN_BUILD_DIR := plugin-build
PLUGIN_DIR ?=


plugin-build-mac: export PATH := $(LOCAL_DIR)/osxcross/bin:$(PATH)
plugin-build-mac: export CC := x86_64-apple-darwin17-clang
plugin-build-mac: export CXX := x86_64-apple-darwin17-clang++-libc++
plugin-build-mac: export STRIP := x86_64-apple-darwin17-strip


plugin-build-win: export PATH := $(LOCAL_DIR)/x86_64-w64-mingw32/bin:$(PATH)
plugin-build-win: export CC := x86_64-w64-mingw32-gcc
plugin-build-win: export CXX := x86_64-w64-mingw32-g++
plugin-build-win: export STRIP := x86_64-w64-mingw32-strip


plugin-build-linux: export PATH:=$(LOCAL_DIR)/x86_64-ubuntu16.04-linux-gnu/bin:$(PATH)
plugin-build-linux: export CC := x86_64-ubuntu16.04-linux-gnu-gcc
plugin-build-linux: export CXX := x86_64-ubuntu16.04-linux-gnu-g++
plugin-build-linux: export STRIP := x86_64-ubuntu16.04-linux-gnu-strip


plugin-build-mac plugin-build-win plugin-build-linux: export RACK_DIR := $(RACK_DIR)
# Since the compiler we're using could have a newer version than the minimum supported libstdc++ version, link it statically.
# Rack v2 includes this flag in plugin.mk, so remove it after it releases.
plugin-build-mac plugin-build-win plugin-build-linux: export LDFLAGS := -static-libstdc++


plugin-build-mac plugin-build-win plugin-build-linux:
	cd $(PLUGIN_DIR) && $(MAKE) clean
	cd $(PLUGIN_DIR) && $(MAKE) cleandep
	cd $(PLUGIN_DIR) && $(MAKE) dep
	cd $(PLUGIN_DIR) && $(MAKE) dist
	mkdir -p $(PLUGIN_BUILD_DIR)
	cp $(PLUGIN_DIR)/dist/*.zip $(PLUGIN_BUILD_DIR)/
	cd $(PLUGIN_DIR) && $(MAKE) clean


plugin-build:
	$(MAKE) plugin-build-mac
	$(MAKE) plugin-build-win
	$(MAKE) plugin-build-linux


plugin-build-clean:
	rm -rf $(PLUGIN_BUILD_DIR)


# Docker helpers


dep-ubuntu:
	apt-get update
	apt-get install -y --no-install-recommends \
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
		clang \
		libz-dev \
		rsync \
		xxd \
		perl \
		coreutils


dep-arch-linux:
	# TODO Complete this list
	sudo pacman -S --needed \
		wget \
		help2man


docker-build:
	docker build --tag rack-plugin-toolchain:1 .


DOCKER_RUN := docker run --rm --interactive --tty \
	--volume=$(PLUGIN_DIR):/home/build/plugin-src \
	--volume=$(PWD)/$(PLUGIN_BUILD_DIR):/home/build/rack-plugin-toolchain/$(PLUGIN_BUILD_DIR) \
	--env PLUGIN_DIR=/home/build/plugin-src \
	rack-plugin-toolchain:1 \
	/bin/bash

docker-run:
	$(DOCKER_RUN)

docker-plugin-build-mac:
	mkdir -p $(PLUGIN_BUILD_DIR)
	$(DOCKER_RUN) -c "$(MAKE) plugin-build-mac $(MFLAGS)"

docker-plugin-build-win:
	mkdir -p $(PLUGIN_BUILD_DIR)
	$(DOCKER_RUN) -c "$(MAKE) plugin-build-win $(MFLAGS)"

docker-plugin-build-lin:
	mkdir -p $(PLUGIN_BUILD_DIR)
	$(DOCKER_RUN) -c "$(MAKE) plugin-build-lin $(MFLAGS)"

docker-plugin-build:
	mkdir -p $(PLUGIN_BUILD_DIR)
	$(DOCKER_RUN) -c "$(MAKE) plugin-build $(MFLAGS)"


.NOTPARALLEL:
.PHONY: all plugin-build
