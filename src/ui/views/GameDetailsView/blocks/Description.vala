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
using GameHub.UI.Widgets;

using Gdk;
using Gee;

#if WEBKIT2GTK
using WebKit;
#endif

using GameHub.Data;
using GameHub.Data.Sources.Humble;

namespace GameHub.UI.Views.GameDetailsView.Blocks
{
	public class Description: GameDetailsBlock
	{
		#if WEBKIT2GTK
		private WebView description;
		#endif

		private const string CSS          = "body{overflow: hidden; font-size: 0.8em; margin: 7px; line-height: 1.4; %s} h1,h2,h3{line-height: 1.2;} ul{padding: 4px 0 4px 16px;} img{max-width: 100%; display: block;}";
		private const string CSS_COLORS   = "background: %s; color: %s;";
		private const string WRAPPER_HTML = "<html><body><div id=\"description\">%s</div><script>setInterval(function(){document.title = -1; document.title = document.getElementById('description').offsetHeight;},250);</script></body></html>";
		private string? current_colors;

		public Description(Game game, bool is_dialog)
		{
			Object(game: game, orientation: Orientation.VERTICAL, text_max_width: is_dialog ? 80 : -1);
		}

		construct
		{
			if(!supports_game) return;

			get_style_context().add_class(Gtk.STYLE_CLASS_BACKGROUND);

			#if WEBKIT2GTK
			description = new WebView();
			description.hexpand = true;
			description.vexpand = false;
			description.sensitive = false;
			description.get_settings().hardware_acceleration_policy = HardwareAccelerationPolicy.NEVER;

			update_colors();
			state_flags_changed.connect(() => update_colors());
			GameHub.Settings.UI.Appearance.instance.notify["dark-theme"].connect(() => update_colors());

			description.set_size_request(-1, -1);
			var desc = WRAPPER_HTML.printf(game.description);
			description.load_html(desc, null);
			description.notify["title"].connect(e => {
				description.set_size_request(-1, -1);
				var height = int.parse(description.title);
				description.set_size_request(-1, height + 8);
			});

			add(description);
			#endif

			show_all();
			if(parent != null) parent.queue_draw();
		}

		private void update_colors()
		{
			#if WEBKIT2GTK
			var colors = CSS_COLORS.printf(get_style_context().get_background_color(get_state_flags()).to_string(), get_style_context().get_color(get_state_flags()).to_string());
			if(colors != current_colors)
			{
				description.user_content_manager.remove_all_style_sheets();
				description.user_content_manager.add_style_sheet(new UserStyleSheet(CSS.printf(colors), UserContentInjectedFrames.TOP_FRAME, UserStyleLevel.USER, null, null));
				current_colors = colors;
			}
			#endif
		}

		public override bool supports_game { get { return game.description != null; } }
	}
}
