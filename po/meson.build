import('i18n').gettext(
	gh_gettext_domain,
	args: ['--directory=' + meson.project_source_root(), '--from-code=UTF-8'],
	preset: 'glib'
)
add_project_arguments('-DGETTEXT_PACKAGE="@0@"'.format(gh_gettext_domain), language: 'c')