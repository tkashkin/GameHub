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

		public TweaksList(Traits.Game.SupportsTweaks? game = null)
		{
			Object(game: game, show_border: false, expand: true);
		}

		construct
		{
			update();
		}

		public void update(CompatTool? compat_tool=null)
		{
			this.foreach(w => w.destroy());

			var tweaks = Tweak.load_tweaks_grouped(game == null);

			if(tweaks != null && tweaks.size > 0)
			{
				foreach(var group in tweaks.entries)
				{
					var tab = new TweakGroupTab(game, compat_tool, group.key ?? _("Ungrouped"), group.value);
					append_page(tab, new Label(tab.group));
				}
				show_tabs = tweaks.size > 1;
			}
			else
			{
				append_page(new AlertView(_("No tweaks"), _("No tweaks were found\nAdd your tweaks into one of the tweak directories"), "dialog-warning-symbolic"));
				show_tabs = false;
			}
		}

		private class TweakGroupTab: ScrolledWindow
		{
			public Traits.Game.SupportsTweaks? game { get; construct; default = null; }
			public CompatTool? compat_tool { get; construct; default = null; }
			public string? group { get; construct; default = null; }
			public HashMap<string, Tweak>? tweaks { get; construct; default = null; }

			public TweakGroupTab(Traits.Game.SupportsTweaks? game = null, CompatTool? compat_tool = null, string? group = null, HashMap<string, Tweak>? tweaks = null)
			{
				Object(game: game, compat_tool: compat_tool, group: group, tweaks: tweaks, hscrollbar_policy: PolicyType.NEVER, expand: true);
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
						if(game == null || tweak.is_applicable_to(game, compat_tool))
						{
							tweaks_list.add(new TweakRow(tweak, game));
						}
					}
				}

				tweaks_list.row_activated.connect(row => {
					var setting = row as ActivatableSetting;
					if(setting != null)
					{
						setting.setting_activated();
					}
				});

				show_all();
			}
		}
	}
}
