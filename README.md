# [GameHub](https://tkashkin.tk/projects/gamehub) [![Build status](https://ci.appveyor.com/api/projects/status/cgw5hc4kos4uvmy9/branch/master?svg=true)](https://ci.appveyor.com/project/tkashkin/gamehub/branch/master) [![Translation status](https://hosted.weblate.org/widgets/gamehub/-/translations/svg-badge.svg)](https://hosted.weblate.org/engage/gamehub/?utm_source=widget)
Unified library for all your games.

### [Features](https://tkashkin.tk/projects/gamehub/#/features)
GameHub allows to view, download, install, run and uninstall games from [supported sources](#game-sources).

### [Games](https://tkashkin.tk/projects/gamehub/#/games)
GameHub supports non-native games as well as native games for Linux.

It supports multiple [compatibility layers](https://github.com/tkashkin/GameHub/wiki/Compatibility-layers) for non-native games:
* Wine / Proton
* DOSBox
* RetroArch
* ScummVM

It also allows to add custom emulators.

GameHub supports [WineWrap](https://www.gog.com/forum/general/adamhms_linux_wine_wrappers_news_faq_discussion/post1) — a set of preconfigured wrappers for [supported games](https://www.gog.com/forum/general/adamhms_linux_wine_wrappers_news_faq_discussion/post3).

### [Game sources](https://tkashkin.tk/projects/gamehub/#/sources)
GameHub supports multiple game sources and services:
* Steam
* GOG
* Humble Bundle
* Humble Trove

Locally installed games can also be added to GameHub.

### [Collection](https://tkashkin.tk/projects/gamehub/#/collection)
GameHub makes storing and managing your DRM-free game collection easier.

Download installers, DLCs and bonus content and GameHub will save your downloads according to settings.

## Installation
Prebuilt releases can be found on [releases page](https://github.com/tkashkin/GameHub/releases).

### Ubuntu-based distros
Install debian package from [releases page](https://github.com/tkashkin/GameHub/releases) or use [PPA](https://launchpad.net/~tkashkin/+archive/ubuntu/gamehub):
```bash
# install if `add-apt-repository` is not available
sudo apt install --no-install-recommends software-properties-common

sudo add-apt-repository ppa:tkashkin/gamehub
sudo apt update
sudo apt install com.github.tkashkin.gamehub
```

### Arch Linux
[gamehub-git](https://aur.archlinux.org/packages/gamehub-git/) and [gamehub](https://aur.archlinux.org/packages/gamehub/) are available in AUR.

### Other packages
See [this issue](https://github.com/tkashkin/GameHub/issues/156) for more information.

## Building

### Debian/Ubuntu-based distros

#### Build dependencies
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

#### Building
```bash
git clone https://github.com/tkashkin/GameHub.git
cd GameHub
scripts/build.sh build_deb
```

### Any distro, without package manager
```bash
git clone https://github.com/tkashkin/GameHub.git
cd GameHub
meson build --prefix=/usr --buildtype=debug
cd build
ninja
sudo ninja install
```

### flatpak
```bash
git clone https://github.com/tkashkin/GameHub.git
cd GameHub
scripts/build.sh build_flatpak
```

## [Screenshots](https://tkashkin.tk/projects/gamehub/#/screenshots)
<p align="center"><img src="data/screenshots/light/welcome.png?raw=true" width="49%" /> <img src="data/screenshots/dark/grid.png?raw=true" width="49%" /><img src="data/screenshots/dark/list.png?raw=true" width="49%" /> <img src="data/screenshots/light/grid_controller.png?raw=true" width="49%" /><img src="data/screenshots/light/details.png?raw=true" width="49%" /> <img src="data/screenshots/dark/settings_collection.png?raw=true" width="49%" /><img src="data/screenshots/dark/overlays.png?raw=true" width="49%" /> <img src="data/screenshots/light/install.png?raw=true" width="49%" /><img src="data/screenshots/light/properties.png?raw=true" width="49%" /> <img src="data/screenshots/dark/install_compat.png?raw=true" width="49%" /></p>
