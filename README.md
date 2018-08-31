# GameHub [![Build Status](https://travis-ci.com/tkashkin/GameHub.svg?branch=master)](https://travis-ci.com/tkashkin/GameHub)
Games manager/downloader/library written in Vala for elementary OS

## Game sources
GameHub supports multiple game sources and services

__Currently supported sources:__
* Steam
* GOG
* Humble Bundle

## Features
GameHub allows to view, download, install, run and uninstall games from supported sources.

It also allows to download bonus content for GOG games.

## Installation
Prebuilt releases can be found on [releases page](https://github.com/tkashkin/GameHub/releases).

### Arch Linux
~~There is an [AUR package](https://aur.archlinux.org/packages/gamehub/), maintained by [@twisty1](https://github.com/twisty1).~~ *[outdated]*

## Building

### Debian/Ubuntu-based distros

#### Build dependencies
* meson
* valac
* libgranite-dev
* libgtk-3-dev
* libglib2.0-dev
* libwebkit2gtk-4.0-dev
* libjson-glib-dev
* libgee-0.8-dev
* libsoup2.4-dev
* libsqlite3-dev

#### Building
```bash
git clone https://github.com/tkashkin/GameHub.git
cd GameHub
debuild
```

### Any distro, without package manager
```bash
git clone https://github.com/tkashkin/GameHub.git
cd GameHub
meson build --prefix=/usr -Ddistro=generic
cd build
ninja
sudo ninja install
```

### flatpak
flatpak manifest and build instructions are in the [flatpak branch](https://github.com/tkashkin/GameHub/tree/flatpak).

## Screenshots
<p align="center"><img src="data/screenshots/1.png?raw=true" width="49%" /> <img src="data/screenshots/1_dark.png?raw=true" width="49%" /><img src="data/screenshots/2.png?raw=true" width="49%" /> <img src="data/screenshots/2_dark.png?raw=true" width="49%" /><img src="data/screenshots/3.png?raw=true" width="49%" /> <img src="data/screenshots/3_dark.png?raw=true" width="49%" /><img src="data/screenshots/3_dialog.png?raw=true" width="49%" /> <img src="data/screenshots/3_dialog_dark.png?raw=true" width="49%" /><img src="data/screenshots/4.png?raw=true" width="49%" /> <img src="data/screenshots/4_dark.png?raw=true" width="49%" /></p>
