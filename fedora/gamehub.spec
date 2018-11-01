%define gitshort  7e443e4
%define build_ver 9
%define branch dev
%define app_pkg com.github.tkashkin.gamehub

Name: gamehub
Version:	0.11.6
Release:	1.%{build_ver}.%{gitshort}%{?dist}
Summary:	Games manager/downloader/library written in Vala

License:	GPLv3
URL:		https://tkashkin.tk/projects/gamehub/
Source0:	https://github.com/tkashkin/GameHub/archive/%{version}-%{build_ver}-%{branch}.tar.gz#/gamehub-%{version}-%{build_ver}-%{branch}.tar.gz

BuildRequires:	meson
BuildRequires:	gcc
BuildRequires:	vala
BuildRequires:	pkgconfig(granite)
BuildRequires:	pkgconfig(webkit2gtk-4.0)
BuildRequires:	pkgconfig(json-glib-1.0)
BuildRequires:	pkgconfig(sqlite3)

BuildRequires: libappstream-glib
BuildRequires: desktop-file-utils

Recommends: innoextract
Recommends: dosbox
Recommends: wine
Recommends: file-roller

Suggests: steam


%description
GameHub allows to view, download, install, run and uninstall games from
Steam, GOG or Humble Bundle.

It also allows to download bonus content for GOG games.

%prep
%autosetup -n GameHub-%{version}-%{build_ver}-%{branch}


%build
%meson
%meson_build


%install
%meson_install
%find_lang %{app_pkg}

%check
appstream-util validate-relax --nonet %{buildroot}%{_metainfodir}/%{app_pkg}.appdata.xml
desktop-file-validate %{buildroot}/%{_datadir}/applications/%{app_pkg}.desktop

%files -f %{app_pkg}.lang
%{_bindir}/%{app_pkg}
%{_datadir}/applications/%{app_pkg}.desktop
%{_datadir}/%{app_pkg}/compat/dosbox/windowed.conf
%{_datadir}/glib-2.0/schemas/%{app_pkg}.gschema.xml
%{_datadir}/icons/hicolor/scalable/apps/%{app_pkg}.svg
%{_datadir}/metainfo/%{app_pkg}.appdata.xml




%changelog

