using Gtk;
using Gdk;
using Gee;
using Granite;

using GameHub.Data;
using GameHub.Data.Sources.Steam;

using GameHub.Utils;

namespace GameHub.UI.Views.GameDetailsView.Blocks
{
	public class SteamDetails: GameDetailsBlock
	{
		public SteamDetails(Game game)
		{
			Object(game: game, orientation: Orientation.VERTICAL);
		}

		construct
		{
			if(!supports_game) return;

			var root = Parser.parse_json(game.info_detailed).get_object();
			var app = root.has_member(game.id) ? root.get_object_member(game.id) : null;
			var data = app != null && app.has_member("data") ? app.get_object_member("data") : null;
			if(data != null)
			{
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
					add_info_label(categories_label, categories_string, false, true);
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
					add_info_label(genres_label, genres_string, false, true);
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
					add_info_label(langs_label, langs, false, true);
				}
			}
		}

		public override bool supports_game { get { return (game is SteamGame) && game.info_detailed != null && game.info_detailed.length > 0; } }
	}
}
