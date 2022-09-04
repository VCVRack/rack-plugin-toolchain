# Installation path for executables
LOCAL_DIR := $(PWD)/local
# Local programs should have higher path priority than system-installed programs
export PATH := $(LOCAL_DIR)/bin:$(PATH)

# Allow specifying the number of jobs for toolchain build for systems that need it.
# Due to different build systems used in the toolchain build, just `make -j` won't work here.
# Note: Plugin build uses `$(MAKE)` to inherit `-j` argument from command line.
ifdef JOBS
export JOBS := $(JOBS)
# Define number of jobs for crosstool-ng (uses different argument format)
export JOBS_CT_NG := .$(JOBS)
else
# If `JOBS` is not specified, default to max number of jobs.
export JOBS :=
export JOBS_CT_NG :=
endif

RACK_SDK_VERSION := 2.1.2
DOCKER_IMAGE_VERSION := 4

all: toolchain-all

# Toolchain build


crosstool-ng := $(LOCAL_DIR)/bin/ct-ng
$(crosstool-ng):
	git clone https://github.com/crosstool-ng/crosstool-ng.git
	cd crosstool-ng && git checkout crosstool-ng-1.25.0
	cd crosstool-ng && ./bootstrap
	cd crosstool-ng && ./configure --prefix="$(LOCAL_DIR)"
	cd crosstool-ng && make -j $(JOBS)
	cd crosstool-ng && make install -j $(JOBS)
	rm -rf crosstool-ng


toolchain-lin := $(LOCAL_DIR)/x86_64-ubuntu16.04-linux-gnu
toolchain-lin: $(toolchain-lin)
$(toolchain-lin): $(crosstool-ng)
	ct-ng x86_64-ubuntu16.04-linux-gnu
	CT_PREFIX="$(LOCAL_DIR)" ct-ng build$(JOBS_CT_NG)
	rm -rf .build .config build.log
	# HACK Copy GL include dir to toolchain sysroot
	chmod +w $(toolchain-lin)/x86_64-ubuntu16.04-linux-gnu/sysroot/usr/include
	cp -r /usr/include/GL $(toolchain-lin)/x86_64-ubuntu16.04-linux-gnu/sysroot/usr/include/
	chmod -w $(toolchain-lin)/x86_64-ubuntu16.04-linux-gnu/sysroot/usr/include


toolchain-win := $(LOCAL_DIR)/x86_64-w64-mingw32
toolchain-win: $(toolchain-win)
$(toolchain-win): $(crosstool-ng)
	ct-ng x86_64-w64-mingw32
	CT_PREFIX="$(LOCAL_DIR)" ct-ng build$(JOBS_CT_NG)
	rm -rf .build .config build.log /home/build/src


toolchain-mac := $(LOCAL_DIR)/osxcross
toolchain-mac: $(toolchain-mac)
MAC_CLANG_VERSION := 12.0.1
MAC_BINUTILS_VERSION := 2.37
# Binaries from ./build.sh must be available in order to run ./build_binutils.sh
$(toolchain-mac): export PATH := $(LOCAL_DIR)/osxcross/bin:$(PATH)
$(toolchain-mac):
	# Download osxcross
	git clone "https://github.com/tpoechtrager/osxcross.git" osxcross
	cd osxcross && git checkout 0f87f567dfaf98460244471ad6c0f4311d62079c

	# Build clang
	cd osxcross && UNATTENDED=1 DISABLE_BOOTSTRAP=1 INSTALLPREFIX="$(LOCAL_DIR)" CLANG_VERSION=$(MAC_CLANG_VERSION) OCDEBUG=1 JOBS=$(JOBS) ./build_clang.sh
	cd osxcross/build/llvm-$(MAC_CLANG_VERSION).src/build && make install -j $(JOBS)

	# Build osxcross
	cp MacOSX11.1.sdk.tar.* osxcross/tarballs/
	cd osxcross && PATH="$(LOCAL_DIR)/bin:$(PATH)" UNATTENDED=1 TARGET_DIR="$(LOCAL_DIR)/osxcross" JOBS=$(JOBS) ./build.sh

	# Build Mac version of binutils and build LLVM gold
	cd osxcross && BINUTILS_VERSION=$(MAC_BINUTILS_VERSION) TARGET_DIR="$(LOCAL_DIR)/osxcross" JOBS=$(JOBS) ./build_binutils.sh
	cd osxcross/build/llvm-$(MAC_CLANG_VERSION).src/build && cmake .. -DLLVM_BINUTILS_INCDIR=$(PWD)/osxcross/build/binutils-$(MAC_BINUTILS_VERSION)/include && make install -j $(JOBS)

	rm -rf osxcross


rack-sdk-mac := Rack-SDK-mac
rack-sdk-mac: $(rack-sdk-mac)
$(rack-sdk-mac):
	wget -c "https://vcvrack.com/downloads/Rack-SDK-$(RACK_SDK_VERSION)-mac.zip"
	unzip Rack-SDK-$(RACK_SDK_VERSION)-mac.zip
	mv Rack-SDK Rack-SDK-mac
	rm Rack-SDK-$(RACK_SDK_VERSION)-mac.zip
RACK_DIR_MAC := $(PWD)/$(rack-sdk-mac)

rack-sdk-win := Rack-SDK-win
rack-sdk-win: $(rack-sdk-win)
$(rack-sdk-win):
	wget -c "https://vcvrack.com/downloads/Rack-SDK-$(RACK_SDK_VERSION)-win.zip"
	unzip Rack-SDK-$(RACK_SDK_VERSION)-win.zip
	mv Rack-SDK Rack-SDK-win
	rm Rack-SDK-$(RACK_SDK_VERSION)-win.zip
RACK_DIR_WIN := $(PWD)/$(rack-sdk-win)

rack-sdk-lin := Rack-SDK-lin
rack-sdk-lin: $(rack-sdk-lin)
$(rack-sdk-lin):
	wget -c "https://vcvrack.com/downloads/Rack-SDK-$(RACK_SDK_VERSION)-lin.zip"
	unzip Rack-SDK-$(RACK_SDK_VERSION)-lin.zip
	mv Rack-SDK Rack-SDK-lin
	rm Rack-SDK-$(RACK_SDK_VERSION)-lin.zip
RACK_DIR_LIN := $(PWD)/$(rack-sdk-lin)

rack-sdk-clean:
	rm -rf $(PWD)/Rack-SDK-mac $(PWD)/Rack-SDK-win $(PWD)/Rack-SDK-lin

rack-sdk-all: rack-sdk-mac rack-sdk-win rack-sdk-lin

toolchain-all: toolchain-lin toolchain-win toolchain-mac rack-sdk-all


toolchain-clean:
	rm -rf local osxcross $(rack-sdk-mac) $(rack-sdk-win) $(rack-sdk-lin)


# Plugin build


PLUGIN_BUILD_DIR := plugin-build
PLUGIN_DIR ?=


plugin-build-mac: export PATH := $(LOCAL_DIR)/osxcross/bin:$(PATH)
plugin-build-mac: export CC := x86_64-apple-darwin20.2-clang
plugin-build-mac: export CXX := x86_64-apple-darwin20.2-clang++-libc++
plugin-build-mac: export STRIP := x86_64-apple-darwin20.2-strip
plugin-build-mac: export INSTALL_NAME_TOOL := x86_64-apple-darwin20.2-install_name_tool
plugin-build-mac: export OTOOL := x86_64-apple-darwin20.2-otool


plugin-build-win: export PATH := $(LOCAL_DIR)/x86_64-w64-mingw32/bin:$(PATH)
plugin-build-win: export CC := x86_64-w64-mingw32-gcc
plugin-build-win: export CXX := x86_64-w64-mingw32-g++
plugin-build-win: export STRIP := x86_64-w64-mingw32-strip


plugin-build-linux: export PATH:=$(LOCAL_DIR)/x86_64-ubuntu16.04-linux-gnu/bin:$(PATH)
plugin-build-linux: export CC := x86_64-ubuntu16.04-linux-gnu-gcc
plugin-build-linux: export CXX := x86_64-ubuntu16.04-linux-gnu-g++
plugin-build-linux: export STRIP := x86_64-ubuntu16.04-linux-gnu-strip


plugin-build-mac: export RACK_DIR := $(RACK_DIR_MAC)
plugin-build-win: export RACK_DIR := $(RACK_DIR_WIN)
plugin-build-linux: export RACK_DIR := $(RACK_DIR_LIN)


plugin-build-mac plugin-build-win plugin-build-linux:
	cd $(PLUGIN_DIR) && $(MAKE) clean
	cd $(PLUGIN_DIR) && $(MAKE) cleandep
	cd $(PLUGIN_DIR) && $(MAKE) dep
	cd $(PLUGIN_DIR) && $(MAKE) dist
	mkdir -p $(PLUGIN_BUILD_DIR)
	cp $(PLUGIN_DIR)/dist/*.vcvplugin $(PLUGIN_BUILD_DIR)/
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
		libz-dev \
		rsync \
		xxd \
		perl \
		coreutils \
		zstd \
		markdown


dep-arch-linux:
	# TODO Complete this list
	sudo pacman -S --needed \
		wget \
		help2man


docker-build: rack-sdk-all
	docker build --build-arg JOBS=$(JOBS) --tag rack-plugin-toolchain:$(DOCKER_IMAGE_VERSION) .


DOCKER_RUN := docker run --rm --interactive --tty \
	--volume=$(PLUGIN_DIR):/home/build/plugin-src \
	--volume=$(PWD)/$(PLUGIN_BUILD_DIR):/home/build/rack-plugin-toolchain/$(PLUGIN_BUILD_DIR) \
	--volume=$(PWD)/Rack-SDK-mac:/home/build/rack-plugin-toolchain/Rack-SDK-mac \
	--volume=$(PWD)/Rack-SDK-win:/home/build/rack-plugin-toolchain/Rack-SDK-win \
	--volume=$(PWD)/Rack-SDK-lin:/home/build/rack-plugin-toolchain/Rack-SDK-lin \
	--env PLUGIN_DIR=/home/build/plugin-src \
	rack-plugin-toolchain:$(DOCKER_IMAGE_VERSION) \
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
	$(DOCKER_RUN) -c "$(MAKE) plugin-build-linux $(MFLAGS)"

docker-plugin-build:
	mkdir -p $(PLUGIN_BUILD_DIR)
	$(DOCKER_RUN) -c "$(MAKE) plugin-build $(MFLAGS)"


.NOTPARALLEL:
.PHONY: all plugin-build
