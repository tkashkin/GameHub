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
using GameHub.Data.Sources.Steam;

using GameHub.Utils;

using GameHub.UI.Widgets;

namespace GameHub.UI.Views.GameDetailsView.Blocks
{
	public class SteamDetails: GameDetailsBlock
	{
		public SteamDetails(Game game)
		{
			Object(game: game, orientation: Orientation.VERTICAL, text_max_width: 48);
		}

		construct
		{
			if(!supports_game) return;

			var root = Parser.parse_json(game.info_detailed).get_object();
			var app = root.has_member(game.id) ? root.get_object_member(game.id) : null;
			var data = app != null && app.has_member("data") ? app.get_object_member("data") : null;
			if(data == null) return;

			get_style_context().add_class("gameinfo-sidebar-block");

			var link = new ActionButton(game.source.icon, null, "Steam", true, true);
			if(game.store_page != null)
			{
				link.tooltip_text = game.store_page;
				link.clicked.connect(() => {
					try
					{
						Utils.open_uri(game.store_page);
					}
					catch(Utils.RunError error)
					{
						//FIXME [DEV-ART]: Replace this with inline error display?
						GameHub.UI.Dialogs.QuickErrorDialog.display_and_log.begin(
							this, error, Log.METHOD,
							_("Opening website “%s” failed").printf(game.store_page)
						);
					}
				});
			}

			add(link);

			var categories = data.has_member("categories") ? data.get_array_member("categories") : null;
			if(categories != null)
			{
				var categories_string = "";
				foreach(var c in categories.get_elements())
				{
					var cat = c.get_object().get_string_member("description");
					categories_string += (categories_string.length > 0 ? ", " : "") + cat;
				}

				var categories_label = _("Category");
				if(categories_string.contains(","))
				{
					categories_label = _("Categories");
				}
				add(new Separator(Orientation.HORIZONTAL));
				add_info_label(categories_label, categories_string, categories_string.contains(","), true);
			}

			var genres = data.has_member("genres") ? data.get_array_member("genres") : null;
			if(genres != null)
			{
				var genres_string = "";
				foreach(var g in genres.get_elements())
				{
					var genre = g.get_object().get_string_member("description");
					genres_string += (genres_string.length > 0 ? ", " : "") + genre;
				}

				var genres_label = _("Genre");
				if(genres_string.contains(","))
				{
					genres_label = _("Genres");
				}
				add(new Separator(Orientation.HORIZONTAL));
				add_info_label(genres_label, genres_string, genres_string.contains(","), true);
			}

			var langs = data.has_member("supported_languages") ? data.get_string_member("supported_languages") : null;
			if(langs != null)
			{
				langs = langs.split("<br><strong>*</strong>")[0].replace("strong>", "b>");
				var langs_label = _("Language");
				if(langs.contains(","))
				{
					langs_label = _("Languages");
				}
				add(new Separator(Orientation.HORIZONTAL));
				add_info_label(langs_label, langs, langs.contains(","), true);
			}

			show_all();
			if(parent != null) parent.queue_draw();
		}

		public override bool supports_game { get { return (game is SteamGame) && game.info_detailed != null && game.info_detailed.length > 0; } }
	}
}
