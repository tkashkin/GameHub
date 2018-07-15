project('com.github.tkashkin.gamehub', 'vala', 'c', version: '0.5.3')

i18n = import('i18n')
gnome = import('gnome')

add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()), language: 'c')

if get_option('use_ivy')
	add_global_arguments('-g', '-X', '-rdynamic', '-D', 'USE_IVY', language: 'vala')
endif

if get_option('flatpak')
	add_global_arguments('-D', 'FLATPAK', language: 'vala')
endif

subdir('data')
subdir('src')
subdir('po')

meson.add_install_script('meson/post_install.py')
