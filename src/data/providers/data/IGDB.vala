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

namespace GameHub.Data.Providers.Data
{
	public class IGDB: DataProvider<ArrayList<Result>?>
	{
		private const string SCHEME        = "https://";
		private const string DOMAIN        = "igdb.com";
		private const string API_SUBDOMAIN = "api-v3.";
		private const string API_BASE_URL  = SCHEME + API_SUBDOMAIN + DOMAIN;
		private const string API_KEY_PAGE  = "https://api.igdb.com/admin/applications";

		public override string id   { get { return "igdb"; } }
		public override string name { get { return "IGDB"; } }
		public override string url  { get { return SCHEME + DOMAIN; } }
		public override string icon { get { return "provider-data-igdb"; } }

		public override bool enabled
		{
			get { return Settings.Providers.Data.IGDB.instance.enabled; }
			set { Settings.Providers.Data.IGDB.instance.enabled = value; }
		}

		public static IGDB instance;
		private bool request_quota_reached;

		public IGDB()
		{
			instance = this;
			request_quota_reached = false;
		}

		public override async ArrayList<Result>? data(Game game)
		{
			var cached = DB.Tables.IGDBData.get(game);

			bool error = false;
			uint status = 0;
			string? err_msg = null;

			if(cached != null && cached.length > 0)
			{
				var res = yield parse(game, cached, out error, out status, out err_msg);
				if(error || res == null)
				{
					DB.Tables.IGDBData.remove(game);
				}
				if(res != null) return res;
			}

			if(request_quota_reached) return null;

			var headers = new HashMap<string, string>();
			headers.set("user-key", Settings.Providers.Data.IGDB.instance.api_key);

			var endpoint = "/games?search=%s&fields=%s".printf(Uri.escape_string(game.name), string.joinv(",", Fields.REQUEST_FIELDS));
			var json = yield Parser.load_remote_file_async(API_BASE_URL + endpoint, "GET", null, headers, null, out status);

			var res = yield parse(game, json, out error, out status, out err_msg);

			if(!error)
			{
				DB.Tables.IGDBData.add(game, json);
			}
			else
			{
				show_error(status, err_msg);
			}

			return res;
		}

		private async ArrayList<Result>? parse(Game game, string json, out bool error, out uint status, out string? err_msg)
		{
			error = false;
			status = 0;
			err_msg = null;

			var json_root = Parser.parse_json(json);
			if(json_root == null || json_root.get_node_type() != Json.NodeType.ARRAY) return null;
			var json_array = json_root.get_array();
			if(json_array == null || json_array.get_length() < 1) return null;

			var results = new ArrayList<Result>();

			foreach(var node in json_array.get_elements())
			{
				var obj = node.get_object();

				if(is_error(obj, out status, out err_msg))
				{
					error = true;
					return null;
				}

				results.add(new Result(obj));
			}

			return results;
		}

		private bool is_error(Json.Object? obj, out uint status, out string? err_msg)
		{
			status = 0;
			err_msg = null;

			if(obj == null) return true;

			err_msg = obj.has_member("cause") ? obj.get_string_member("cause") : null;

			if(err_msg != null)
			{
				status = obj.has_member("status") ? (uint) obj.get_int_member("status") : 0;
				warning(@"[IGDB] Error $(status): $(err_msg)");
				return true;
			}
			return false;
		}

		private void show_error(uint status, string? err_msg)
		{
			if(request_quota_reached) return;
			if(status == Soup.Status.FORBIDDEN && err_msg != null && "request limit" in err_msg)
			{
				request_quota_reached = true;
				if(UI.Views.GamesView.GamesView.instance == null) return;
				Idle.add(() => {
					var msg = UI.Views.GamesView.GamesView.instance.add_message(_("Monthly IGDB request quota has been reached. Set your own API key to use IGDB data or disable IGDB."), Gtk.MessageType.WARNING);
					msg.add_button(_("Settings"), 1);

					msg.close.connect(() => {
						#if GTK_3_22
						msg.revealed = false;
						#endif
						Timeout.add(250, () => { msg.destroy(); return Source.REMOVE; });
					});

					msg.response.connect(r => {
						switch(r)
						{
							case 1:
								new UI.Dialogs.SettingsDialog.SettingsDialog("providers/providers");
								break;

							case Gtk.ResponseType.CLOSE:
								msg.close();
								break;
						}
					});
					return Source.REMOVE;
				});
			}
		}

		public class Result
		{
			public int?        id                      = null;
			public string?     name                    = null;
			public string?     url                     = null;
			public int64?      release_date            = null;
			public Website[]?  websites                = null;

			public Link[]?     platforms               = null;

			public string?     summary                 = null;
			public string?     storyline               = null;

			public Link[]?     genres                  = null;
			public Link[]?     keywords                = null;

			public double?     popularity              = null;

			public double?     aggregated_rating       = null;
			public int?        aggregated_rating_count = null;
			public double?     igdb_rating             = null;
			public int?        igdb_rating_count       = null;
			public double?     total_rating            = null;
			public int?        total_rating_count      = null;

			public Result(Json.Object obj)
			{
				if(obj.has_member(Fields.ID))
					id = (int) obj.get_int_member(Fields.ID);
				if(obj.has_member(Fields.NAME))
					name = obj.get_string_member(Fields.NAME);
				if(obj.has_member(Fields.URL))
					url = obj.get_string_member(Fields.URL);
				if(obj.has_member(Fields.RELEASE_DATE))
					release_date = obj.get_int_member(Fields.RELEASE_DATE);

				if(obj.has_member(Fields.SUMMARY))
					summary = obj.get_string_member(Fields.SUMMARY);
				if(obj.has_member(Fields.STORYLINE))
					storyline = obj.get_string_member(Fields.STORYLINE);

				if(obj.has_member(Fields.POPULARITY))
					popularity = obj.get_double_member(Fields.POPULARITY);

				if(obj.has_member(Fields.AGGREGATED_RATING))
					aggregated_rating = obj.get_double_member(Fields.AGGREGATED_RATING);
				if(obj.has_member(Fields.AGGREGATED_RATING_COUNT))
					aggregated_rating_count = (int) obj.get_int_member(Fields.AGGREGATED_RATING_COUNT);
				if(obj.has_member(Fields.IGDB_RATING))
					igdb_rating = obj.get_double_member(Fields.IGDB_RATING);
				if(obj.has_member(Fields.IGDB_RATING_COUNT))
					igdb_rating_count = (int) obj.get_int_member(Fields.IGDB_RATING_COUNT);
				if(obj.has_member(Fields.TOTAL_RATING))
					total_rating = obj.get_double_member(Fields.TOTAL_RATING);
				if(obj.has_member(Fields.TOTAL_RATING_COUNT))
					total_rating_count = (int) obj.get_int_member(Fields.TOTAL_RATING_COUNT);

				if(obj.has_member(Fields.WEBSITES) && obj.get_member(Fields.WEBSITES).get_node_type() == Json.NodeType.ARRAY)
				{
					var websites_array = obj.get_array_member(Fields.WEBSITES);
					if(websites_array.get_length() > 0)
					{
						Website[] websites = {};
						foreach(var node in websites_array.get_elements())
						{
							websites += new Website(node.get_object());
						}
						this.websites = websites;
					}
				}

				if(obj.has_member(Fields.PLATFORMS) && obj.get_member(Fields.PLATFORMS).get_node_type() == Json.NodeType.ARRAY)
				{
					var platforms_array = obj.get_array_member(Fields.PLATFORMS);
					if(platforms_array.get_length() > 0)
					{
						Link[] platforms = {};
						foreach(var node in platforms_array.get_elements())
						{
							platforms += new Link(node.get_object());
						}
						this.platforms = platforms;
					}
				}

				if(obj.has_member(Fields.GENRES) && obj.get_member(Fields.GENRES).get_node_type() == Json.NodeType.ARRAY)
				{
					var genres_array = obj.get_array_member(Fields.GENRES);
					if(genres_array.get_length() > 0)
					{
						Link[] genres = {};
						foreach(var node in genres_array.get_elements())
						{
							genres += new Link(node.get_object());
						}
						this.genres = genres;
					}
				}

				if(obj.has_member(Fields.KEYWORDS) && obj.get_member(Fields.KEYWORDS).get_node_type() == Json.NodeType.ARRAY)
				{
					var keywords_array = obj.get_array_member(Fields.KEYWORDS);
					if(keywords_array.get_length() > 0)
					{
						Link[] keywords = {};
						foreach(var node in keywords_array.get_elements())
						{
							keywords += new Link(node.get_object());
						}
						this.keywords = keywords;
					}
				}
			}

			public class Link
			{
				public string name;
				public string url;

				public Link(Json.Object obj)
				{
					name = obj.get_string_member("name");
					url  = obj.get_string_member("url");
				}
			}

			public class Website
			{
				public string url;
				public Category category;

				public Website(Json.Object obj)
				{
					url = obj.get_string_member("url");
					category = Category.from_id((int) obj.get_int_member("category"));
				}

				public enum Category
				{
					UNKNOWN = 0, OFFICIAL = 1, WIKIA = 2, WIKIPEDIA = 3, FACEBOOK = 4, TWITTER = 5, TWITCH = 6,
					INSTAGRAM = 8, YOUTUBE = 9, IPHONE = 10, IPAD = 11, ANDROID = 12, STEAM = 13, REDDIT = 14,
					DISCORD = 15, GOOGLE_PLUS = 16, TUMBLR = 17, LINKEDIN = 18, PINTEREST = 19, SOUNDCLOUD = 20;

					public static Category from_id(int id)
					{
						return (Category) id;
					}

					public int id()
					{
						return (int) this;
					}

					public string icon()
					{
						switch(this)
						{
							case WIKIPEDIA:   return "related-link-wikipedia-symbolic";
							case FACEBOOK:    return "related-link-facebook-symbolic";
							case TWITTER:     return "related-link-twitter-symbolic";
							case TWITCH:      return "related-link-twitch-symbolic";
							case INSTAGRAM:   return "related-link-instagram-symbolic";
							case YOUTUBE:     return "related-link-youtube-symbolic";
							case IPHONE:      return "related-link-app-iphone-symbolic";
							case IPAD:        return "related-link-app-ipad-symbolic";
							case ANDROID:     return "related-link-app-android-symbolic";
							case STEAM:       return "source-steam-symbolic";
							case REDDIT:      return "related-link-reddit-symbolic";
							case DISCORD:     return "related-link-discord-symbolic";
							case GOOGLE_PLUS: return "related-link-google-plus-symbolic";
							case TUMBLR:      return "related-link-tumblr-symbolic";
							case LINKEDIN:    return "related-link-linkedin-symbolic";
							case PINTEREST:   return "related-link-pinterest-symbolic";
							case SOUNDCLOUD:  return "related-link-soundcloud-symbolic";
						}
						return "web-browser-symbolic";
					}

					public string? description()
					{
						switch(this)
						{
							case OFFICIAL:    return C_("igdb_related_link", "Official website");
							case WIKIA:       return "Wikia";
							case WIKIPEDIA:   return "Wikipedia";
							case FACEBOOK:    return "Facebook";
							case TWITTER:     return "Twitter";
							case TWITCH:      return "Twitch";
							case INSTAGRAM:   return "Instagram";
							case YOUTUBE:     return "YouTube";
							case IPHONE:      return "iPhone";
							case IPAD:        return "iPad";
							case ANDROID:     return "Android";
							case STEAM:       return "Steam";
							case REDDIT:      return "Reddit";
							case DISCORD:     return "Discord";
							case GOOGLE_PLUS: return "Google+";
							case TUMBLR:      return "Tumblr";
							case LINKEDIN:    return "LinkedIn";
							case PINTEREST:   return "Pinterest";
							case SOUNDCLOUD:  return "SoundCloud";
						}
						return null;
					}
				}
			}
		}

		private class Fields
		{
			public const string[] REQUEST_FIELDS = {
				ID, NAME, URL, RELEASE_DATE, WEBSITES + _EXPAND,
				PLATFORMS + _EXPAND,
				SUMMARY, STORYLINE,
				GENRES + _EXPAND, KEYWORDS + _EXPAND,
				POPULARITY,
				AGGREGATED_RATING, AGGREGATED_RATING_COUNT, IGDB_RATING, IGDB_RATING_COUNT, TOTAL_RATING, TOTAL_RATING_COUNT
			};

			public const string   _EXPAND                 = ".*";
			public const string   _COUNT                  = "_count";

			public const string   ID                      = "id";
			public const string   NAME                    = "name";
			public const string   URL                     = "url";
			public const string   RELEASE_DATE            = "first_release_date";
			public const string   WEBSITES                = "websites";

			public const string   PLATFORMS               = "platforms";

			public const string   SUMMARY                 = "summary";
			public const string   STORYLINE               = "storyline";

			public const string   GENRES                  = "genres";
			public const string   KEYWORDS                = "keywords";

			public const string   POPULARITY              = "popularity";

			public const string   AGGREGATED_RATING       = "aggregated_rating";
			public const string   AGGREGATED_RATING_COUNT = AGGREGATED_RATING + _COUNT;
			public const string   IGDB_RATING             = "rating";
			public const string   IGDB_RATING_COUNT       = IGDB_RATING + _COUNT;
			public const string   TOTAL_RATING            = "total_rating";
			public const string   TOTAL_RATING_COUNT      = TOTAL_RATING + _COUNT;
		}

		public override Gtk.Widget? settings_widget
		{
			owned get
			{
				var settings = Settings.Providers.Data.IGDB.instance;

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
					try
					{
						Utils.open_uri(API_KEY_PAGE);
					}
					catch(Error e)
					{
						//FIXME [DEV-ART]: Replace this with inline error display?
						(new Gtk.MessageDialog(
							grid.get_toplevel() as Gtk.Window,
							Gtk.DialogFlags.MODAL, Gtk.MessageType.ERROR, Gtk.ButtonsType.OK,
							"%s\n\n%s", _("Opening IGDB API key page failed"), e.message
						)).show();
					}
				});

				entry_wrapper.add(entry);
				entry_wrapper.add(link);

				var desc_src_wrapper = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);

				var desc_src_label = new Gtk.Label(C_("igdb_preferred_description", "When game has description, show description"));
				desc_src_label.halign = Gtk.Align.START;
				desc_src_label.valign = Gtk.Align.CENTER;
				desc_src_label.hexpand = true;

				var desc_src = new GameHub.UI.Widgets.ModeButton();
				desc_src.homogeneous = false;
				desc_src.append_text(C_("igdb_preferred_description", "of game"));
				desc_src.append_text(C_("igdb_preferred_description", "from IGDB"));
				desc_src.append_text(C_("igdb_preferred_description", "both"));

				desc_src.selected = settings.preferred_description;

				desc_src.mode_changed.connect(() => {
					settings.preferred_description = (Settings.Providers.Data.IGDB.PreferredDescription) desc_src.selected;
				});

				desc_src_wrapper.add(desc_src_label);
				desc_src_wrapper.add(desc_src);

				grid.attach(label, 0, 0);
				grid.attach(entry_wrapper, 1, 0);
				grid.attach(desc_src_wrapper, 0, 1, 2, 1);

				return grid;
			}
		}
	}
}
