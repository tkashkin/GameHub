foreach size: ['32', '48', '64', '128']
	install_data(
		'icon' / (size + '.svg'),
		rename: gh_rdnn + '.svg',
		install_dir: get_option('prefix') / get_option('datadir') / 'icons' / 'hicolor' / (size + 'x' + size) / 'apps'
	)
	install_data(
		'icon' / (size + '.svg'),
		rename: gh_rdnn + '.svg',
		install_dir: get_option('prefix') / get_option('datadir') / 'icons' / 'hicolor' / (size + 'x' + size + '@2') / 'apps'
	)
endforeach

gh_data_config = {
	'RDNN': gh_rdnn,
	'SCHEMA_ID': gh_rdnn,
	'SCHEMA_PATH': '/' + gh_rdnn.replace('.', '/'),
	'PREF_API_KEY_STEAM': get_option('api_key_steam'),
	'PREF_API_KEY_ITCH': get_option('api_key_itch'),
	'PREF_API_KEY_IGDB': get_option('api_key_igdb'),
	'PREF_API_KEY_STEAMGRIDDB': get_option('api_key_steamgriddb'),
	'PREFIX': get_option('prefix'),
	'BINDIR': get_option('prefix') / get_option('bindir'),
	'DATADIR': get_option('prefix') / get_option('datadir'),
	'LOCALEDIR': get_option('prefix') / get_option('localedir'),
	'GETTEXT_DOMAIN': gh_gettext_domain
}

configure_file(
	input: 'gamehub.gschema.xml.in',
	output: gh_rdnn + '.gschema.xml',
	configuration: gh_data_config,
	install: true,
	install_dir: get_option('prefix') / get_option('datadir') / 'glib-2.0' / 'schemas'
)

install_subdir('share/compat', install_dir: get_option('prefix') / get_option('datadir') / gh_rdnn)
install_subdir('share/tweaks', install_dir: get_option('prefix') / get_option('datadir') / gh_rdnn)

import('i18n').merge_file(
	input: configure_file(
		input: 'gamehub.desktop',
		output: gh_rdnn + '.desktop.in',
		configuration: gh_data_config
	),
	output: gh_rdnn + '.desktop',
	po_dir: meson.project_source_root() / 'po',
	type: 'desktop',
	install: true,
	install_dir: get_option('prefix') / get_option('datadir') / 'applications'
)

import('i18n').merge_file(
	input: configure_file(
		input: 'gamehub.metainfo.xml',
		output: gh_rdnn + '.metainfo.xml.in',
		configuration: gh_data_config + {'CHANGELOG': run_command('cat', files('gamehub.changelog.xml')).stdout().strip()}
	),
	output: gh_rdnn + '.metainfo.xml',
	po_dir: meson.project_source_root() / 'po',
	type: 'xml',
	install: true,
	install_dir: get_option('prefix') / get_option('datadir') / 'metainfo'
)

configure_file(
	input: 'gamehub.policy',
	output: gh_rdnn + '.policy',
	configuration: gh_data_config,
	install: true,
	install_dir: get_option('prefix') / get_option('datadir') / 'polkit-1' / 'actions'
)

install_data(
	'gamehub-overlayfs-helper',
	rename: gh_rdnn + '-overlayfs-helper',
	install_dir: get_option('prefix') / get_option('bindir')
)
