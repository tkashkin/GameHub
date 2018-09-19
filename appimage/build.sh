#!/bin/bash

set -e

_ROOT="`pwd`"
_SCRIPTROOT="$(dirname "$(readlink -f "$0")")"
_LINUXDEPLOYQT="linuxdeployqt-continuous-x86_64.AppImage"

_SOURCE="${APPVEYOR_BUILD_VERSION:-local}"
_VERSION="$_SOURCE-$(git rev-parse --short HEAD)"

BUILDROOT="$_ROOT/build/appimage"
BUILDDIR="$BUILDROOT/build"
APPDIR="$BUILDROOT/appdir"

ACTION=${1:-build_local}

deps()
{
	sudo add-apt-repository ppa:elementary-os/stable -y
	sudo add-apt-repository ppa:elementary-os/os-patches -y
	sudo add-apt-repository ppa:elementary-os/daily -y
	sudo apt update -qq
	sudo apt install -y meson valac checkinstall build-essential elementary-sdk libgranite-dev libgtk-3-dev libglib2.0-dev libwebkit2gtk-4.0-dev libjson-glib-dev libgee-0.8-dev libsoup2.4-dev libsqlite3-dev libxml2-dev
	sudo apt full-upgrade -y
}

build()
{
	cd "$_ROOT"
	mkdir -p "$BUILDROOT"
	meson "$BUILDDIR" --prefix=/usr --buildtype=debugoptimized -Ddistro=generic -Dappimage=true
	cd "$BUILDDIR"
	ninja
	DESTDIR="$APPDIR" ninja install
	cd "$_ROOT"
}

appimage()
{
	cd "$BUILDROOT"
	wget -c -nv "https://github.com/probonopd/linuxdeployqt/releases/download/continuous/$_LINUXDEPLOYQT"
	chmod a+x linuxdeployqt-continuous-x86_64.AppImage
	unset QTDIR; unset QT_PLUGIN_PATH; unset LD_LIBRARY_PATH
	export VERSION="$_VERSION"
	export LD_LIBRARY_PATH=$APPDIR/usr/lib:$LD_LIBRARY_PATH
	"./$_LINUXDEPLOYQT" "$APPDIR/usr/share/applications/com.github.tkashkin.gamehub.desktop" -appimage -verbose=2
	rm -f "$APPDIR/AppRun"
	cp -f "$_SCRIPTROOT/AppRun" "$APPDIR/AppRun"
	glib-compile-schemas "$APPDIR/usr/share/glib-2.0/schemas"
	"./$_LINUXDEPLOYQT" --appimage-extract
	PATH=./squashfs-root/usr/bin:$PATH ./squashfs-root/usr/bin/appimagetool --no-appstream "$APPDIR"
}

upload()
{
	cd "$BUILDROOT"
	wget -c https://github.com/probonopd/uploadtool/raw/master/upload.sh
	bash upload.sh GameHub*.AppImage*
}

if [[ "$ACTION" = "deps" ]]; then deps; fi
if [[ "$ACTION" = "build" || "$ACTION" = "build_local" ]]; then build; fi
if [[ "$ACTION" = "appimage" || "$ACTION" = "build_local" ]]; then appimage; fi
if [[ "$ACTION" = "upload" ]]; then upload; fi
