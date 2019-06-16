/*
This file is part of GameHub.
Copyright (C) 2018-2019 Anatoliy Kashkin

GameHub is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

GameHub is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with GameHub.  If not, see <https://www.gnu.org/licenses/>.
*/

using Gtk;
using Granite;
using GameHub.Utils;

namespace GameHub.UI.Dialogs.SettingsDialog.Pages
{
	public class About: SettingsPage
	{
		private Settings.UI.Appearance ui_settings;

		private Box links_view;
		private Box small_links_view;

		public About(SettingsDialog dlg)
		{
			Object(
				header: _("About"),
				title: "GameHub",
				status: ProjectConfig.VERSION,
				icon_name: ProjectConfig.PROJECT_NAME
			);
		}

		construct
		{
			ui_settings = Settings.UI.Appearance.instance;

			var content_vbox = new Box(Orientation.VERTICAL, 8);
			content_vbox.expand = true;

			var content_hbox = new Box(Orientation.HORIZONTAL, 0);
			content_hbox.margin = 12;

			var logo = new Image.from_icon_name(ProjectConfig.PROJECT_NAME, IconSize.DIALOG);
			logo.valign = Align.START;

			var appinfo_grid = new Grid();
			appinfo_grid.margin_start = 12;
			appinfo_grid.row_spacing = 0;
			appinfo_grid.column_spacing = 8;

			var app_title = new Label("GameHub");
			app_title.hexpand = true;
			app_title.xalign = 0;
			app_title.get_style_context().add_class(Granite.STYLE_CLASS_H2_LABEL);

			var app_version = new Label(ProjectConfig.VERSION);
			app_version.hexpand = true;
			app_version.xalign = 0;
			app_version.get_style_context().add_class(Gtk.STYLE_CLASS_DIM_LABEL);

			var app_info_copy = new Button.from_icon_name("edit-copy-symbolic", IconSize.BUTTON);
			app_info_copy.tooltip_text = _("Copy application version and environment info");
			app_info_copy.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
			app_info_copy.set_size_request(36, 36);
			app_info_copy.halign = app_info_copy.valign = Align.CENTER;

			app_info_copy.clicked.connect(copy_app_info);

			var app_subtitle = new Label(_("All your games in one place"));
			app_subtitle.margin_top = 4;
			app_subtitle.hexpand = true;
			app_subtitle.xalign = 0;
			app_subtitle.get_style_context().add_class(Granite.STYLE_CLASS_H3_LABEL);

			appinfo_grid.attach(app_title, 0, 0);
			appinfo_grid.attach(app_version, 0, 1);
			appinfo_grid.attach(app_info_copy, 1, 0, 1, 2);
			appinfo_grid.attach(app_subtitle, 0, 2);

			links_view = new Box(Orientation.VERTICAL, 2);
			links_view.expand = true;
			links_view.margin = 4;

			add_link(C_("about_link", "Website"), "https://tkashkin.tk/projects/gamehub", "web-browser");
			add_link(C_("about_link", "Source code on GitHub"), "https://github.com/tkashkin/GameHub", "text-x-script");
			add_link(C_("about_link", "Report a problem"), "https://github.com/tkashkin/GameHub/issues/new/choose", "dialog-warning");
			add_link(C_("about_link", "Suggest translations"), "https://hosted.weblate.org/engage/gamehub", "preferences-desktop-locale");

			small_links_view = new Box(Orientation.HORIZONTAL, 8);
			small_links_view.margin = 8;
			small_links_view.halign = Align.END;

			add_small_link(C_("about_link", "Issues"), "https://github.com/tkashkin/GameHub/issues");
			add_small_link(C_("about_link", "Contributors"), "https://github.com/tkashkin/GameHub/graphs/contributors");

			// TRANSLATORS: Likely it should not be translated. GitHub Pulse is a page that shows recent repository activity: https://github.com/tkashkin/GameHub/pulse
			add_small_link(C_("about_link", "Pulse"), "https://github.com/tkashkin/GameHub/pulse");
			add_small_link(C_("about_link", "Forks"), "https://github.com/tkashkin/GameHub/network");

			content_hbox.add(logo);
			content_hbox.add(appinfo_grid);

			content_vbox.add(content_hbox);
			content_vbox.add(links_view);
			content_vbox.add(small_links_view);

			add(content_vbox);
		}

		private void copy_app_info()
		{
			var info = "Version: %s\n".printf(ProjectConfig.VERSION) +
			           "Branch:  %s\n".printf(ProjectConfig.GIT_BRANCH) +
			           "Commit:  %s (%s)\n".printf(ProjectConfig.GIT_COMMIT_SHORT, ProjectConfig.GIT_COMMIT) +
			           "Distro:  %s\n".printf(Utils.get_distro()) +
			           "DE:      %s".printf(Utils.get_desktop_environment() ?? "unknown");

			Clipboard.get_default(Gdk.Display.get_default()).set_text(info, info.length);
		}

		private void add_link(string title, string url, string icon="web-browser")
		{
			var button = new GameHub.UI.Widgets.ActionButton(icon + Settings.UI.Appearance.symbolic_icon_suffix, null, title, true, ui_settings.icon_style.is_symbolic());
			button.tooltip_text = url;

			button.clicked.connect(() => {
				Utils.open_uri(url);
			});

			ui_settings.notify["icon-style"].connect(() => {
				button.icon = icon + Settings.UI.Appearance.symbolic_icon_suffix;
				button.compact = ui_settings.icon_style.is_symbolic();
			});

			links_view.add(button);
		}

		private void add_small_link(string title, string url)
		{
			small_links_view.add(new LinkButton.with_label(url, title));
		}
	}
}
