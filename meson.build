project('com.github.tkashkin.gamehub', 'vala', 'c', version: '0.2.1')

i18n = import('i18n')
gnome = import('gnome')

add_global_arguments('-g', language: 'vala')
add_global_arguments('-X', language: 'vala')
add_global_arguments('-rdynamic', language: 'vala')
add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()), language: 'c')

subdir('data')
subdir('src')
subdir('po')

meson.add_install_script('meson/post_install.py')
