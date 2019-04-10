project_config = vcs_tag(
	input: vcs_tag(
		input: vcs_tag(
			input: configure_file(
				input: 'ProjectConfig.vala.in',
				output: 'ProjectConfig.vala.in.in.in',
				configuration: conf_data
			),
			output: 'ProjectConfig.vala.in.in',
			command: ['git', 'rev-parse', '--short', 'HEAD'],
			replace_string: '@GIT_COMMIT_SHORT@',
			fallback: ''
		),
		output: 'ProjectConfig.vala.in',
		command: ['git', 'rev-parse', 'HEAD'],
		replace_string: '@GIT_COMMIT@',
		fallback: ''
	),
	output: 'ProjectConfig.vala',
	command: ['git', 'symbolic-ref', '--short', '-q', 'HEAD'],
	replace_string: '@GIT_BRANCH@',
	fallback: ''
)

deps = [
	dependency('granite', version: '>=5.2.0'),
	dependency('gdk-3.0'),
	dependency('webkit2gtk-4.0'),
	dependency('glib-2.0'),
	dependency('json-glib-1.0'),
	dependency('gee-0.8'),
	dependency('sqlite3'),
	dependency('libxml-2.0'),
	dependency('polkit-gobject-1'),
	meson.get_compiler('vala').find_library('posix'),
	meson.get_compiler('vala').find_library('linux')
]

sources = [
	'app.vala',

	'data/Runnable.vala',
	'data/Game.vala',
	'data/GameSource.vala',
	'data/Emulator.vala',

	'data/sources/steam/Steam.vala',
	'data/sources/steam/SteamGame.vala',

	'data/sources/gog/GOG.vala',
	'data/sources/gog/GOGGame.vala',

	'data/sources/humble/Humble.vala',
	'data/sources/humble/HumbleGame.vala',
	'data/sources/humble/Trove.vala',

	'data/sources/user/User.vala',
	'data/sources/user/UserGame.vala',

	'data/db/Database.vala',
	'data/db/Table.vala',
	'data/db/tables/Games.vala',
	'data/db/tables/Tags.vala',
	'data/db/tables/Merges.vala',
	'data/db/tables/Emulators.vala',

	'data/CompatTool.vala',
	'data/compat/CustomScript.vala',
	'data/compat/Innoextract.vala',
	'data/compat/WineWrap.vala',
	'data/compat/Proton.vala',
	'data/compat/Wine.vala',
	'data/compat/DOSBox.vala',
	'data/compat/ScummVM.vala',
	'data/compat/RetroArch.vala',
	'data/compat/CustomEmulator.vala',

	'data/adapters/GamesAdapter.vala',

	'ui/windows/MainWindow.vala',
	'ui/windows/WebAuthWindow.vala',

	'ui/dialogs/SettingsDialog/SettingsDialog.vala',
	'ui/dialogs/SettingsDialog/SettingsDialogTab.vala',

	'ui/dialogs/SettingsDialog/tabs/UI.vala',
	'ui/dialogs/SettingsDialog/tabs/Collection.vala',
	'ui/dialogs/SettingsDialog/tabs/Steam.vala',
	'ui/dialogs/SettingsDialog/tabs/GOG.vala',
	'ui/dialogs/SettingsDialog/tabs/Humble.vala',
	'ui/dialogs/SettingsDialog/tabs/RetroArch.vala',
	'ui/dialogs/SettingsDialog/tabs/Emulators.vala',

	'ui/dialogs/InstallDialog.vala',
	'ui/dialogs/GameDetailsDialog.vala',
	'ui/dialogs/GamePropertiesDialog.vala',
	'ui/dialogs/GameFSOverlaysDialog.vala',
	'ui/dialogs/CompatRunDialog.vala',
	'ui/dialogs/CorruptedInstallerDialog.vala',
	'ui/dialogs/AboutDialog.vala',

	'ui/views/BaseView.vala',
	'ui/views/WelcomeView.vala',

	'ui/views/GamesView/GamesView.vala',
	'ui/views/GamesView/GameCard.vala',
	'ui/views/GamesView/GameListRow.vala',
	'ui/views/GamesView/DownloadProgressView.vala',
	'ui/views/GamesView/FiltersPopover.vala',
	'ui/views/GamesView/AddGamePopover.vala',
	'ui/views/GamesView/GameContextMenu.vala',

	'ui/views/GameDetailsView/GameDetailsView.vala',
	'ui/views/GameDetailsView/GameDetailsPage.vala',

	'ui/views/GameDetailsView/GameDetailsBlock.vala',
	'ui/views/GameDetailsView/blocks/Playtime.vala',
	'ui/views/GameDetailsView/blocks/Achievements.vala',
	'ui/views/GameDetailsView/blocks/Description.vala',
	'ui/views/GameDetailsView/blocks/GOGDetails.vala',
	'ui/views/GameDetailsView/blocks/SteamDetails.vala',

	'ui/widgets/AutoSizeImage.vala',
	'ui/widgets/ActionButton.vala',
	'ui/widgets/FileChooserEntry.vala',
	'ui/widgets/CompatToolOptions.vala',
	'ui/widgets/CompatToolPicker.vala',
	'ui/widgets/TagRow.vala',

	'utils/Utils.vala',
	'utils/FSUtils.vala',
	'utils/FSOverlay.vala',
	'utils/Parser.vala',
	'utils/Settings.vala',
	'utils/BinaryVDF.vala',

	'utils/downloader/Downloader.vala',
	'utils/downloader/SoupDownloader.vala'
]

gtk322 = dependency('gtk+-3.0', version: '>=3.22', required: false)
if gtk322.found()
	add_global_arguments('-D', 'GTK_3_22', language: 'vala')
	deps += gtk322
else
	deps += dependency('gtk+-3.0')
endif

# not sure which version fixed Message.response_headers.get_content_range(), 2.60+ should work
soup260 = dependency('libsoup-2.4', version: '>=2.60', required: false)
if soup260.found()
	add_global_arguments('-D', 'SOUP_2_60', language: 'vala')
	deps += soup260
else
	deps += dependency('libsoup-2.4')
endif

unity = dependency('unity', required: false)
if unity.found()
	add_global_arguments('-D', 'UNITY', language: 'vala')
	deps += unity
endif

manette = dependency('manette-0.2', required: false)
if manette.found()
	add_global_arguments('-D', 'MANETTE', language: 'vala')
	deps += manette
	deps += dependency('x11')
	deps += dependency('gdk-x11-3.0')
	deps += dependency('xtst')
	sources += 'utils/Gamepad.vala'
	sources += 'ui/dialogs/SettingsDialog/tabs/Controller.vala'
endif

executable(
	meson.project_name(),
	project_config,

	sources,

	icons_gresource,
	css_gresource,

	dependencies: deps,
	install: true
)
