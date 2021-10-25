gh_config = [
	configure_file(
		input: 'Config.vala',
		output: '_Config.vala',
		configuration: {
			'RDNN': gh_rdnn,
			'VERSION': meson.project_version(),
			'PREFIX': get_option('prefix'),
			'DATADIR': get_option('prefix') / get_option('datadir'),
			'BINDIR': get_option('prefix') / get_option('bindir'),
			'LOCALEDIR': get_option('prefix') / get_option('localedir'),
			'GETTEXT_DOMAIN': gh_gettext_domain
		}
	)
]

if get_option('git_branch') == ''
	gh_config += vcs_tag(
		input: 'GitBranch.vala',
		output: '_GitBranch.vala',
		command: ['git', 'symbolic-ref', '--short', '-q', 'HEAD'],
		replace_string: '@GIT_BRANCH@',
		fallback: 'unknown'
	)
else
	gh_config += configure_file(
		input: 'GitBranch.vala',
		output: '_GitBranch.vala',
		configuration: {'GIT_BRANCH': get_option('git_branch')}
	)
endif

if get_option('git_commit') == ''
	gh_config += vcs_tag(
		input: 'GitCommit.vala',
		output: '_GitCommit.vala',
		command: ['git', 'rev-parse', 'HEAD'],
		replace_string: '@GIT_COMMIT@',
		fallback: 'unknown'
	)
else
	gh_config += configure_file(
		input: 'GitCommit.vala',
		output: '_GitCommit.vala',
		configuration: {'GIT_COMMIT': get_option('git_commit')}
	)
endif