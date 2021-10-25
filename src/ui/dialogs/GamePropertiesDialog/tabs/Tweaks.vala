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
using GameHub.Data.Runnables;

using GameHub.Utils;
using GameHub.Utils.FS;

using GameHub.UI.Widgets;
using GameHub.UI.Widgets.Tweaks;
using GameHub.UI.Widgets.Settings;

namespace GameHub.UI.Dialogs.GamePropertiesDialog.Tabs
{
	private class Tweaks: GamePropertiesDialogTab
	{
		public Traits.Game.SupportsTweaks game { get; construct; }

		public Tweaks(Traits.Game.SupportsTweaks game)
		{
			Object(
				game: game,
				title: _("Tweaks"),
				orientation: Orientation.VERTICAL
			);
		}

		construct
		{
			var sgrp_tweaks = new SettingsGroupBox();
			sgrp_tweaks.container.get_style_context().remove_class(Gtk.STYLE_CLASS_VIEW);
			sgrp_tweaks.add_widget(new TweaksList(game));
			add(sgrp_tweaks);
		}
	}
}
