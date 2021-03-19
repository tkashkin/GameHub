subdir('config')

gh_deps = [
	dependency('glib-2.0', version: '>=2.62'),
	dependency('gtk+-3.0', version: '>=3.22'),
	dependency('libsoup-2.4', version: '>=2.60'),
	dependency('gdk-3.0'),
	dependency('json-glib-1.0'),
	dependency('gee-0.8'),
	dependency('sqlite3'),
	dependency('libxml-2.0'),
	dependency('gio-unix-2.0'),
	dependency('zlib'),
	meson.get_compiler('vala').find_library('posix'),
	meson.get_compiler('vala').find_library('linux')
]

gh_sources = files(
	'app.vala',

	#'data/Runnable.vala',
	#'data/Game.vala',
	'data/GameSource.vala',
	#'data/Emulator.vala',

	'data/Platform.vala',

	'data/runnables/Runnable.vala',
	'data/runnables/Game.vala',

	'data/runnables/tasks/install/Installer.vala',
	'data/runnables/tasks/install/InstallerType.vala',
	'data/runnables/tasks/install/InstallTask.vala',

	'data/runnables/tasks/run/RunTask.vala',

	'data/runnables/traits/HasExecutableFile.vala',
	'data/runnables/traits/SupportsCompatTools.vala',
	'data/runnables/traits/HasActions.vala',

	'data/runnables/traits/game/HasAchievements.vala',
	'data/runnables/traits/game/SupportsOverlays.vala',
	'data/runnables/traits/game/SupportsTweaks.vala',

	'data/sources/steam/Steam.vala',
	'data/sources/steam/SteamGame.vala',

	'data/sources/epicgames/EpicAnalysis.vala',
	'data/sources/epicgames/EpicChunk.vala',
	'data/sources/epicgames/EpicDownloader.vala',
	'data/sources/epicgames/EpicGame.vala',
	'data/sources/epicgames/EpicGames.vala',
	'data/sources/epicgames/EpicGamesServices.vala',
	'data/sources/epicgames/EpicInstaller.vala',
	'data/sources/epicgames/EpicManifest.vala',
	'data/sources/epicgames/EpicUtils.vala',

	'data/sources/gog/GOG.vala',
	'data/sources/gog/GOGGame.vala',

	'data/sources/humble/Humble.vala',
	'data/sources/humble/HumbleGame.vala',
	'data/sources/humble/Trove.vala',

	'data/sources/itch/Itch.vala',
	'data/sources/itch/ItchGame.vala',
	'data/sources/itch/ItchDownloader.vala',
	'data/sources/itch/ButlerDaemon.vala',
	'data/sources/itch/ButlerConnection.vala',
	'data/sources/itch/ButlerClient.vala',

	'data/sources/user/User.vala',
	'data/sources/user/UserGame.vala',

	'data/db/Database.vala',
	'data/db/Table.vala',
	'data/db/tables/Games.vala',
	'data/db/tables/Tags.vala',
	'data/db/tables/Merges.vala',
	'data/db/tables/IGDBData.vala',
	'data/db/tables/CompatTools.vala',
	#'data/db/tables/Emulators.vala',

	'data/compat/CompatTool.vala',

	'data/compat/tools/wine/Wine.vala',
	'data/compat/tools/wine/WineOptions.vala',

	'data/compat/tools/proton/Proton.vala',

	'data/compat/tools/SteamCompatTool.vala',

	#'data/compat/tools/CustomScript.vala',
	#'data/compat/tools/Innoextract.vala',
	#'data/compat/tools/WineWrap.vala',
	#'data/compat/tools/DOSBox.vala',
	#'data/compat/tools/ScummVM.vala',
	#'data/compat/tools/RetroArch.vala',
	#'data/compat/CustomEmulator.vala',

	'data/adapters/GamesAdapter.vala',

	'data/providers/Provider.vala',
	'data/providers/ImagesProvider.vala',
	'data/providers/DataProvider.vala',
	'data/providers/images/Steam.vala',
	'data/providers/images/SteamGridDB.vala',
	'data/providers/images/JinxSGVI.vala',
	'data/providers/data/IGDB.vala',

	'data/tweaks/Tweak.vala',
	'data/tweaks/Option.vala',
	'data/tweaks/ApplicabilityOptions.vala',
	'data/tweaks/Requirements.vala',
	'data/tweaks/TweakOptions.vala',
	'data/tweaks/TweakSet.vala',

	'ui/windows/MainWindow.vala',
	'ui/windows/WebAuthWindow.vala',

	'ui/dialogs/SettingsDialog/SettingsDialog.vala',
	'ui/dialogs/SettingsDialog/SettingsDialogPage.vala',

	'ui/dialogs/SettingsDialog/pages/ui/Appearance.vala',
	'ui/dialogs/SettingsDialog/pages/ui/Behavior.vala',
	'ui/dialogs/SettingsDialog/pages/general/Collection.vala',
	'ui/dialogs/SettingsDialog/pages/general/CompatTools.vala',
	'ui/dialogs/SettingsDialog/pages/general/Tweaks.vala',
	'ui/dialogs/SettingsDialog/pages/sources/Steam.vala',
	'ui/dialogs/SettingsDialog/pages/sources/EpicGames.vala',
	'ui/dialogs/SettingsDialog/pages/sources/GOG.vala',
	'ui/dialogs/SettingsDialog/pages/sources/Humble.vala',
	'ui/dialogs/SettingsDialog/pages/sources/Itch.vala',
	#'ui/dialogs/SettingsDialog/pages/emulators/RetroArch.vala',
	#'ui/dialogs/SettingsDialog/pages/emulators/Emulators.vala',
	'ui/dialogs/SettingsDialog/pages/providers/Providers.vala',
	'ui/dialogs/SettingsDialog/pages/About.vala',

	'ui/dialogs/InstallDialog/InstallDialog.vala',
	'ui/dialogs/InstallDialog/steps/InstallerStep.vala',
	'ui/dialogs/InstallDialog/steps/InstallDirStep.vala',
	'ui/dialogs/InstallDialog/steps/CompatToolStep.vala',

	'ui/dialogs/GamePropertiesDialog/GamePropertiesDialog.vala',
	'ui/dialogs/GamePropertiesDialog/tabs/General.vala',
	'ui/dialogs/GamePropertiesDialog/tabs/Executable.vala',
	'ui/dialogs/GamePropertiesDialog/tabs/Compat.vala',
	'ui/dialogs/GamePropertiesDialog/tabs/Tweaks.vala',
	'ui/dialogs/GamePropertiesDialog/tabs/Overlays.vala',

	'ui/dialogs/GameDetailsDialog.vala',
	'ui/dialogs/CorruptedInstallerDialog.vala',
	#'ui/dialogs/ImportEmulatedGamesDialog.vala',

	'ui/views/BaseView.vala',
	'ui/views/WelcomeView.vala',

	'ui/views/GamesView/GamesView.vala',

	'ui/views/GamesView/grid/GamesGrid.vala',
	'ui/views/GamesView/grid/GameCard.vala',

	'ui/views/GamesView/list/GamesList.vala',
	'ui/views/GamesView/list/GameListRow.vala',

	'ui/views/GamesView/DownloadProgressView.vala',
	'ui/views/GamesView/FiltersPopover.vala',
	'ui/views/GamesView/AddGamePopover.vala',
	'ui/views/GamesView/GameContextMenu.vala',

	'ui/views/GameDetailsView/GameDetailsView.vala',
	'ui/views/GameDetailsView/MultipleGamesDetailsView.vala',
	'ui/views/GameDetailsView/GameDetailsPage.vala',

	'ui/views/GameDetailsView/GameDetailsBlock.vala',
	'ui/views/GameDetailsView/blocks/Artwork.vala',
	'ui/views/GameDetailsView/blocks/Playtime.vala',
	'ui/views/GameDetailsView/blocks/Achievements.vala',
	'ui/views/GameDetailsView/blocks/Description.vala',
	'ui/views/GameDetailsView/blocks/GOGDetails.vala',
	'ui/views/GameDetailsView/blocks/SteamDetails.vala',
	'ui/views/GameDetailsView/blocks/IGDBInfo.vala',

	'ui/widgets/AutoSizeImage.vala',
	'ui/widgets/ActionButton.vala',
	'ui/widgets/FileChooserEntry.vala',
	'ui/widgets/VariableEntry.vala',
	'ui/widgets/ExtendedStackSwitcher.vala',
	'ui/widgets/ImagesDownloadPopover.vala',
	'ui/widgets/GameTagsList.vala',
	'ui/widgets/TagRow.vala',
	'ui/widgets/Styles.vala',
	'ui/widgets/AlertView.vala',
	'ui/widgets/ModeButton.vala',
	'ui/widgets/OverlayBar.vala',
	'ui/widgets/Welcome.vala',
	'ui/widgets/DirectoriesList.vala',

	'ui/widgets/compat/CompatToolsList.vala',
	'ui/widgets/compat/tabs/Wine.vala',
	'ui/widgets/compat/tabs/Proton.vala',
	'ui/widgets/compat/tabs/SteamCompatTools.vala',

	'ui/widgets/settings/SettingsSidebar.vala',
	'ui/widgets/settings/SettingsGroup.vala',
	'ui/widgets/settings/Settings.vala',

	'ui/widgets/tweaks/TweaksList.vala',
	'ui/widgets/tweaks/TweakRow.vala',
	'ui/widgets/tweaks/TweakOptionsPopover.vala',

	'utils/Utils.vala',
	'utils/TypeUtils.vala',

	'utils/ExecTask.vala',
	'utils/OS.vala',

	'utils/fs/FS.vala',
	'utils/fs/FSOverlay.vala',

	'utils/ImageCache.vala',
	'utils/Parser.vala',
	'utils/BinaryVDF.vala',
	'utils/SignalRateLimiter.vala',
	'utils/Inhibitor.vala',

	'settings/Settings.vala',
	'settings/UI.vala',
	'settings/SavedState.vala',
	'settings/Auth.vala',
	'settings/Compat.vala',
	'settings/Paths.vala',
	'settings/Providers.vala',
	'settings/Controller.vala',
	'settings/Tweaks.vala',

	'utils/downloader/Downloader.vala',
	'utils/downloader/SoupDownloader.vala'
)

gh_dep_webkit2gtk = dependency('webkit2gtk-4.0', required: false)
if gh_dep_webkit2gtk.found()
	add_project_arguments('-D', 'WEBKIT2GTK', language: 'vala')
	gh_deps += gh_dep_webkit2gtk
endif

if gh_target == 'linux' and not get_option('overlayfs').disabled()
	add_project_arguments('-D', 'OVERLAYFS', language: 'vala')
	gh_dep_polkit = dependency('polkit-gobject-1', required: false)
	if gh_dep_polkit.found()
		add_project_arguments('-D', 'POLKIT', language: 'vala')
		gh_deps += gh_dep_polkit
	endif
endif

gh_dep_manette = dependency('manette-0.2', required: false)
if gh_dep_manette.found()
	add_project_arguments('-D', 'MANETTE', language: 'vala')
	gh_deps += gh_dep_manette
	gh_deps += dependency('x11')
	gh_deps += dependency('gdk-x11-3.0')
	gh_deps += dependency('xtst')
	gh_sources += 'utils/Gamepad.vala'
	gh_sources += 'ui/dialogs/SettingsDialog/pages/general/Controller.vala'
endif

executable(
	gh_rdnn,
	gh_config,

	gh_sources,

	gh_icons,
	gh_styles,

	dependencies: gh_deps,
	install: true,
	win_subsystem: 'windows'
)
