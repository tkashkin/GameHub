/*
This file is part of GameHub.
Copyright (C) Anatoliy Kashkin

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
using GameHub.Data.Compat;
using GameHub.Data.Runnables;

using GameHub.Utils;
using GameHub.Utils.FS;

using GameHub.UI.Widgets;
using GameHub.UI.Widgets.Compat;
using GameHub.UI.Widgets.Settings;

namespace GameHub.UI.Dialogs.GamePropertiesDialog.Tabs
{
	private class Compat: GamePropertiesDialogTab
	{
		public Traits.SupportsCompatTools game { get; construct; }

		public Compat(Traits.SupportsCompatTools game)
		{
			Object(
				game: game,
				title: _("Compatibility layers"),
				orientation: Orientation.VERTICAL
			);
		}

		construct
		{
			if(!game.needs_compat)
			{
				var sgrp_compat_force = new SettingsGroup();
				sgrp_compat_force.add_setting(
					new SwitchSetting.bind(
						_("Force compatibility layers"),
						_("Enable compatibility layers for this game even if it's native"),
						game, "force-compat"
					)
				);
				add(sgrp_compat_force);
			}

			var sgrp_compat = new SettingsGroupBox();
			sgrp_compat.container.get_style_context().remove_class(Gtk.STYLE_CLASS_VIEW);
			var compat_tools_list = sgrp_compat.add_widget(new CompatToolsList(game));
			add(sgrp_compat);

			compat_tools_list.compat_tool_selected.connect(tool => {
				tool.cast<CompatToolTraits.Run>(tool => {
					game.compat_tool = tool.full_id;
					game.save();
				});
			});

			sgrp_compat.sensitive = game.use_compat;
			game.notify["use-compat"].connect(() => sgrp_compat.sensitive = game.use_compat);
		}
	}
}
