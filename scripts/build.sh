#!/bin/bash

_GH_RDNN="com.github.tkashkin.gamehub"
_GH_VERSION="0.13.1"

_GH_BRANCH="${APPVEYOR_REPO_BRANCH:-$(git symbolic-ref --short -q HEAD)}"
_GH_COMMIT="$(git rev-parse HEAD)"
_GH_COMMIT_SHORT="$(git rev-parse --short HEAD)"

_ROOT="`pwd`"
_SCRIPTROOT="$(dirname "$(readlink -f "$0")")"
_LINUXDEPLOYQT="linuxdeployqt-5-x86_64.AppImage"

_SOURCE="${APPVEYOR_BUILD_VERSION:-$_GH_VERSION-$_GH_BRANCH-local}"
_VERSION="$_SOURCE-$_GH_COMMIT_SHORT"
_BUILD_VERSION="${APPVEYOR_BUILD_VERSION:-$_VERSION}"
_DEB_VERSION="$_BUILD_VERSION"
_DEB_TARGET_DISTRO="bionic"
_BUILD_IMAGE="local"
_GPG_BINARY="gpg1"
_GPG_PACKAGE="gnupg1"

export CFLAGS="$CFLAGS -O0"

if [[ "$APPVEYOR_BUILD_WORKER_IMAGE" = "Ubuntu1604" ]]; then
	_VERSION="xenial-$_VERSION"
	_DEB_VERSION="$_DEB_VERSION~ubuntu16.04"
	_DEB_TARGET_DISTRO="xenial"
	_BUILD_IMAGE="xenial"
	_GPG_BINARY="gpg"
	_GPG_PACKAGE="gnupg"
elif [[ "$APPVEYOR_BUILD_WORKER_IMAGE" = "Ubuntu1804" ]]; then
	_VERSION="bionic-$_VERSION"
	_DEB_VERSION="$_DEB_VERSION~ubuntu18.04"
	_DEB_TARGET_DISTRO="bionic"
	_BUILD_IMAGE="bionic"
	_GPG_BINARY="gpg1"
	_GPG_PACKAGE="gnupg1"
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
		sudo apt install -y "$_GPG_PACKAGE"
		curl -sflL "https://raw.githubusercontent.com/appveyor/secure-file/master/install.sh" | bash -e -
		./appveyor-tools/secure-file -decrypt "$_SCRIPTROOT/launchpad/key_pub.gpg.enc" -secret $keys_enc_secret
		./appveyor-tools/secure-file -decrypt "$_SCRIPTROOT/launchpad/key_sec.gpg.enc" -secret $keys_enc_secret
		./appveyor-tools/secure-file -decrypt "$_SCRIPTROOT/launchpad/passphrase.enc" -secret $keys_enc_secret
		"$_GPG_BINARY" --no-use-agent --import "$_SCRIPTROOT/launchpad/key_pub.gpg"
		"$_GPG_BINARY" --no-use-agent --allow-secret-key-import --import "$_SCRIPTROOT/launchpad/key_sec.gpg"
		sudo apt-key add "$_SCRIPTROOT/launchpad/key_pub.gpg"
		rm -f "$_SCRIPTROOT/launchpad/key_pub.gpg" "$_SCRIPTROOT/launchpad/key_sec.gpg"
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
	sudo apt install -y meson valac checkinstall build-essential dput fakeroot moreutils git-buildpackage elementary-sdk libgranite-dev libgtk-3-dev libglib2.0-dev libwebkit2gtk-4.0-dev libjson-glib-dev libgee-0.8-dev libsoup2.4-dev libsqlite3-dev libxml2-dev libpolkit-gobject-1-dev libunity-dev
	#sudo apt full-upgrade -y
	if [[ "$APPVEYOR_BUILD_WORKER_IMAGE" = "Ubuntu1604" ]]; then
		sudo dpkg -i "$_SCRIPTROOT/deps/xenial/"*.deb
	else
		sudo apt install -y libmanette-0.2-dev libxtst-dev libx11-dev
	fi
}

gen_changelogs()
{
	set +e
	cd "$_ROOT"
	echo "[scripts/build.sh] Generating changelogs"

	if [[ -z `git config user.name` ]]; then
		git config user.email "ci@localhost"
		git config user.name "CI"
	fi

	git fetch --tags

	git tag -a $_BUILD_VERSION -m $_BUILD_VERSION

	> "debian/changelog"
	> "data/$_GH_RDNN.changelog.xml"

	prevtag="initial"
	git tag --sort v:refname | while read tag; do
		if [[ "$prevtag" == "initial" ]]; then
			prevtag="$tag"
			continue
		fi

		commitmsg=`git log --pretty=format:'  * %s [%h]' $prevtag..$tag`

		(
			echo "$_GH_RDNN ($tag) $_DEB_TARGET_DISTRO; urgency=low"
			echo "${commitmsg:-  * <no commit message>}"
			git log -n1 --pretty='format:%n -- %aN <%aE>  %aD%n%n' $tag^..$tag
		) | cat - "debian/changelog" | sponge "debian/changelog"

		xml_r_type="development" && [[ "$tag" == *"-master" ]] && xml_r_type="stable"
		xml_r_date=`git log -n1 --date=short --pretty='format:date="%cd" timestamp="%ct"' $tag^..$tag`
		xml_r_end=" />" && [[ -n "$commitmsg" ]] && xml_r_end=">"
		xml_ver=`echo "$tag" | sed -E "s|-|.|g"`

		(
			echo -e "\t\t<release type=\"$xml_r_type\" version=\"$xml_ver\" $xml_r_date$xml_r_end"

			if [[ -n "$commitmsg" ]]; then
				echo -e "\t\t\t<description>"
				echo -e "\t\t\t\t<ul>"

				echo "$commitmsg" | sed -E "s|<|\&lt;|g; s|>|\&gt;|g; s|  \* (.*)|\t\t\t\t\t<li>\1</li>|g"

				echo -e "\t\t\t\t</ul>"
				echo -e "\t\t\t</description>"
				echo -e "\t\t</release>"
			fi
		) | cat - "data/$_GH_RDNN.changelog.xml" | sponge "data/$_GH_RDNN.changelog.xml"

		prevtag="$tag"
	done

	git tag -d $_BUILD_VERSION
}

build_deb()
{
	set -e
	cd "$_ROOT"
	sed "s/\$_GH_BRANCH/$_GH_BRANCH/g; s/\$_GH_COMMIT_SHORT/$_GH_COMMIT_SHORT/g; s/\$_GH_COMMIT/$_GH_COMMIT/g" "debian/rules.in" > "debian/rules"
	if [[ "$APPVEYOR_BUILD_WORKER_IMAGE" = "Ubuntu1604" ]]; then
		sed "s/libmanette-0.2-dev,//g" "debian/control.in" > "debian/control"
	else
		cp -f "debian/control.in" "debian/control"
	fi
	echo "[scripts/build.sh] Building deb package"
	dpkg-buildpackage -F -sa -us -uc
	mkdir -p "build/$_BUILD_IMAGE"
	mv ../$_GH_RDNN*.deb "build/$_BUILD_IMAGE/GameHub-$_VERSION-amd64.deb"
	export DEB_BUILD_OPTIONS="noopt nostrip nocheck"
	if [[ -e "$_SCRIPTROOT/launchpad/passphrase" && -n "$keys_enc_secret" ]]; then
		set +e
		dpkg-buildpackage -S -sa -us -uc
		echo "[scripts/build.sh] Signing source package"
		debsign -p"$_GPG_BINARY --no-use-agent --passphrase-file $_SCRIPTROOT/launchpad/passphrase --batch" -S -k2744E6BAF20BA10AAE92253F20442B9273408FF9 "../${_GH_RDNN}_${_BUILD_VERSION}_source.changes"
		rm -f "$_SCRIPTROOT/launchpad/passphrase"
		echo "[scripts/build.sh] Uploading package to launchpad"
		dput -u -c "$_SCRIPTROOT/launchpad/dput.cf" "gamehub_$_DEB_TARGET_DISTRO" "../${_GH_RDNN}_${_BUILD_VERSION}_source.changes"
		set -e
	fi
	cd "$_ROOT"
}

build()
{
	set -e
	echo "[scripts/build.sh] Building"
	cd "$_ROOT"
	mkdir -p "$BUILDROOT"
	meson "$BUILDDIR" --prefix=/usr --buildtype=debug -Ddistro=generic -Dappimage=true -Dgit_branch=$_GH_BRANCH -Dgit_commit=$_GH_COMMIT -Dgit_commit_short=$_GH_COMMIT_SHORT
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
	wget -c -nv "https://github.com/probonopd/linuxdeployqt/releases/download/5/$_LINUXDEPLOYQT"
	chmod a+x "./$_LINUXDEPLOYQT"
	unset QTDIR; unset QT_PLUGIN_PATH; unset LD_LIBRARY_PATH
	export VERSION="$_VERSION"
	export LD_LIBRARY_PATH=$APPDIR/usr/lib:$LD_LIBRARY_PATH
	"./$_LINUXDEPLOYQT" "$APPDIR/usr/share/applications/$_GH_RDNN.desktop" -appimage -no-plugins -no-copy-copyright-files -verbose=2
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
	cd "$_ROOT"
	gen_changelogs
	git add "debian/changelog" "data/$_GH_RDNN.changelog.xml"
	git commit -m "Save generated changelog"
	mkdir -p "$_ROOT/build/flatpak"
	cd "$_ROOT/flatpak"
	echo "[scripts/build.sh] Installing flatpak"
	sudo apt install -y flatpak flatpak-builder
	flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
	sed "s/\$BRANCH/$_GH_BRANCH/g; s/\$COMMIT_SHORT/$_GH_COMMIT_SHORT/g; s/\$COMMIT/$_GH_COMMIT/g" "$_GH_RDNN.json.in" > "$_GH_RDNN.json"
	echo "[scripts/build.sh] Autoinstalling dependencies"
	flatpak-builder -y --user --install-deps-from=flathub --install-deps-only "$_ROOT/build/flatpak/build" "$_GH_RDNN.json"
	echo "[scripts/build.sh] Building"
	flatpak-builder -y --user --repo="$_ROOT/build/flatpak/repo" --force-clean "$_ROOT/build/flatpak/build" "$_GH_RDNN.json"
	echo "[scripts/build.sh] Building bundle"
	flatpak build-bundle "$_ROOT/build/flatpak/repo" "$_ROOT/build/flatpak/GameHub-$_VERSION.flatpak" "$_GH_RDNN"
	echo "[scripts/build.sh] Removing flatpak build and repo directories"
	rm -rf ".flatpak-builder" "$_ROOT/build/flatpak/build" "$_ROOT/build/flatpak/repo"
	return 0
}

set +e
cd "$_ROOT"
git submodule update --init
mkdir -p "$BUILDROOT"

if [[ "$ACTION" = "import_keys" ]]; then import_keys; fi

if [[ "$ACTION" = "deps" ]]; then deps; fi

if [[ "$ACTION" = "gen_changelogs" ]]; then gen_changelogs; fi

if [[ "$ACTION" = "build_deb" ]]; then build_deb; fi

if [[ "$ACTION" = "build" || "$ACTION" = "build_local" ]]; then build; fi

if [[ "$ACTION" = "appimage" || "$ACTION" = "build_local" ]]; then appimage; fi
if [[ "$ACTION" = "appimage_tweak" || "$ACTION" = "build_local" ]]; then appimage_tweak; fi
if [[ "$ACTION" = "appimage_bundle_libs" || "$ACTION" = "build_local" ]]; then appimage_bundle_libs; fi
if [[ "$ACTION" = "appimage_checkrt" || ( "$ACTION" = "build_local" && "$CHECKRT" = "--checkrt" ) ]]; then appimage_checkrt; fi
if [[ "$ACTION" = "appimage_pack" || "$ACTION" = "build_local" ]]; then appimage_pack; fi

if [[ "$ACTION" = "build_appimage" ]]; then
	build
	appimage
	appimage_tweak
	appimage_bundle_libs
	appimage_checkrt
	appimage_pack
fi

if [[ "$ACTION" = "build_flatpak" && ! "$_BUILD_IMAGE" = "xenial" ]]; then build_flatpak; fi
