
Build Rack plugins for Mac, Windows, and Linux with a single command on any Linux distro.

## General prerequisites

**IMPORTANT:** Clone this repository in a path without spaces, or the Makefile will break.

Obtain `MacOSX10.13.sdk.tar.bz2` using the method at https://github.com/tpoechtrager/osxcross#packaging-the-sdk, and place it in the root of this repository.
This must be done on a computer with Macintosh 10.13.

Place `MacOSX10.13.sdk.tar.bz2` in root directory of this repository.

## Local toolchain build

Build toolchains for each platform.
```
make toolchain-all
```
Each toolchain will take around an hour to build, requiring network access and about 15 GB free disk space.
The final disk space after building is about 1.6 GB.

Execute plugin build.
```
make plugin-build -j8 PLUGIN_DIR=...
```

Build artifacts will be located in `plugin-build` directory.

## Docker-based toolchain build

Build Docker image with toolchains for each platform.
```
make docker-build
```

Execute plugin build in Docker container.
```
make docker-plugin-build -j8 PLUGIN_DIR=...
```

Build artifacts will be located in `plugin-build` directory.

## Acknowledgments

Thanks to @cschol for help with crosstool-ng, Ubuntu, Docker, and testing.
