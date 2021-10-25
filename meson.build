project('gamehub', 'vala', 'c', version: '1.0.0', default_options: ['buildtype=debugoptimized'], meson_version: '>=0.59.0')

gh_name = 'gamehub'
gh_rdnn = 'com.github.tkashkin.gamehub'
gh_gettext_domain = gh_rdnn

gh_supported_platforms = {
	'linux': 'linux',
	'windows': 'windows',
	'cygwin': 'windows',
	'darwin': 'macos'
}

gh_target = target_machine.system()

if gh_target in gh_supported_platforms
	gh_target = gh_supported_platforms[gh_target]
	add_project_arguments('-D', 'OS_@0@'.format(gh_target.to_upper()), language: 'vala')
else
	error('Unsupported target OS:', gh_target)
endif

if gh_target == 'linux' and get_option('flatpak')
	add_project_arguments('-D', 'FLATPAK', language: 'vala')
endif

subdir('data')
subdir('res')
subdir('po')
subdir('src')

meson.add_install_script('build-aux/postinstall.py')
