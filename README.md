# VCV Rack plugin build toolchains

**Cross-compile** Rack plugins for Mac, Windows, and Linux with a single command on any Linux distro.

## Building

Clone this repository in a **path without spaces**, or the Makefile will break.

Obtain `MacOSX11.1.sdk.tar.xz` using the instructions at https://github.com/tpoechtrager/osxcross#packaging-the-sdk, and place it in the root of this repository.
You must have access to a Mac with **Xcode 12.4** to generate this SDK package. You **must** use this specific SDK version to build the toolchains.

There are two ways to build the toolchains:
- Locally on Linux: Uses your system's compilers to build the toolchains.
- In a Docker container: This method uses an Ubuntu 20.04 base image and installs all dependencies necessary to build the toolchains.

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

**IMPORTANT:** Do **not** invoke the Docker-based toolchain with `sudo`! There is no need to do so and it will not work correctly.

Instead, follow the instructions to let non-root users manage Docker containers: https://docs.docker.com/engine/install/linux-postinstall/

Build the Docker container with toolchains for all platforms.
```bash
make docker-build
```

*Optional*: Pass number of jobs to use to for the tool chain build with the `JOBS` environment variable.
```bash
JOBS=8 make docker-build
```
(`-j8` will not work due to the different build systems used in the toolchain build process.)

Build your plugin.
```bash
make -j8 docker-plugin-build PLUGIN_DIR=...
```
You may replace 8 with your desired number of parallel jobs, such as your number of logical cores.

Built plugin packages are placed in the `plugin-build/` directory.

## Acknowledgments

Thanks to @cschol for help with crosstool-ng, Ubuntu, Docker, and testing.
