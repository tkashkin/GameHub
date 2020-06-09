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

using GameHub.Data;
using GameHub.Utils;
using GameHub.UI.Widgets;

namespace GameHub.UI.Dialogs.SettingsDialog.Pages.General
{
	public class Tweaks: SettingsDialogPage
	{
		public Tweaks(SettingsDialog dlg)
		{
			Object(
				dialog: dlg,
				title: _("Tweaks"),
				description: _("Tweak launch options and apply them to games automatically"),
				icon_name: "system-run"
			);
			status = description;
		}

		construct
		{
			root_grid.margin = 0;
			header_grid.margin = 12;
			header_grid.margin_bottom = 0;
			content_area.margin = 0;

			var header = add_header(_("Tweaks"));
			header.margin_start = header.margin_end = 12;

			var tweaks_list_scroll = add_widget(new ScrolledWindow(null, null));
			tweaks_list_scroll.get_style_context().add_class(Gtk.STYLE_CLASS_FRAME);
			tweaks_list_scroll.hscrollbar_policy = PolicyType.NEVER;

			tweaks_list_scroll.margin_start = 7;
			tweaks_list_scroll.margin_end = 3;
			tweaks_list_scroll.margin_top = 0;
			tweaks_list_scroll.margin_bottom = 6;

			var tweaks_list = new TweaksList();
			tweaks_list.get_style_context().add_class("separated-list");

			tweaks_list_scroll.add(tweaks_list);

			#if GTK_3_22
			tweaks_list_scroll.propagate_natural_width = true;
			tweaks_list_scroll.propagate_natural_height = true;
			#else
			tweaks_list_scroll.expand = true;
			#endif

			add_dirs_info();
		}

		private void add_dirs_info()
		{
			var dirs = FSUtils.get_data_dirs("tweaks", true);
			var last_dir = dirs.last();

			var dirs_tooltip = """<span size="smaller" weight="600">%s</span>""".printf(_("Tweaks are loaded from following directories in order\nLast tweak overrides previous tweaks with same identifiers")) + "\n";
			foreach(var dir in dirs)
			{
				if(dir == last_dir)
					dirs_tooltip += "\n• <b>%s</b> (%s)".printf(dir.get_path(), _("Click to open"));
				else
					dirs_tooltip += "\n• %s".printf(dir.get_path());
			}

			var dirs_btn = new Button();
			dirs_btn.hexpand = true;
			dirs_btn.tooltip_markup = dirs_tooltip;
			StyleClass.add(dirs_btn, Gtk.STYLE_CLASS_FLAT);

			var dirs_btn_label = new Label(_("Tweaks are loaded from <b>%1$s</b> and %2$d more directories <b>(?)</b>").printf(last_dir.get_path(), dirs.size - 1));
			dirs_btn_label.wrap = true;
			dirs_btn_label.xalign = 0;
			dirs_btn_label.use_markup = true;

			dirs_btn.add(dirs_btn_label);

			dirs_btn.clicked.connect(() => {
				try
				{
					Utils.open_uri(last_dir.get_uri());
				}
				catch(Utils.RunError error)
				{
					//FIXME [DEV-ART]: Replace this with inline error display?
					GameHub.UI.Dialogs.QuickErrorDialog.display_and_log.begin(
						this, error, Log.METHOD,
						_("Opening directory “%s” failed").printf(last_dir.get_path())
					);
				}
			});

			add_widget(dirs_btn);
		}
	}
}
