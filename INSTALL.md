# Installation

## Table of contents

- [Arch-based distributions](#arch-based-distributions)
- [Debian](#debian)
- [Fedora](#fedora)
- [OpenMandriva](#openmandriva)
- [openSUSE](#opensuse)
- [Ubuntu-based distributions](#ubuntu-based-distributions)
- [AppImage](#appimage)
- [Flatpak](#flatpak)
- [Prebuilt releases](#prebuilt-releases)
- [Source](#source)
	- [Building](#building)
	- [Installing](#installing)

## Arch-based distributions
[gamehub-git](https://aur.archlinux.org/packages/gamehub-git/) and [gamehub](https://aur.archlinux.org/packages/gamehub/) are available in AUR.

## Debian
Unfortunately, there is no package available in the Debian repository, so it will be required to run the [`/scripts/build.sh build_deb`](../scripts/build.sh#L171-L210) script. The script will install the dependencies and GameHub.

**Build dependencies**
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

```bash
git clone https://github.com/tkashkin/GameHub.git
cd GameHub
scripts/build.sh build_deb
```

## Fedora
```bash
sudo dnf install gamehub
```

## OpenMandriva
[gamehub](https://abf.openmandriva.org/openmandriva/gamehub/build_lists) is available in the OpenMandriva repository.

## openSUSE
```bash
sudo zypper install gamehub
```

## Ubuntu-based distributions
Install Debian package from the [releases page](https://github.com/tkashkin/GameHub/releases) or import the [PPA](https://launchpad.net/~tkashkin/+archive/ubuntu/gamehub):
```bash
# install if `add-apt-repository` is not available
sudo apt install --no-install-recommends software-properties-common

sudo add-apt-repository ppa:tkashkin/gamehub
sudo apt update
sudo apt install com.github.tkashkin.gamehub
```

## AppImage
AppImages can be found in the [releases page](https://github.com/tkashkin/GameHub/releases).

## Flatpak
Unfortunately, there is no package available in the Flathub repository, so it will be required to run the [`/scripts/build.sh build_flatpak`](../scripts/build.sh#L311-L334) script:

```bash
git clone https://github.com/tkashkin/GameHub.git
cd GameHub
scripts/build.sh build_flatpak
```

## Prebuilt releases
Prebuilt releases can be found in the [releases page](https://github.com/tkashkin/GameHub/releases).

## Source
### Building
```bash
git clone https://github.com/tkashkin/GameHub.git
cd GameHub
meson build --prefix=/usr --buildtype=debug
cd build
ninja
```
### Installing
```
sudo ninja install
```
