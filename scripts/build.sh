#!/bin/bash

_GH_VERSION="0.11.3"

_ROOT="`pwd`"
_SCRIPTROOT="$(dirname "$(readlink -f "$0")")"
_LINUXDEPLOYQT="linuxdeployqt-continuous-x86_64.AppImage"

_SOURCE="${APPVEYOR_BUILD_VERSION:-$_GH_VERSION-local}"
_VERSION="$_SOURCE-$(git rev-parse --short HEAD)"
_DEB_VERSION="${APPVEYOR_BUILD_VERSION:-$_VERSION}"
_DEB_TARGET_DISTRO="bionic"
_BUILD_IMAGE="local"

if [[ "$APPVEYOR_BUILD_WORKER_IMAGE" = "Ubuntu1604" ]]; then
	_VERSION="xenial-$_VERSION"
	_DEB_VERSION="$_DEB_VERSION~ubuntu16.04"
	_DEB_TARGET_DISTRO="xenial"
	_BUILD_IMAGE="xenial"
elif [[ "$APPVEYOR_BUILD_WORKER_IMAGE" = "Ubuntu1804" ]]; then
	_VERSION="bionic-$_VERSION"
	_DEB_VERSION="$_DEB_VERSION~ubuntu18.04"
	_DEB_TARGET_DISTRO="bionic"
	_BUILD_IMAGE="bionic"
fi

BUILDROOT="$_ROOT/build/appimage"
BUILDDIR="$BUILDROOT/build"
APPDIR="$BUILDROOT/appdir"

ACTION=${1:-build_local}
CHECKRT=${2:---checkrt}

_usr_patch()
{
	set +e
	file="$1"
	echo "[scripts/build.sh] Patching $file"
	sed -i -e 's#/usr#././#g' "$file"
}

_mv_deps()
{
	set +e
	lib="$1"
	src="$2"
	dest="$3"
	recursive=${4:-true}
	echo "[scripts/build.sh] Moving $lib"
	[ -e "$src/$lib" ] && mv -f "$src/$lib" "$dest"
	[ -e "$dest/$lib" ] && ldd "$dest/$lib" | awk '{print $1}' | while read dep; do
		[ -e "$src/$dep" ] && echo "[scripts/build.sh] $dep <- $lib"
		if [ "$recursive" = "true" ]; then
			[ -e "$src/$dep" ] && _mv_deps "$dep" "$src" "$dest" "$recursive"
		else
			[ -e "$src/$dep" ] && mv -f "$src/$dep" "$dest"
		fi
	done
}

import_keys()
{
	set +e
	cd "$_ROOT"
	if [[ -n "$keys_enc_secret" ]]; then
		echo "[scripts/build.sh] Importing keys"
		sudo apt install -y gnupg1
		curl -sflL "https://raw.githubusercontent.com/appveyor/secure-file/master/install.sh" | bash -e -
		./appveyor-tools/secure-file -decrypt "$_SCRIPTROOT/launchpad/key_pub.gpg.enc" -secret $keys_enc_secret
		./appveyor-tools/secure-file -decrypt "$_SCRIPTROOT/launchpad/key_sec.gpg.enc" -secret $keys_enc_secret
		./appveyor-tools/secure-file -decrypt "$_SCRIPTROOT/launchpad/passphrase.enc" -secret $keys_enc_secret
		gpg1 --no-use-agent --import "$_SCRIPTROOT/launchpad/key_pub.gpg"
		gpg1 --no-use-agent --allow-secret-key-import --import "$_SCRIPTROOT/launchpad/key_sec.gpg"
		sudo apt-key add "$_SCRIPTROOT/launchpad/key_pub.gpg"
		rm "$_SCRIPTROOT/launchpad/key_pub.gpg" "$_SCRIPTROOT/launchpad/key_sec.gpg"
	fi
}

deps()
{
	set +e
	echo "[scripts/build.sh] Installing dependencies"
	sudo add-apt-repository ppa:elementary-os/stable -y
	sudo add-apt-repository ppa:elementary-os/os-patches -y
	sudo add-apt-repository ppa:elementary-os/daily -y
	sudo add-apt-repository ppa:vala-team/next -y
	sudo apt update -qq
	if [[ "$_BUILD_IMAGE" = "bionic" ]]; then
		sudo apt install -y libwebkit2gtk-4.0-\*=2.20.1-1 libjavascriptcoregtk-4.0-\*=2.20.1-1 gir1.2-webkit2-4.0=2.20.1-1 gir1.2-javascriptcoregtk-4.0=2.20.1-1
	else
		sudo apt install -y libwebkit2gtk-4.0-dev
	fi
	sudo apt install -y meson valac checkinstall build-essential dput elementary-sdk libgranite-dev libgtk-3-dev libglib2.0-dev libjson-glib-dev libgee-0.8-dev libsoup2.4-dev libsqlite3-dev libxml2-dev
	#sudo apt full-upgrade -y
	if [[ "$APPVEYOR_BUILD_WORKER_IMAGE" = "Ubuntu1604" ]]; then
		sudo dpkg -i "$_SCRIPTROOT/deps/xenial/"*.deb
	fi
}

build_deb()
{
	set -e
	echo "[scripts/build.sh] Building deb package"
	cd "$_ROOT"
	sed "s/\$VERSION/$_DEB_VERSION/g; s/\$DISTRO/$_DEB_TARGET_DISTRO/g; s/\$DATE/`date -R`/g" "debian/changelog.in" > "debian/changelog"
	export DEB_BUILD_OPTIONS="nostrip nocheck"
	if [[ -e "$_SCRIPTROOT/launchpad/passphrase" && -n "$keys_enc_secret" ]]; then
		dpkg-buildpackage -S -sa -us -uc
		set +e
		debsign -p"gpg1 --no-use-agent --passphrase-file $_SCRIPTROOT/launchpad/passphrase --batch" -S -k2744E6BAF20BA10AAE92253F20442B9273408FF9 ../*.changes
		rm "$_SCRIPTROOT/launchpad/passphrase"
		echo "[scripts/build.sh] Uploading package to launchpad"
		dput -u -c "$_SCRIPTROOT/launchpad/dput.cf" "gamehub_$_DEB_TARGET_DISTRO" ../*.changes
		set -e
	fi
	dpkg-buildpackage -us -uc
	mkdir -p "build/$_BUILD_IMAGE"
	cp ../*.deb "build/$_BUILD_IMAGE/GameHub-$_VERSION-amd64.deb"
	cd "$_ROOT"
}

build()
{
	set -e
	echo "[scripts/build.sh] Building"
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
	set -e
	echo "[scripts/build.sh] Preparing AppImage"
	cd "$BUILDROOT"
	wget -c -nv "https://github.com/probonopd/linuxdeployqt/releases/download/continuous/$_LINUXDEPLOYQT"
	chmod a+x "./$_LINUXDEPLOYQT"
	unset QTDIR; unset QT_PLUGIN_PATH; unset LD_LIBRARY_PATH
	export VERSION="$_VERSION"
	export LD_LIBRARY_PATH=$APPDIR/usr/lib:$LD_LIBRARY_PATH
	"./$_LINUXDEPLOYQT" "$APPDIR/usr/share/applications/com.github.tkashkin.gamehub.desktop" -appimage -no-plugins -no-copy-copyright-files -verbose=2
}

appimage_tweak()
{
	set -e
	echo "[scripts/build.sh] Tweaking AppImage"
	cd "$BUILDROOT"
	rm -f "$APPDIR/AppRun"
	cp -f "$_SCRIPTROOT/AppRun" "$APPDIR/AppRun"
	glib-compile-schemas "$APPDIR/usr/share/glib-2.0/schemas"
}

appimage_bundle_libs()
{
	set +e
	echo "[scripts/build.sh] Bundling additional libs"
	cd "$BUILDROOT"

	mkdir -p "$APPDIR/usr/lib/x86_64-linux-gnu/webkit2gtk-4.0/"
	cp -rf "/usr/lib/x86_64-linux-gnu/webkit2gtk-4.0/injected-bundle/" "$APPDIR/usr/lib/x86_64-linux-gnu/webkit2gtk-4.0/"
	cp -f "/usr/lib/x86_64-linux-gnu/webkit2gtk-4.0/WebKitNetworkProcess" "$APPDIR/usr/lib/x86_64-linux-gnu/webkit2gtk-4.0/"
	cp -f "/usr/lib/x86_64-linux-gnu/webkit2gtk-4.0/WebKitStorageProcess" "$APPDIR/usr/lib/x86_64-linux-gnu/webkit2gtk-4.0/"
	cp -f "/usr/lib/x86_64-linux-gnu/webkit2gtk-4.0/WebKitWebProcess" "$APPDIR/usr/lib/x86_64-linux-gnu/webkit2gtk-4.0/"
	find "$APPDIR/usr/lib/" -maxdepth 1 -type f -name "libwebkit2gtk-4.0.so.*" -print0 | while read -d $'\0' file; do
		_usr_patch "$file"
	done
	find "$APPDIR/usr/lib/x86_64-linux-gnu/webkit2gtk-4.0/" -maxdepth 1 -type f -print0 | while read -d $'\0' file; do
		_usr_patch "$file"
	done
}

appimage_checkrt()
{
	set +e
	echo "[scripts/build.sh] Bundling checkrt libs"
	cd "$BUILDROOT"
	cp -f "$_SCRIPTROOT/checkrt.sh" "$APPDIR/checkrt.sh"
	cp -rf "$_SCRIPTROOT/optlib" "$APPDIR/usr/"

	echo "[scripts/build.sh] Moving GTK and its dependencies"
	mkdir -p "$APPDIR/usr/optlib/libgtk-3.so.0/"
	_mv_deps "libgtk-3.so.0" "$APPDIR/usr/lib" "$APPDIR/usr/optlib/libgtk-3.so.0/"

	echo "[scripts/build.sh] Moving back non-GTK-specific dependencies"
	find "$APPDIR/usr/lib/" -maxdepth 1 -type f -not -name "libgranite.so.*" -not -name "libwebkit2gtk-4.0.so.*" -print0 | while read -d $'\0' dep; do
		_mv_deps "$(basename $dep)" "$APPDIR/usr/optlib/libgtk-3.so.0" "$APPDIR/usr/lib/" "false"
	done

	if [[ "$APPVEYOR_BUILD_WORKER_IMAGE" = "Ubuntu1804" ]]; then
		echo "[scripts/build.sh] Removing GTK and its dependencies"
		rm -rf "$APPDIR/usr/optlib/libgtk-3.so.0"
	fi

	for lib in 'libstdc++.so.6' 'libgcc_s.so.1'; do
		echo "[scripts/build.sh] Bundling $lib"
		mkdir -p "$APPDIR/usr/optlib/$lib"
		for dir in "/lib" "/usr/lib"; do
			libfile="$dir/x86_64-linux-gnu/$lib"
			[ -e "$libfile" ] && cp "$libfile" "$APPDIR/usr/optlib/$lib/"
		done
	done
}

appimage_pack()
{
	set -e
	echo "[scripts/build.sh] Packing AppImage"
	cd "$BUILDROOT"
	unset QTDIR; unset QT_PLUGIN_PATH; unset LD_LIBRARY_PATH
	export VERSION="$_VERSION"
	export LD_LIBRARY_PATH=$APPDIR/usr/lib:$LD_LIBRARY_PATH
	"./$_LINUXDEPLOYQT" --appimage-extract
	PATH=./squashfs-root/usr/bin:$PATH ./squashfs-root/usr/bin/appimagetool --no-appstream "$APPDIR"
}

build_flatpak()
{
	set +e
	echo "[scripts/build.sh] Building flatpak package"
	mkdir -p "$_ROOT/build/flatpak"
	cd "$_ROOT/build/flatpak"
	sudo apt install -y flatpak flatpak-builder
	sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
	git clone https://github.com/tkashkin/GameHub.git --branch flatpak --recursive --depth=1 "manifest"
	cd "manifest"
	sudo flatpak-builder -y --install-deps-from=flathub --install-deps-only build com.github.tkashkin.gamehub.json
	sudo flatpak update -y
	sudo flatpak-builder -y --repo=repo --force-clean build com.github.tkashkin.gamehub.json
	sudo flatpak build-bundle repo "$_ROOT/build/flatpak/GameHub-$_VERSION.flatpak" com.github.tkashkin.gamehub
}

mkdir -p "$BUILDROOT"

if [[ "$ACTION" = "import_keys" ]]; then import_keys; fi

if [[ "$ACTION" = "deps" ]]; then deps; fi

if [[ "$ACTION" = "build_deb" ]]; then build_deb; fi

if [[ "$ACTION" = "build" || "$ACTION" = "build_local" ]]; then build; fi

if [[ "$ACTION" = "appimage" || "$ACTION" = "build_local" ]]; then appimage; fi
if [[ "$ACTION" = "appimage_tweak" || "$ACTION" = "build_local" ]]; then appimage_tweak; fi
if [[ "$ACTION" = "appimage_bundle_libs" || "$ACTION" = "build_local" ]]; then appimage_bundle_libs; fi
if [[ "$ACTION" = "appimage_checkrt" || ( "$ACTION" = "build_local" && "$CHECKRT" = "--checkrt" ) ]]; then appimage_checkrt; fi
if [[ "$ACTION" = "appimage_pack" || "$ACTION" = "build_local" ]]; then appimage_pack; fi

if [[ "$ACTION" = "build_flatpak" && "$_BUILD_IMAGE" = "bionic" ]]; then build_flatpak; fi
