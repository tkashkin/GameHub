#!/bin/bash

_CRT_LIB_PATH=""

echo "[CheckRT] Checking library versions"

_CRT_LIBS=(
	'libstdc++.so.6':'^GLIBCXX_[0-9]\.[0-9]'
	'libgcc_s.so.1':'^GCC_[0-9]\.[0-9]'
)

_CRT_LIBS_PREFER_SYSTEM=(
	'libgtk-3.so.0':'^gtk_scrolled_window_set_propagate_natural_width' # GTK 3.22+
)

for lib in ${_CRT_LIBS[@]}; do
	lib_filename=$(echo "$lib" | cut -d: -f1)
	version_prefix=$(echo "$lib" | cut -d: -f2)
	lib_dir="$APPDIR/usr/optlib/$lib_filename"
	lib_path="$lib_dir/$lib_filename"
	if [ -e "$lib_path" ]; then
		lib=$(PATH="/sbin:$PATH" ldconfig -p | grep "$lib_filename" | awk 'NR==1 {print $NF}')
		sym_sys=$(tr '\0' '\n' < "$lib" | grep -e "$version_prefix" | tail -n1)
		sym_app=$(tr '\0' '\n' < "$lib_path" | grep -e "$version_prefix" | tail -n1)
		echo "[CheckRT] $lib_filename: sys: $sym_sys; app: $sym_app"
		if [ z$(printf "$sym_sys\n$sym_app" | sort -V | tail -1) != z"$sym_sys" ]; then
			_CRT_LIB_PATH="$lib_dir:$_CRT_LIB_PATH"
		fi
	fi
done

for lib in ${_CRT_LIBS_PREFER_SYSTEM[@]}; do
	lib_filename=$(echo "$lib" | cut -d: -f1)
	version_prefix=$(echo "$lib" | cut -d: -f2)
	lib_dir="$APPDIR/usr/optlib/$lib_filename"
	lib_path="$lib_dir/$lib_filename"
	if [ -e "$lib_path" ]; then
		lib=$(PATH="/sbin:$PATH" ldconfig -p | grep "$lib_filename" | awk 'NR==1 {print $NF}')
		sym_sys=$(tr '\0' '\n' < "$lib" | grep -e "$version_prefix" | tail -n1)
		if [ -z "$sym_sys" ]; then
			_CRT_LIB_PATH="$lib_dir:$_CRT_LIB_PATH"
		else
			echo "[CheckRT] Using system version of $lib_filename"
		fi
	fi
done

export LD_LIBRARY_PATH="$_CRT_LIB_PATH:$LD_LIBRARY_PATH"

if [ -e "$APPDIR/usr/optlib/exec.so" ]; then
	export LD_PRELOAD="$APPDIR/usr/optlib/exec.so:$LD_PRELOAD"
fi

echo "[CheckRT] LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
echo "[CheckRT] LD_PRELOAD: $LD_PRELOAD"
