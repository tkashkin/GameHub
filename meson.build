project('com.github.tkashkin.gamehub', 'vala', 'c')

i18n = import('i18n')
gnome = import('gnome')

add_global_arguments('-g', language: 'vala')
add_global_arguments('-X', language: 'vala')
add_global_arguments('-rdynamic', language: 'vala')
add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()), language: 'c')

subdir('data')
subdir('po')

executable(
    meson.project_name(),
    
    'src/app.vala',

	'src/data/Game.vala',
	'src/data/GameSource.vala',

	'src/data/sources/steam/Steam.vala',
	'src/data/sources/steam/SteamGame.vala',

	'src/data/sources/gog/GOG.vala',
	'src/data/sources/gog/GOGGame.vala',

	'src/ui/windows/MainWindow.vala',
	'src/ui/windows/WebAuthWindow.vala',
	
	'src/ui/views/BaseView.vala',
	'src/ui/views/WelcomeView.vala',
	
	'src/ui/views/GamesGridView/GamesGridView.vala',
	'src/ui/views/GamesGridView/GameCard.vala',
	
	'src/utils/Utils.vala',
	'src/utils/FSUtils.vala',
	'src/utils/Parser.vala',
	
	icons_gresource,
    css_gresource,
	
    dependencies: [
		dependency('granite'),
		dependency('gtk+-3.0'),
		dependency('gdk-3.0'),
		dependency('webkit2gtk-4.0'),
		dependency('glib-2.0'),
		dependency('json-glib-1.0'),
		dependency('gee-0.8'),
		dependency('libsoup-2.4'),
		dependency('ivy')
    ],
    install: true
)
