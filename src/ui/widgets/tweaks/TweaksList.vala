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
using Gdk;
using Gee;

using GameHub.UI.Widgets;
using GameHub.UI.Widgets.Settings;

using GameHub.Data;
using GameHub.Data.Tweaks;
using GameHub.Data.Runnables;

namespace GameHub.UI.Widgets.Tweaks
{
	public class TweaksList: Notebook
	{
		public Traits.Game.SupportsTweaks? game { get; construct; default = null; }
		public TweakSet tweakset { get; construct; }

		private Button reset_button;

		public TweaksList(Traits.Game.SupportsTweaks? game = null)
		{
			Object(game: game, tweakset: game == null ? GameHub.Settings.Tweaks.global_tweakset : game.tweaks, show_border: false, expand: true, scrollable: true);
		}

		construct
		{
			reset_button = new Button.from_icon_name("edit-delete-symbolic", IconSize.SMALL_TOOLBAR);
			reset_button.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
			reset_button.valign = Align.CENTER;
			reset_button.tooltip_markup = """<span weight="600" size="smaller" alpha="75%">%s</span>%s%s""".printf(
				_("Reset to default"), "\n",
				tweakset.is_global
					? _("Disable all tweaks and reset all options globally\nOptions set for specific games will be kept")
					: _("Remove all tweaks and options set for the game and use global options")
			);
			reset_button.clicked.connect(reset);
			reset_button.show();
			set_action_widget(reset_button, PackType.END);
			update();
		}

		private void update(CompatTool? compat_tool=null)
		{
			this.foreach(w => w.destroy());

			var tweaks = Tweak.load_tweaks_grouped(t => tweakset.is_global || t.is_applicable_to(game, compat_tool));

			if(tweaks != null && tweaks.size > 0)
			{
				var tab_names = new ArrayList<string?>();
				tab_names.add_all(tweaks.keys);
				tab_names.sort((first, second) => {
					if(first == null && second == null) return 0;
					if(first != null && second == null) return -1;
					if(first == null && second != null) return 1;
					return first.collate(second);
				});

				foreach(var tab_name in tab_names)
				{
					var tab = new TweakGroupTab(tweakset, tab_name ?? _("Ungrouped"), tweaks[tab_name]);
					append_page(tab, new Label(tab.group));
				}
				show_tabs = true;
			}
			else
			{
				append_page(new AlertView(_("No tweaks"), _("No tweaks were found\nAdd your tweaks into one of the tweak directories"), "dialog-warning-symbolic"));
				show_tabs = false;
			}
		}

		private void reset()
		{
			var current_tab = page;
			tweakset.reset();
			update();
			page = current_tab;
		}

		private class TweakGroupTab: ScrolledWindow
		{
			public TweakSet tweakset { get; construct; }
			public string? group { get; construct; default = null; }
			public HashMap<string, Tweak>? tweaks { get; construct; default = null; }

			public TweakGroupTab(TweakSet tweakset, string? group = null, HashMap<string, Tweak>? tweaks = null)
			{
				Object(tweakset: tweakset, group: group, tweaks: tweaks, hscrollbar_policy: PolicyType.NEVER, expand: true);
			}

			construct
			{
				var tweaks_list = new ListBox();
				tweaks_list.selection_mode = SelectionMode.NONE;
				child = tweaks_list;

				if(tweaks != null)
				{
					foreach(var tweak in tweaks.values)
					{
						tweaks_list.add(new TweakRow(tweak, tweakset));
					}
				}

				tweaks_list.row_activated.connect(row => {
					var setting = row as ActivatableSetting;
					if(setting != null)
					{
						setting.setting_activated();
					}
				});

				tweaks_list.set_sort_func((r1, r2) => {
					var first = (TweakRow) r1;
					var second = (TweakRow) r2;
					if(first.is_available && !second.is_available) return -1;
					if(!first.is_available && second.is_available) return 1;
					return first.tweak.name.collate(second.tweak.name);
				});
				tweaks_list.invalidate_sort();

				show_all();
			}
		}
	}
}
