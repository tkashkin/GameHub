# flatpak
This directory contains flatpak manifest

#### Runtime dependencies

* `org.gnome.Platform//3.28`
* `org.freedesktop.Platform//1.6`
* `io.elementary.Loki.BaseApp//stable`

#### Build dependencies

* `org.gnome.Sdk//3.28`

## Building

#### Add flathub repo

```bash
flatpak remote-add [--user] --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
```

#### Install dependencies and build

```bash
scripts/build.sh build_flatpak
```

#### Run

```bash
flatpak run [-v] com.github.tkashkin.gamehub [--debug]
```
