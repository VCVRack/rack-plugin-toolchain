# VCV Rack plugin build toolchains

Compile Rack plugins for Mac, Windows, and Linux with a single command on any Linux distro.

## Building

Clone this repository in a path without spaces, or the Makefile will break.

Obtain `MacOSX10.13.sdk.tar.bz2` using the method at https://github.com/tpoechtrager/osxcross#packaging-the-sdk, and place it in the root of this repository.
This must be done on a computer with Mac 10.13.

There are two ways to build the toolchains:
- Locally on Linux: Uses your system's compilers to build the toolchains.
- In a Docker container: Downloads an Ubuntu image and installs all dependencies in the container.

### Local toolchain build

*Requires a Linux host.*

Install toolchain build dependencies.
On Ubuntu,
```bash
sudo make dep-ubuntu
```
Or on Arch Linux,
```bash
sudo make dep-arch-linux
```

Build toolchains for each platform.
```bash
make toolchain-lin
make toolchain-win
make toolchain-mac
```
Each toolchain will take around an hour to build, requiring network access and about 15 GB free disk space.
The final disk space after building is about 3.7 GB.

Build your plugin.
```bash
make plugin-build PLUGIN_DIR=...
```
To speed up builds, use `-jN` to launch N parallel jobs, such as your number of logical cores.

Built plugin packages are placed in the `plugin-build/` directory.

### Docker toolchain build

*Works on any operating system with [Docker](https://www.docker.com/) installed.*

Build the Docker container with toolchains for all platforms.
```bash
make docker-build
```

Build your plugin.
```bash
make docker-plugin-build PLUGIN_DIR=...
```

Built plugin packages are placed in the `plugin-build/` directory.

## Acknowledgments

Thanks to @cschol for help with crosstool-ng, Ubuntu, Docker, and testing.
