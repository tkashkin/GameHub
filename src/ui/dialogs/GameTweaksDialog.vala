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

using GameHub.Data;
using GameHub.Data.DB;
using GameHub.Utils;
using GameHub.UI.Widgets;

namespace GameHub.UI.Dialogs
{
	public class GameTweaksDialog: Dialog
	{
		public TweakableGame? game { get; construct; }

		private Box content;
		private TweaksList tweaks_list;
		private ScrolledWindow tweaks_list_scroll;

		public GameTweaksDialog(TweakableGame? game)
		{
			Object(transient_for: Windows.MainWindow.instance, resizable: false, title: _("%s: Tweaks").printf(game.name), game: game);
		}

		construct
		{
			get_style_context().add_class("rounded");
			get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);

			gravity = Gdk.Gravity.NORTH;

			content = new Box(Orientation.VERTICAL, 0);
			content.margin_start = content.margin_end = 6;

			var tweaks_header = Styled.H4Label(_("Tweaks"));
			tweaks_header.xpad = 8;
			content.add(tweaks_header);

			tweaks_list = new TweaksList(game);
			tweaks_list.get_style_context().add_class("separated-list");
			tweaks_list.hexpand = false;

			tweaks_list_scroll = new ScrolledWindow(null, null);
			tweaks_list_scroll.get_style_context().add_class(Gtk.STYLE_CLASS_FRAME);
			tweaks_list_scroll.hscrollbar_policy = PolicyType.NEVER;
			tweaks_list_scroll.vexpand = true;
			#if GTK_3_22
			tweaks_list_scroll.propagate_natural_width = true;
			tweaks_list_scroll.propagate_natural_height = true;
			tweaks_list_scroll.max_content_height = 520;
			#endif
			tweaks_list_scroll.add(tweaks_list);

			content.add(tweaks_list_scroll);

			get_content_area().add(content);
			get_content_area().set_size_request(480, -1);

			show_all();
		}
	}
}
