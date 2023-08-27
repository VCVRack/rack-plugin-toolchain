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

RACK_SDK_VERSION := 2.4.0
DOCKER_IMAGE_VERSION := 12


all: toolchain-all rack-sdk-all


# Toolchain build


toolchain-all: toolchain-lin toolchain-win toolchain-mac


crosstool-ng := $(LOCAL_DIR)/bin/ct-ng
$(crosstool-ng):
	git clone https://github.com/crosstool-ng/crosstool-ng.git
	cd crosstool-ng && git checkout e63c40854c977f488bee159a8f8ebf5fc06c8666
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
	# HACK Copy GL and related include dirs to toolchain sysroot
	chmod +w $(toolchain-lin)/x86_64-ubuntu16.04-linux-gnu/sysroot/usr/include
	cp -r /usr/include/GL $(toolchain-lin)/x86_64-ubuntu16.04-linux-gnu/sysroot/usr/include/
	cp -r /usr/include/KHR $(toolchain-lin)/x86_64-ubuntu16.04-linux-gnu/sysroot/usr/include/
	cp -r /usr/include/X11 $(toolchain-lin)/x86_64-ubuntu16.04-linux-gnu/sysroot/usr/include/
	chmod -w $(toolchain-lin)/x86_64-ubuntu16.04-linux-gnu/sysroot/usr/include


toolchain-win := $(LOCAL_DIR)/x86_64-w64-mingw32
toolchain-win: $(toolchain-win)
$(toolchain-win): $(crosstool-ng)
	ct-ng x86_64-w64-mingw32
	CT_PREFIX="$(LOCAL_DIR)" ct-ng build$(JOBS_CT_NG)
	rm -rf .build .config build.log /home/build/src


OSXCROSS_CLANG_VERSION := 15.0.7
OSXCROSS_BINUTILS_VERSION := 2.37

toolchain-mac := $(LOCAL_DIR)/osxcross
toolchain-mac: $(toolchain-mac)
$(toolchain-mac): export PATH := $(LOCAL_DIR)/osxcross/bin:$(PATH)
$(toolchain-mac):
	# Obtain osxcross sources.
	# FIXME Use official osxcross version when workaround from our fork are not required anymore.
	git clone "https://github.com/cschol/osxcross.git" osxcross
	cd osxcross && git checkout ae54314c24a959cd90ebb1f3aff3507677d36591

	# Build a custom clang compiler using the system's gcc compiler.
	# This enables us to have custom compiler environment needed for cross-compilation.
	cd osxcross && UNATTENDED=1 INSTALLPREFIX="$(LOCAL_DIR)" GITPROJECT=llvm CLANG_VERSION=$(OSXCROSS_CLANG_VERSION) OCDEBUG=1 ENABLE_CLANG_INSTALL=1 JOBS=$(JOBS) ./build_clang.sh

	## Build osxcross.
	cp MacOSX11.1.sdk.tar.* osxcross/tarballs/
	cd osxcross && PATH="$(LOCAL_DIR)/bin:$(PATH)" UNATTENDED=1 TARGET_DIR="$(LOCAL_DIR)/osxcross" JOBS=$(JOBS) ./build.sh

	## Build compiler-rt.
	cd osxcross && ENABLE_COMPILER_RT_INSTALL=1 JOBS=$(JOBS) ./build_compiler_rt.sh

	## Build MacOS binutils and build LLVM gold.
	cd osxcross && BINUTILS_VERSION=$(OSXCROSS_BINUTILS_VERSION) TARGET_DIR="$(LOCAL_DIR)/osxcross" JOBS=$(JOBS) ./build_binutils.sh
	cd osxcross/build/build_stage && cmake . -DLLVM_BINUTILS_INCDIR=$(PWD)/osxcross/build/binutils-$(OSXCROSS_BINUTILS_VERSION)/include && make install -j $(JOBS)

	# Fix library paths (for Arch Linux and Ubuntu arm64).
	export PLATFORM_ID=$$($(LOCAL_DIR)/bin/clang -dumpmachine) ; \
	echo "Platform ID: $$PLATFORM_ID" ; \
	if [ ! -z "$$PLATFORM_ID" ] && [ -e "$(LOCAL_DIR)/lib/$$PLATFORM_ID/"  ]; then \
		echo "Copying lib files..." ; \
		cp -Pv $(LOCAL_DIR)/lib/$$PLATFORM_ID/* $(LOCAL_DIR)/lib/ ; \
		echo "done" ; \
	fi

	## Download rcodesign binary to ad-hoc sign arm64 plugin builds in a cross-compilation environment.
	wget --continue "https://github.com/indygreg/apple-platform-rs/releases/download/apple-codesign%2F0.22.0/apple-codesign-0.22.0-x86_64-unknown-linux-musl.tar.gz"
	tar -xvf apple-codesign-0.22.0-x86_64-unknown-linux-musl.tar.gz
	rm apple-codesign-0.22.0-x86_64-unknown-linux-musl.tar.gz
	cp ./apple-codesign-0.22.0-x86_64-unknown-linux-musl/rcodesign $(LOCAL_DIR)/osxcross/bin/
	rm -r apple-codesign-0.22.0-x86_64-unknown-linux-musl

	rm -rf osxcross


toolchain-clean:
	rm -rf local osxcross .build build.log .config


# Rack SDK


rack-sdk-all: rack-sdk-mac-x64 rack-sdk-mac-arm64 rack-sdk-win-x64 rack-sdk-lin-x64


rack-sdk-mac-x64 := Rack-SDK-mac-x64
rack-sdk-mac-x64: $(rack-sdk-mac-x64)
$(rack-sdk-mac-x64):
	wget -c "https://vcvrack.com/downloads/Rack-SDK-$(RACK_SDK_VERSION)-mac-x64.zip"
	unzip Rack-SDK-$(RACK_SDK_VERSION)-mac-x64.zip
	mv Rack-SDK Rack-SDK-mac-x64
	rm Rack-SDK-$(RACK_SDK_VERSION)-mac-x64.zip
RACK_DIR_MAC_X64 := $(PWD)/$(rack-sdk-mac-x64)


rack-sdk-mac-arm64 := Rack-SDK-mac-arm64
rack-sdk-mac-arm64: $(rack-sdk-mac-arm64)
$(rack-sdk-mac-arm64):
	wget -c "https://vcvrack.com/downloads/Rack-SDK-$(RACK_SDK_VERSION)-mac-arm64.zip"
	unzip Rack-SDK-$(RACK_SDK_VERSION)-mac-arm64.zip
	mv Rack-SDK Rack-SDK-mac-arm64
	rm Rack-SDK-$(RACK_SDK_VERSION)-mac-arm64.zip
RACK_DIR_MAC_ARM64 := $(PWD)/$(rack-sdk-mac-arm64)


rack-sdk-win-x64 := Rack-SDK-win-x64
rack-sdk-win-x64: $(rack-sdk-win-x64)
$(rack-sdk-win-x64):
	wget -c "https://vcvrack.com/downloads/Rack-SDK-$(RACK_SDK_VERSION)-win-x64.zip"
	unzip Rack-SDK-$(RACK_SDK_VERSION)-win-x64.zip
	mv Rack-SDK Rack-SDK-win-x64
	rm Rack-SDK-$(RACK_SDK_VERSION)-win-x64.zip
RACK_DIR_WIN_X64 := $(PWD)/$(rack-sdk-win-x64)


rack-sdk-lin-x64 := Rack-SDK-lin-x64
rack-sdk-lin-x64: $(rack-sdk-lin-x64)
$(rack-sdk-lin-x64):
	wget -c "https://vcvrack.com/downloads/Rack-SDK-$(RACK_SDK_VERSION)-lin-x64.zip"
	unzip Rack-SDK-$(RACK_SDK_VERSION)-lin-x64.zip
	mv Rack-SDK Rack-SDK-lin-x64
	rm Rack-SDK-$(RACK_SDK_VERSION)-lin-x64.zip
RACK_DIR_LIN_X64 := $(PWD)/$(rack-sdk-lin-x64)


rack-sdk-clean:
	rm -rf $(rack-sdk-mac-x64) $(rack-sdk-mac-arm64) $(rack-sdk-win-x64) $(rack-sdk-lin-x64)


# Plugin build


PLUGIN_BUILD_DIR := plugin-build
PLUGIN_DIR ?=


plugin-build:
	$(MAKE) plugin-build-mac-x64
	$(MAKE) plugin-build-mac-arm64
	$(MAKE) plugin-build-win-x64
	$(MAKE) plugin-build-lin-x64


plugin-build-mac-x64: export PATH := $(LOCAL_DIR)/osxcross/bin:$(PATH)
plugin-build-mac-x64: export CC := x86_64-apple-darwin20.2-clang
plugin-build-mac-x64: export CXX := x86_64-apple-darwin20.2-clang++-libc++
plugin-build-mac-x64: export STRIP := x86_64-apple-darwin20.2-strip
plugin-build-mac-x64: export INSTALL_NAME_TOOL := x86_64-apple-darwin20.2-install_name_tool
plugin-build-mac-x64: export OTOOL := x86_64-apple-darwin20.2-otool
plugin-build-mac-x64: export CODESIGN := rcodesign sign


plugin-build-mac-arm64: export PATH := $(LOCAL_DIR)/osxcross/bin:$(PATH)
plugin-build-mac-arm64: export CC := arm64-apple-darwin20.2-clang
plugin-build-mac-arm64: export CXX := arm64-apple-darwin20.2-clang++-libc++
plugin-build-mac-arm64: export STRIP := arm64-apple-darwin20.2-strip
plugin-build-mac-arm64: export INSTALL_NAME_TOOL := arm64-apple-darwin20.2-install_name_tool
plugin-build-mac-arm64: export OTOOL := arm64-apple-darwin20.2-otool
plugin-build-mac-arm64: export CODESIGN := rcodesign sign


plugin-build-win-x64: export PATH := $(LOCAL_DIR)/x86_64-w64-mingw32/bin:$(PATH)
plugin-build-win-x64: export CC := x86_64-w64-mingw32-gcc
plugin-build-win-x64: export CXX := x86_64-w64-mingw32-g++
plugin-build-win-x64: export STRIP := x86_64-w64-mingw32-strip


plugin-build-lin-x64: export PATH:=$(LOCAL_DIR)/x86_64-ubuntu16.04-linux-gnu/bin:$(PATH)
plugin-build-lin-x64: export CC := x86_64-ubuntu16.04-linux-gnu-gcc
plugin-build-lin-x64: export CXX := x86_64-ubuntu16.04-linux-gnu-g++
plugin-build-lin-x64: export STRIP := x86_64-ubuntu16.04-linux-gnu-strip


plugin-build-mac-x64: export RACK_DIR := $(RACK_DIR_MAC_X64)
plugin-build-mac-arm64: export RACK_DIR := $(RACK_DIR_MAC_ARM64)
plugin-build-win-x64: export RACK_DIR := $(RACK_DIR_WIN_X64)
plugin-build-lin-x64: export RACK_DIR := $(RACK_DIR_LIN_X64)


plugin-build-mac-x64 plugin-build-mac-arm64 plugin-build-win-x64 plugin-build-lin-x64:
	cd $(PLUGIN_DIR) && $(MAKE) clean
	cd $(PLUGIN_DIR) && $(MAKE) cleandep
	cd $(PLUGIN_DIR) && $(MAKE) dep
	cd $(PLUGIN_DIR) && $(MAKE) dist
	mkdir -p $(PLUGIN_BUILD_DIR)
	cp $(PLUGIN_DIR)/dist/*.vcvplugin $(PLUGIN_BUILD_DIR)/
	cd $(PLUGIN_DIR) && $(MAKE) clean


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
		markdown \
		libarchive-tools


dep-arch-linux:
	pacman -Suyy --noconfirm && pacman -S --noconfirm --needed \
		gcc \
		git \
		cmake \
		patch \
		python3 \
		automake \
		help2man \
		texinfo \
		libtool \
		jq \
		rsync \
		autoconf \
		flex \
		bison \
		which \
		unzip \
		wget \
		glu \
		libx11 \
		mesa



docker-build: rack-sdk-all
	docker build --build-arg JOBS=$(JOBS) --no-cache --tag rack-plugin-toolchain:$(DOCKER_IMAGE_VERSION) . --progress=plain 2>&1 | tee docker-build.log


DOCKER_RUN := docker run --rm --interactive --tty \
	--volume=$(PLUGIN_DIR):/home/build/plugin-src \
	--volume=$(PWD)/$(PLUGIN_BUILD_DIR):/home/build/rack-plugin-toolchain/$(PLUGIN_BUILD_DIR) \
	--volume=$(PWD)/Rack-SDK-mac-x64:/home/build/rack-plugin-toolchain/Rack-SDK-mac-x64 \
	--volume=$(PWD)/Rack-SDK-mac-arm64:/home/build/rack-plugin-toolchain/Rack-SDK-mac-arm64 \
	--volume=$(PWD)/Rack-SDK-win-x64:/home/build/rack-plugin-toolchain/Rack-SDK-win-x64 \
	--volume=$(PWD)/Rack-SDK-lin-x64:/home/build/rack-plugin-toolchain/Rack-SDK-lin-x64 \
	--env PLUGIN_DIR=/home/build/plugin-src \
	rack-plugin-toolchain:$(DOCKER_IMAGE_VERSION) \
	/bin/bash

docker-run:
	$(DOCKER_RUN)

docker-plugin-build:
	mkdir -p $(PLUGIN_BUILD_DIR)
	$(DOCKER_RUN) -c "$(MAKE) plugin-build $(MFLAGS)"

docker-plugin-build-mac-x64:
	mkdir -p $(PLUGIN_BUILD_DIR)
	$(DOCKER_RUN) -c "$(MAKE) plugin-build-mac-x64 $(MFLAGS)"

docker-plugin-build-mac-arm64:
	mkdir -p $(PLUGIN_BUILD_DIR)
	$(DOCKER_RUN) -c "$(MAKE) plugin-build-mac-arm64 $(MFLAGS)"

docker-plugin-build-win-x64:
	mkdir -p $(PLUGIN_BUILD_DIR)
	$(DOCKER_RUN) -c "$(MAKE) plugin-build-win-x64 $(MFLAGS)"

docker-plugin-build-lin-x64:
	mkdir -p $(PLUGIN_BUILD_DIR)
	$(DOCKER_RUN) -c "$(MAKE) plugin-build-lin-x64 $(MFLAGS)"


.NOTPARALLEL:
.PHONY: all plugin-build
