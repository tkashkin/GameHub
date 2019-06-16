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

using Gee;
using GameHub.Utils;

namespace GameHub.Data.Providers.Images
{
	public class SteamGridDB: ImagesProvider
	{
		private const string DOMAIN       = "https://steamgriddb.com";
		private const string BASE_URL     = DOMAIN + "/api/v2";
		private const string API_KEY_PAGE = DOMAIN + "/profile/preferences";

		public override string id   { get { return "steamgriddb"; } }
		public override string name { get { return "SteamGridDB"; } }
		public override string url  { get { return DOMAIN; } }
		public override string icon { get { return "provider-images-steamgriddb"; } }

		public override bool enabled
		{
			get { return Settings.Providers.Images.SteamGridDB.instance.enabled; }
			set { Settings.Providers.Images.SteamGridDB.instance.enabled = value; }
		}

		public override async ImagesProvider.Result images(Game game)
		{
			var result = new ImagesProvider.Result();

			var endpoint = "/grids/steam/" + game.id;

			if(game is GameHub.Data.Sources.Steam.SteamGame)
			{
				var gid = yield game_id_by_steam_appid(game.id);
				if(gid != null) result.url = DOMAIN + "/game/" + gid;
			}
			else
			{
				var gid = yield game_id_by_name(game.name);
				if(gid == null) return result;
				endpoint = "/grids/game/" + gid;
				result.url = DOMAIN + "/game/" + gid;
			}

			var root = yield Parser.parse_remote_json_file_async(BASE_URL + endpoint, "GET", Settings.Providers.Images.SteamGridDB.instance.api_key);
			if(root == null || root.get_node_type() != Json.NodeType.OBJECT) return result;
			var obj = root.get_object();
			var data = obj.has_member("data") ? obj.get_array_member("data") : null;
			if(data == null || data.get_length() < 1) return result;

			result.images = new ArrayList<Image>();
			foreach(var img_node in data.get_elements())
			{
				var img = img_node != null && img_node.get_node_type() == Json.NodeType.OBJECT ? img_node.get_object() : null;
				if(img == null || !img.has_member("url")) continue;
				result.images.add(new Image(img));
			}

			return result;
		}

		private async string? game_id_by_name(string name)
		{
			var root = yield Parser.parse_remote_json_file_async(BASE_URL + "/search/autocomplete/" + Uri.escape_string(name), "GET", Settings.Providers.Images.SteamGridDB.instance.api_key);
			if(root == null || root.get_node_type() != Json.NodeType.OBJECT) return null;
			var obj = root.get_object();
			var data = obj.has_member("data") ? obj.get_array_member("data") : null;
			if(data == null || data.get_length() < 1) return null;
			var item = data.get_object_element(0);
			return item == null || !item.has_member("id") ? null : item.get_int_member("id").to_string();
		}

		private async string? game_id_by_steam_appid(string appid)
		{
			var root = yield Parser.parse_remote_json_file_async(BASE_URL + "/games/steam/" + appid, "GET", Settings.Providers.Images.SteamGridDB.instance.api_key);
			if(root == null || root.get_node_type() != Json.NodeType.OBJECT) return null;
			var obj = root.get_object();
			var data = obj.has_member("data") ? obj.get_object_member("data") : null;
			return data == null || !data.has_member("id") ? null : data.get_int_member("id").to_string();
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

				return grid;
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
				ALTERNATE, BLURRED, MATERIAL, NO_LOGO;

				public string name()
				{
					switch(this)
					{
						case Style.ALTERNATE: return C_("imagesource_steamgriddb_image_style", "Alternate");
						case Style.BLURRED:   return C_("imagesource_steamgriddb_image_style", "Blurred");
						// TRANSLATORS: Flat / Material Design image style. Probably should not be translated
						case Style.MATERIAL:  return C_("imagesource_steamgriddb_image_style", "Material");
						case Style.NO_LOGO:   return C_("imagesource_steamgriddb_image_style", "No logo");
					}
					assert_not_reached();
				}

				public static Style? from_string(string style)
				{
					switch(style)
					{
						case "alternate": return Style.ALTERNATE;
						case "blurred":   return Style.BLURRED;
						case "material":  return Style.MATERIAL;
						case "no_logo":   return Style.NO_LOGO;
					}
					return null;
				}
			}
		}
	}
}
