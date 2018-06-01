install_data(
    meson.project_name() + '.svg',
    install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', 'scalable', 'apps')
)

install_data(
    meson.project_name() + '.gschema.xml',
    install_dir: join_paths(get_option('prefix'), get_option('datadir'), 'glib-2.0', 'schemas')
)

i18n.merge_file(
    input: meson.project_name() + '.desktop.in',
    output: meson.project_name() + '.desktop',
    po_dir: join_paths(meson.source_root(), 'po'),
    type: 'desktop',
    install: true,
    install_dir: join_paths(get_option('datadir'), 'applications')
)

i18n.merge_file(
    input: meson.project_name() + '.appdata.xml.in',
    output: meson.project_name() + '.appdata.xml',
    po_dir: join_paths(meson.source_root(), 'po'),
    install: true,
    install_dir: join_paths(get_option('datadir'), 'metainfo')
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
