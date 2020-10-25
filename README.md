# VCV Rack plugin build toolchains

Compile Rack plugins for Mac, Windows, and Linux with a single command on any Linux distro.

## Building

Clone this repository in a path without spaces, or the Makefile will break.

Obtain `MacOSX10.13.sdk.tar.xz` (or `.bz2`, either works) using the instructions at https://github.com/tpoechtrager/osxcross#packaging-the-sdk, and place it in the root of this repository.
You must have access to Mac 10.13 to generate this SDK package.

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

Build toolchains for all three platforms.
```bash
make toolchain-all
```
Each toolchain will take around an hour to build and will require network access, about 8 GB free RAM, and about 15 GB free disk space.
The final disk space after building is about 3.7 GB.

Build your plugin.
```bash
make -j$(nproc) plugin-build PLUGIN_DIR=...
```

Built plugin packages are placed in the `plugin-build/` directory.

### Docker toolchain build

*Works on any operating system with [Docker](https://www.docker.com/) installed.*

Build the Docker container with toolchains for all platforms.
```bash
make docker-build
```

Build your plugin.
```bash
make -j8 docker-plugin-build PLUGIN_DIR=...
```
You may replace 8 with your desired number of parallel jobs, such as your number of logical cores.

Built plugin packages are placed in the `plugin-build/` directory.

## Acknowledgments

Thanks to @cschol for help with crosstool-ng, Ubuntu, Docker, and testing.
