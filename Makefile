.NOTPARALLEL:
.PHONY: all plugin-build


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


toolchain-linux := $(LOCAL_DIR)/x86_64-ubuntu16.04-linux-gnu
toolchain-linux: $(toolchain-linux)
$(toolchain-linux): $(crosstool-ng)
	ct-ng x86_64-ubuntu16.04-linux-gnu
	CT_PREFIX="$(LOCAL_DIR)" ct-ng build
	rm -rf .build .config
	# HACK Copy GL include dir to toolchain sysroot
	chmod +w $(toolchain-linux)/x86_64-ubuntu16.04-linux-gnu/sysroot/usr/include
	cp -r /usr/include/GL $(toolchain-linux)/x86_64-ubuntu16.04-linux-gnu/sysroot/usr/include/
	chmod -w $(toolchain-linux)/x86_64-ubuntu16.04-linux-gnu/sysroot/usr/include


toolchain-windows := $(LOCAL_DIR)/x86_64-w64-mingw32
toolchain-windows: $(toolchain-windows)
$(toolchain-windows): $(crosstool-ng)
	ct-ng x86_64-w64-mingw32
	CT_PREFIX="$(LOCAL_DIR)" ct-ng build
	rm -rf .build .config


toolchain-mac := osxcross
toolchain-mac: $(toolchain-mac)
$(toolchain-mac):
	git clone "https://github.com/tpoechtrager/osxcross.git" $@
	cd $@ && git checkout a791ad4fca685ea9fceb520b77db586881cd3f3d

	# Build clang
	#cd $@ && UNATTENDED=1 DISABLE_BOOTSTRAP=1 INSTALLPREFIX="$(LOCAL_DIR)" OCDEBUG=1 ./build_clang.sh
	#cd $@/build/llvm-10.0.1.src/build && make install

	# Build osxcross
	cp MacOSX10.13.sdk.tar.* $@/tarballs/
	cd $@ && UNATTENDED=1 TARGET_DIR="$(LOCAL_DIR)/osxcross" ./build.sh
	rm -rf osxcross


rack-sdk := Rack-SDK
rack-sdk: $(rack-sdk)
$(rack-sdk):
	wget -c "https://vcvrack.com/downloads/Rack-SDK-1.1.6.zip"
	unzip Rack-SDK-1.1.6.zip
	rm Rack-SDK-1.1.6.zip
RACK_DIR := $(PWD)/$(rack-sdk)


toolchain-all: toolchain-linux toolchain-windows toolchain-mac rack-sdk


toolchain-clean:
	rm -rf local osxcross $(rack-sdk)


# Plugin build


PLUGIN_BUILD_DIR := plugin-build


plugin-build-mac: export PATH := $(LOCAL_DIR)/osxcross/bin:$(PATH)
plugin-build-mac: export CC := x86_64-apple-darwin17-clang
plugin-build-mac: export CXX := x86_64-apple-darwin17-clang++-libc++
plugin-build-mac: export STRIP := x86_64-apple-darwin17-strip


plugin-build-windows: export PATH := $(LOCAL_DIR)/x86_64-w64-mingw32/bin:$(PATH)
plugin-build-windows: export CC := x86_64-w64-mingw32-gcc
plugin-build-windows: export CXX := x86_64-w64-mingw32-g++
plugin-build-windows: export STRIP := x86_64-w64-mingw32-strip


plugin-build-linux: export PATH:=$(LOCAL_DIR)/x86_64-ubuntu16.04-linux-gnu/bin:$(PATH)
plugin-build-linux: export CC := x86_64-ubuntu16.04-linux-gnu-gcc
plugin-build-linux: export CXX := x86_64-ubuntu16.04-linux-gnu-g++
plugin-build-linux: export STRIP := x86_64-ubuntu16.04-linux-gnu-strip


plugin-build-mac plugin-build-windows plugin-build-linux: export RACK_DIR := $(RACK_DIR)
# Since the compiler we're using could have a newer version than the minimum supported libstdc++ version, link it statically.
# Rack v2 includes this flag in plugin.mk, so remove it after it releases.
plugin-build-mac plugin-build-windows plugin-build-linux: export LDFLAGS := -static-libstdc++


plugin-build-mac plugin-build-windows plugin-build-linux:
	cd $(PLUGIN_DIR) && $(MAKE) clean
	cd $(PLUGIN_DIR) && $(MAKE) cleandep
	cd $(PLUGIN_DIR) && $(MAKE) dep
	cd $(PLUGIN_DIR) && $(MAKE) dist
	mkdir -p $(PLUGIN_BUILD_DIR)
	cp $(PLUGIN_DIR)/dist/*.zip $(PLUGIN_BUILD_DIR)/
	cd $(PLUGIN_DIR) && $(MAKE) clean


plugin-build:
	$(MAKE) plugin-build-mac
	$(MAKE) plugin-build-windows
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
		rsync
	rm -rf /var/lib/apt/lists/*


dep-arch-linux:
	# TODO Complete this list
	sudo pacman -S --needed \
		wget \
		help2man


docker-build:
	docker build -t rack-plugin-toolchain:1 .


docker-run:
	mkdir -p $(PLUGIN_BUILD_DIR)
	docker run --rm -it \
		-v $(PLUGIN_DIR):/home/build/plugin-src \
		-v $(PWD)/$(PLUGIN_BUILD_DIR):/home/build/$(PLUGIN_BUILD_DIR) \
		-e PLUGIN_DIR=plugin-src \
		rack-plugin-toolchain:1 \
		/bin/bash \
		-c "$(MAKE) plugin-build $(MFLAGS)"

