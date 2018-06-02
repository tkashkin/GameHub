conf_data = configuration_data()
conf_data.set_quoted('PROJECT_NAME', meson.project_name())
conf_data.set_quoted('GETTEXT_PACKAGE', meson.project_name())
conf_data.set_quoted('VERSION', meson.project_version())
conf_data.set_quoted('PREFIX', get_option('prefix'))
project_config = configure_file(
	input : 'ProjectConfig.vala.in',
	output : 'ProjectConfig.vala',
	configuration : conf_data
)

executable(
	meson.project_name(),
	project_config,
	
	'app.vala',

	'data/Game.vala',
	'data/GameSource.vala',

	'data/sources/steam/Steam.vala',
	'data/sources/steam/SteamGame.vala',

	'data/sources/gog/GOG.vala',
	'data/sources/gog/GOGGame.vala',
	
	'data/GamesDB.vala',

	'ui/windows/MainWindow.vala',
	'ui/windows/WebAuthWindow.vala',
	
	'ui/dialogs/SettingsDialog.vala',
	'ui/dialogs/GOGGameInstallDialog.vala',

	'ui/views/BaseView.vala',
	'ui/views/WelcomeView.vala',

	'ui/views/GamesGridView/GamesGridView.vala',
	'ui/views/GamesGridView/GameCard.vala',
	'ui/views/GamesGridView/GameDownloadProgressView.vala',

	'ui/widgets/AutoSizeImage.vala',

	'utils/Utils.vala',
	'utils/FSUtils.vala',
	'utils/Parser.vala',
	'utils/Settings.vala',
	'utils/Downloader.vala',

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
        dependency('sqlite3'),
		#dependency('ivy'),
	],
	install: true
)
