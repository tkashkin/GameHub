# Installation

## Table of contents

* [Distribution-specific packages](#distribution-specific-packages)
	- [Arch-based distributions](#arch-based-distributions)
	- [Debian](#debian)
	- [Fedora](#fedora)
	- [OpenMandriva](#openmandriva)
	- [openSUSE](#opensuse)
	- [Pop!\_OS](#pop_os)
	- [Ubuntu-based distributions](#ubuntu-based-distributions)
* [Portable packages](#portable-packages)
	- [AppImage](#appimage)
	- [Flatpak](#flatpak)
* [Prebuilt releases](#prebuilt-releases)
* [Source](#source)
	- [Dependencies](#dependencies)
	- [Debian and Ubuntu-based distributions](#debian-and-ubuntu-based-distributions)
	- [Other distributions](#other-distributions)

## Distribution-specific packages

### Arch-based distributions
[`gamehub-git`](https://aur.archlinux.org/packages/gamehub-git) and [`gamehub`](https://aur.archlinux.org/packages/gamehub) are available in AUR.

### Debian
Install Debian package from the [releases page](https://github.com/tkashkin/GameHub/releases) or import the [PPA](https://launchpad.net/~tkashkin/+archive/ubuntu/gamehub):
```bash
sudo apt install dirmngr
sudo sh -c "echo 'deb http://ppa.launchpad.net/tkashkin/gamehub/ubuntu focal main' > /etc/apt/sources.list.d/gamehub-ppa.list
sudo apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 5B63B42CE14BA47CC1B69E7C32B600D632AF380D
sudo apt update
sudo apt install com.github.tkashkin.gamehub
```

### Fedora
Package is available in Fedora repository:
```bash
sudo dnf install gamehub
```

### OpenMandriva
[`gamehub`](https://abf.openmandriva.org/openmandriva/gamehub/build_lists) is available in the OpenMandriva repository.

### openSUSE
```bash
sudo zypper install gamehub
```

### Pop!\_OS
Package is available in Pop!\_OS repository:
```bash
sudo apt install com.github.tkashkin.gamehub
```

### Ubuntu-based distributions
Install Debian package from the [releases page](https://github.com/tkashkin/GameHub/releases) or import the [PPA](https://launchpad.net/~tkashkin/+archive/ubuntu/gamehub):
```bash
# install if `add-apt-repository` is not available
sudo apt install --no-install-recommends software-properties-common

sudo add-apt-repository ppa:tkashkin/gamehub
sudo apt update
sudo apt install com.github.tkashkin.gamehub
```

## Portable packages

### AppImage
AppImages can be found in the [releases page](https://github.com/tkashkin/GameHub/releases).

**WARNING: AppImages are unstable! You might experience issues.**

### Flatpak
Flatpak releases can be found in the [releases page](https://github.com/tkashkin/GameHub/releases).

**WARNING: Flatpak releases are unstable! You might experience issues.**

Install the package by executing this command:
```bash
flatpak install GameHub-*.flatpak
```

If you want to build it from source instead of installing the binary, execute the commands:
```bash
git clone https://github.com/tkashkin/GameHub.git
cd GameHub
scripts/build.sh build_flatpak
```

## Prebuilt releases
Prebuilt releases can be found in the [releases page](https://github.com/tkashkin/GameHub/releases).

## Source

### Dependencies
* `meson`
* `valac`
* `libgtk-3-dev`
* `libglib2.0-dev`
* `libwebkit2gtk-4.0-dev`
* `libjson-glib-dev`
* `libgee-0.8-dev`
* `libsoup2.4-dev`
* `libsqlite3-dev`
* `libxml2-dev`
* `libpolkit-gobject-1-dev`
* `libunity-dev` (optional, required for launcher icon quicklist, progress indicator and counter; pass `-Duse_libunity=true` to `meson` to use)
* `libmanette-0.2-dev`, `libx11-dev`, `libxtst-dev` (optional, required for gamepad support)

### Debian and Ubuntu-based distributions
* Build a .deb package (this will build `GameHub-*.deb` package in the parent directory):
```bash
git clone https://github.com/tkashkin/GameHub.git
cd GameHub
scripts/build.sh build_deb
```
* Install built package:
```bash
sudo apt install ../GameHub-*.deb
```

### Other distributions
* Build:
```bash
git clone https://github.com/tkashkin/GameHub.git
cd GameHub
meson build --prefix=/usr --buildtype=debug
cd build
ninja
```
* Install:
```bash
sudo ninja install
```
Do not remove build directory if you want to uninstall GameHub later, build directory is used in uninstallation process.
