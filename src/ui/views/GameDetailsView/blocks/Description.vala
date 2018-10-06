/*
This file is part of GameHub.
Copyright (C) 2018 Anatoliy Kashkin

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
using Granite;
using WebKit;

using GameHub.Data;
using GameHub.Data.Sources.Humble;

namespace GameHub.UI.Views.GameDetailsView.Blocks
{
	public class Description: GameDetailsBlock
	{
		private Granite.HeaderLabel description_header;
		private WebView description;

		private const string CSS_LIGHT = "background: rgb(245, 245, 245); color: rgb(66, 66, 66)";
		private const string CSS_DARK = "background: rgb(59, 63, 69); color: white";

		public Description(Game game, bool is_dialog)
		{
			Object(game: game, orientation: Orientation.VERTICAL, is_dialog: is_dialog);
		}

		construct
		{
			if(!supports_game) return;

			description_header = new Granite.HeaderLabel(_("Description"));
			description_header.margin_start = description_header.margin_end = 7;
			description_header.get_style_context().add_class("description-header");

			description = new WebView();
			description.hexpand = true;
			description.vexpand = false;
			description.sensitive = false;
			description.get_settings().hardware_acceleration_policy = HardwareAccelerationPolicy.NEVER;

			var ui_settings = GameHub.Settings.UI.get_instance();
			ui_settings.notify["dark-theme"].connect(() => {
				description.user_content_manager.remove_all_style_sheets();
				var style = ui_settings.dark_theme ? CSS_DARK : CSS_LIGHT;
				description.user_content_manager.add_style_sheet(new UserStyleSheet(@"body{overflow: hidden; font-size: 0.8em; margin: 7px; line-height: 1.4; $(style)} h1,h2,h3{line-height: 1.2;} ul{padding: 4px 0 4px 16px;} img{max-width: 100%; display: block;}", UserContentInjectedFrames.TOP_FRAME, UserStyleLevel.USER, null, null));
			});
			ui_settings.notify_property("dark-theme");

			description.set_size_request(-1, -1);
			var desc = game.description + "<script>setInterval(function(){document.title = -1; document.title = document.documentElement.clientHeight;},250);</script>";
			description.load_html(desc, null);
			description.notify["title"].connect(e => {
				description.set_size_request(-1, -1);
				var height = int.parse(description.title);
				description.set_size_request(-1, height);
			});

			add(description_header);
			add(description);
		}

		public override bool supports_game { get { return game.description != null; } }
	}
}
