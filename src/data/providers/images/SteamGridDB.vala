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

using Gee;

using GameHub.Data.Runnables;
using GameHub.Utils;

namespace GameHub.Data.Providers.Images
{
	public class SteamGridDB: ImagesProvider
	{
		private const string DOMAIN       = "https://steamgriddb.com";
		private const string BASE_URL     = DOMAIN + "/api/v2";
		private const string API_KEY_PAGE = DOMAIN + "/profile/preferences";

		private ImagesProvider.ImageSize?[] SIZES = { null, ImageSize(460, 215), ImageSize(920, 430), ImageSize(600, 900), ImageSize(342, 482), ImageSize(660, 930), ImageSize(512, 512), ImageSize(1024, 1024) };

		public override string id   { get { return "steamgriddb"; } }
		public override string name { get { return "SteamGridDB"; } }
		public override string url  { get { return DOMAIN; } }
		public override string icon { get { return "provider-images-steamgriddb"; } }

		public override bool enabled
		{
			get { return Settings.Providers.Images.SteamGridDB.instance.enabled; }
			set { Settings.Providers.Images.SteamGridDB.instance.enabled = value; }
		}

		public enum FilterHumor
		{
			TRUE, FALSE, ANY;

			public string value()
			{
				switch (this)
				{
					case FilterHumor.TRUE:  return "true";
					case FilterHumor.FALSE: return "false";
					case FilterHumor.ANY:   return "any";
				}
				assert_not_reached();
			}

			public static FilterHumor from_string(string setting)
			{
				switch (setting)
				{
					case "true":  return FilterHumor.TRUE;
					case "false": return FilterHumor.FALSE;
					case "any":   return FilterHumor.ANY;
				}
				assert_not_reached();
			}

			public string name()
			{
				switch(this)
				{
					case FilterHumor.TRUE:  return C_("imagesource_steamgriddb_image_filter", "True");
					case FilterHumor.FALSE: return C_("imagesource_steamgriddb_image_filter", "False");
					case FilterHumor.ANY:   return C_("imagesource_steamgriddb_image_filter", "Any");
				}
				assert_not_reached();
			}
		}

		public enum FilterNsfw
		{
			TRUE, FALSE, ANY;

			public string value()
			{
				switch (this)
				{
					case FilterNsfw.TRUE:  return "true";
					case FilterNsfw.FALSE: return "false";
					case FilterNsfw.ANY:   return "any";
				}
				assert_not_reached();
			}

			public static FilterNsfw from_string(string setting)
			{
				switch (setting)
				{
					case "true":  return FilterNsfw.TRUE;
					case "false": return FilterNsfw.FALSE;
					case "any":   return FilterNsfw.ANY;
				}
				assert_not_reached();
			}

			public string name()
			{
				switch(this)
				{
					case FilterNsfw.TRUE:  return C_("imagesource_steamgriddb_image_filter", "True");
					case FilterNsfw.FALSE: return C_("imagesource_steamgriddb_image_filter", "False");
					case FilterNsfw.ANY:   return C_("imagesource_steamgriddb_image_filter", "Any");
				}
				assert_not_reached();
			}
		}

		public override async ArrayList<ImagesProvider.Result> images(Game game)
		{
			var results = new ArrayList<ImagesProvider.Result>();

			ArrayList<SGDBGame>? games;
			if(game is GameHub.Data.Sources.Steam.SteamGame)
			{
				games = yield games_by_steam_appid(game.id);
			}
			else
			{
				games = yield games_by_name(game.name);
			}

			if(games != null && games.size > 0)
			{
				foreach(var g in games)
				{
					foreach(var size in SIZES)
					{
						results.add(new Result(this, g, size));
					}
				}
			}

			return results;
		}

		private async ArrayList<SGDBGame>? games_by_name(string name)
		{
			var root = yield Parser.parse_remote_json_file_async(BASE_URL + "/search/autocomplete/" + Uri.escape_string(name), "GET", Settings.Providers.Images.SteamGridDB.instance.api_key);
			if(root == null || root.get_node_type() != Json.NodeType.OBJECT) return null;
			var obj = root.get_object();
			var data = obj.has_member("data") ? obj.get_array_member("data") : null;
			if(data == null || data.get_length() < 1) return null;

			var games = new ArrayList<SGDBGame>();
			foreach(var item_node in data.get_elements())
			{
				var item = item_node != null && item_node.get_node_type() == Json.NodeType.OBJECT ? item_node.get_object() : null;
				if(item == null || !item.has_member("id") || !item.has_member("name")) continue;
				games.add(new SGDBGame(item));
			}
			return games;
		}

		private async ArrayList<SGDBGame>? games_by_steam_appid(string appid)
		{
			var root = yield Parser.parse_remote_json_file_async(BASE_URL + "/games/steam/" + appid, "GET", Settings.Providers.Images.SteamGridDB.instance.api_key);
			if(root == null || root.get_node_type() != Json.NodeType.OBJECT) return null;
			var obj = root.get_object();
			var data = obj.has_member("data") ? obj.get_object_member("data") : null;
			if(data == null || !data.has_member("id") || !data.has_member("name")) return null;

			var games = new ArrayList<SGDBGame>();
			games.add(new SGDBGame(data));
			return games;
		}

		public class SGDBGame
		{
			public string id;
			public string name;
			public SGDBGame(Json.Object game)
			{
				id = game.get_int_member("id").to_string();
				name = game.get_string_member("name");
			}
		}

		public override Gtk.Widget? settings_widget
		{
			owned get
			{
				var settings = Settings.Providers.Images.SteamGridDB.instance;

				var grid = new Gtk.Grid();
				grid.column_spacing = 12;
				grid.row_spacing = 4;

				var entry = new Gtk.Entry();
				entry.placeholder_text = _("Default");
				entry.max_length = 32;
				if(settings.api_key != settings.schema.get_default_value("api-key").get_string())
				{
					entry.text = settings.api_key;
				}
				entry.secondary_icon_name = "edit-delete-symbolic";
				entry.secondary_icon_tooltip_text = _("Restore default API key");
				entry.set_size_request(250, -1);

				entry.notify["text"].connect(() => { settings.api_key = entry.text; });
				entry.icon_press.connect((pos, e) => {
					if(pos == Gtk.EntryIconPosition.SECONDARY)
					{
						entry.text = "";
					}
				});

				var label = new Gtk.Label(_("API key"));
				label.halign = Gtk.Align.START;
				label.valign = Gtk.Align.CENTER;
				label.hexpand = true;

				var entry_wrapper = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
				entry_wrapper.get_style_context().add_class(Gtk.STYLE_CLASS_LINKED);

				var link = new Gtk.Button.with_label(_("Generate key"));
				link.tooltip_text = API_KEY_PAGE;

				link.clicked.connect(() => {
					Utils.open_uri(API_KEY_PAGE);
				});

				entry_wrapper.add(entry);
				entry_wrapper.add(link);

				grid.attach(label, 0, 0);
				grid.attach(entry_wrapper, 1, 0);

				var label_filter_humor = new Gtk.Label(_("Humoristic images"));
				label_filter_humor.halign = Gtk.Align.START;
				label_filter_humor.valign = Gtk.Align.CENTER;
				label_filter_humor.hexpand = true;

				var combo_filter_humor = new Gtk.ComboBoxText();
				combo_filter_humor.halign = Gtk.Align.END;
				combo_filter_humor.valign = Gtk.Align.CENTER;
				combo_filter_humor.hexpand = false;
				combo_filter_humor.append(FilterHumor.TRUE.value(), FilterHumor.TRUE.name());
				combo_filter_humor.append(FilterHumor.FALSE.value(), FilterHumor.FALSE.name());
				combo_filter_humor.append(FilterHumor.ANY.value(), FilterHumor.ANY.name());
				combo_filter_humor.set_active_id(FilterHumor.from_string(settings.filter_humor).value());
				combo_filter_humor.changed.connect(() => { settings.filter_humor = combo_filter_humor.get_active_id(); });

				grid.attach(label_filter_humor, 0, 1);
				grid.attach(combo_filter_humor, 1, 1);

				var label_filter_nsfw = new Gtk.Label(_("NSFW images"));
				label_filter_nsfw.halign = Gtk.Align.START;
				label_filter_nsfw.valign = Gtk.Align.CENTER;
				label_filter_nsfw.hexpand = true;

				var combo_filter_nsfw = new Gtk.ComboBoxText();
				combo_filter_nsfw.halign = Gtk.Align.END;
				combo_filter_nsfw.valign = Gtk.Align.CENTER;
				combo_filter_nsfw.hexpand = false;
				combo_filter_nsfw.append(FilterNsfw.TRUE.value(), FilterNsfw.TRUE.name());
				combo_filter_nsfw.append(FilterNsfw.FALSE.value(), FilterNsfw.FALSE.name());
				combo_filter_nsfw.append(FilterNsfw.ANY.value(), FilterNsfw.ANY.name());
				combo_filter_nsfw.set_active_id(FilterNsfw.from_string(settings.filter_nsfw).value());
				combo_filter_nsfw.changed.connect(() => { settings.filter_nsfw = combo_filter_nsfw.get_active_id(); });

				grid.attach(label_filter_nsfw, 0, 2);
				grid.attach(combo_filter_nsfw, 1, 2);

				return grid;
			}
		}

		public class Result: ImagesProvider.Result
		{
			private SGDBGame game;
			private string dimensions;
			private string filter_humor;
			private string filter_nsfw;
			private string types = "&types=static"; // GameHub can't display apng anyway.
			private ArrayList<ImagesProvider.Image>? images = null;

			public Result(SteamGridDB source, SGDBGame game, ImagesProvider.ImageSize? size)
			{
				this.game = game;
				provider = source;
				image_size = size ?? ImageSize(460, 215);
				name = "%s: %s (%d × %d)".printf(source.name, game.name, image_size.width, image_size.height);
				title = "%s: %d × %d".printf(source.name, image_size.width, image_size.height);
				subtitle = game.name;
				url = "%s/game/%s".printf(SteamGridDB.DOMAIN, game.id);
				dimensions = size != null ? "&dimensions=%dx%d".printf(size.width, size.height) : "";
				filter_humor = "?humor=%s".printf(Settings.Providers.Images.SteamGridDB.instance.filter_humor);
				filter_nsfw = "&nsfw=%s".printf(Settings.Providers.Images.SteamGridDB.instance.filter_nsfw);
			}

			public override async ArrayList<ImagesProvider.Image>? load_images()
			{
				if(images != null) return images;

				var endpoint = "/grids/game/%s%s%s%s%s".printf(game.id, filter_humor, filter_nsfw, types, dimensions);

				var root = yield Parser.parse_remote_json_file_async(SteamGridDB.BASE_URL + endpoint, "GET", Settings.Providers.Images.SteamGridDB.instance.api_key);
				if(root == null || root.get_node_type() != Json.NodeType.OBJECT) return images;
				var obj = root.get_object();
				var data = obj.has_member("data") ? obj.get_array_member("data") : null;
				if(data == null || data.get_length() < 1) return images;

				images = new ArrayList<ImagesProvider.Image>();
				foreach(var img_node in data.get_elements())
				{
					var img = img_node != null && img_node.get_node_type() == Json.NodeType.OBJECT ? img_node.get_object() : null;
					if(img == null || !img.has_member("url")) continue;
					images.add(new Image(img));
				}

				return images;
			}
		}

		public class Image: ImagesProvider.Image
		{
			public string  raw_style { get; protected construct set; }
			public Style?  style     { get; protected construct set; default = null; }
			public int     score     { get; protected construct set; default = 0; }
			public string? author    { get; protected construct set; default = null; }

			public Image(Json.Object obj)
			{
				Object(url: obj.get_string_member("url"), raw_style: obj.get_string_member("style"));
				style = Style.from_string(raw_style);
				author = obj.has_member("author") ? obj.get_object_member("author").get_string_member("name") : null;
				score = obj.has_member("score") ? (int) obj.get_int_member("score") : 0;

				description = """<span weight="600">%s</span>: %s""".printf(C_("imagesource_steamgriddb_image_property", "Style"), style == null ? raw_style : style.name()) + "\n"
				            + """<span weight="600">%s</span>: %d""".printf(C_("imagesource_steamgriddb_image_property", "Score"), score);

				if(author != null)
				{
					description += "\n" + """<span weight="600">%s</span>: %s""".printf(C_("imagesource_steamgriddb_image_property", "Author"), author);
				}
			}

			public enum Style
			{
				ALTERNATE, BLURRED, MATERIAL, NO_LOGO, WHITE_LOGO;

				public string name()
				{
					switch(this)
					{
						case Style.ALTERNATE:  return C_("imagesource_steamgriddb_image_style", "Alternate");
						case Style.BLURRED:    return C_("imagesource_steamgriddb_image_style", "Blurred");
						// TRANSLATORS: Flat / Material Design image style. Probably should not be translated
						case Style.MATERIAL:   return C_("imagesource_steamgriddb_image_style", "Material");
						case Style.NO_LOGO:    return C_("imagesource_steamgriddb_image_style", "No logo");
						case Style.WHITE_LOGO: return C_("imagesource_steamgriddb_image_style", "White logo");
					}
					assert_not_reached();
				}

				public static Style? from_string(string style)
				{
					switch(style)
					{
						case "alternate":  return Style.ALTERNATE;
						case "blurred":    return Style.BLURRED;
						case "material":   return Style.MATERIAL;
						case "no_logo":    return Style.NO_LOGO;
						case "white_logo": return Style.WHITE_LOGO;
					}
					return null;
				}
			}
		}
	}
}
