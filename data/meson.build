icon_sizes = ['32', '48', '64', '128']

foreach i : icon_sizes
	install_data(
		join_paths('icon', i + '.svg'),
		install_dir: join_paths(get_option('prefix'), get_option('datadir'), 'icons', 'hicolor', i + 'x' + i, 'apps'),
		rename: meson.project_name() + '.svg'
	)
	install_data(
		join_paths('icon', i + '.svg'),
		install_dir: join_paths(get_option('prefix'), get_option('datadir'), 'icons', 'hicolor', i + 'x' + i + '@2', 'apps'),
		rename: meson.project_name() + '.svg'
	)
endforeach

install_data(
	meson.project_name() + '.gschema.xml',
	install_dir: join_paths(get_option('prefix'), get_option('datadir'), 'glib-2.0', 'schemas')
)

install_subdir('share/compat', install_dir: join_paths(get_option('prefix'), get_option('datadir'), meson.project_name()))
install_subdir('share/tweaks', install_dir: join_paths(get_option('prefix'), get_option('datadir'), meson.project_name()))

i18n.merge_file(
	input: meson.project_name() + '.desktop.in',
	output: meson.project_name() + '.desktop',
	po_dir: join_paths(meson.source_root(), 'po'),
	type: 'desktop',
	install: true,
	install_dir: join_paths(get_option('prefix'), get_option('datadir'), 'applications')
)

appdata_changelog_conf = configuration_data()
appdata_changelog_conf.set('CHANGELOG', run_command('cat', files(meson.project_name() + '.changelog.xml')).stdout().strip())

configure_file(
	input: meson.project_name() + '.appdata.xml.in',
	output: meson.project_name() + '.appdata.xml',
	configuration: appdata_changelog_conf,
	install: true,
	install_dir: join_paths(get_option('prefix'), get_option('datadir'), 'metainfo')
)

polkit_policy = configure_file(
	input: meson.project_name() + '.policy.in',
	output: meson.project_name() + '.policy',
	configuration: conf_data
)

install_data(
	polkit_policy,
	install_dir: join_paths(get_option('prefix'), get_option('datadir'), 'polkit-1', 'actions')
)

install_data(
	meson.project_name() + '-overlayfs-helper',
	install_dir: join_paths(get_option('prefix'), get_option('bindir'))
)

icons_gresource = gnome.compile_resources(
	'gresource_icons',
	'icons/icons.gresource.xml',
	source_dir: 'icons'
)

css_gresource = gnome.compile_resources(
	'gresource_css',
	meson.project_name() + '.gresource.xml'
)
