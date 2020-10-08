
Build Rack plugins for Mac, Windows, and Linux with a single command on any Linux distro.
Coming soon: Use Docker to build on Mac, Windows, or Linux.


## Building

Clone this repository in a path without spaces, or the Makefile will break.

Obtain `MacOSX10.13.sdk.tar.bz2` using the method at https://github.com/tpoechtrager/osxcross#packaging-the-sdk, and place it in the root of this repository.
This must be done on a computer with Mac 10.13.

Build toolchains for each platform.
```
make toolchain-linux
make toolchain-windows
make toolchain-mac
```
Each toolchain will take around an hour to build, requiring network access and about 15 GB free disk space total.

Download the latest Rack SDK.
```
make rack-sdk
```

## Building plugins

Build plugin package for all platforms.
```
make plugin-build PLUGIN_DIR=...
```

This places packages in `plugin-build/`.
