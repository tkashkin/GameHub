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
	public class IGDB: DataProvider
	{
		private const string SCHEME        = "https://";
		private const string DOMAIN        = "igdb.com";
		private const string API_SUBDOMAIN = "api-v3.";
		private const string API_BASE_URL  = SCHEME + API_SUBDOMAIN + DOMAIN;

		public override string id   { get { return "igdb"; } }
		public override string name { get { return "IGDB"; } }
		public override string url  { get { return SCHEME + DOMAIN; } }
		public override string icon { get { return "provider-data-igdb"; } }

		public override bool enabled
		{
			get { return Settings.Providers.Data.IGDB.get_instance().enabled; }
			set { Settings.Providers.Data.IGDB.get_instance().enabled = value; }
		}

		public static IGDB instance;
		public IGDB()
		{
			instance = this;
		}

		public override async DataProvider.Result? data(Game game)
		{
			var cached = DB.Tables.IGDBData.get(game);

			if(cached != null)
			{
				return yield parse(game, cached);
			}

			var headers = new HashMap<string, string>();
			headers.set("user-key", Settings.Providers.Data.IGDB.get_instance().api_key);

			var endpoint = "/games?search=%s&fields=%s".printf(Uri.escape_string(game.name), string.joinv(",", Fields.REQUEST_FIELDS));
			var json = yield Parser.load_remote_file_async(API_BASE_URL + endpoint, "GET", null, headers);

			DB.Tables.IGDBData.add(game, json);

			return yield parse(game, json);
		}

		private async DataProvider.Result? parse(Game game, string data)
		{
			var json_root = Parser.parse_json(data);
			if(json_root == null || json_root.get_node_type() != Json.NodeType.ARRAY) return null;
			var json_array = json_root.get_array();
			if(json_array == null || json_array.get_length() < 1) return null;

			return new Result(json_array.get_object_element(0));
		}

		public class Result: DataProvider.Result
		{
			public int?        id                      = null;
			public string?     name                    = null;
			public string?     url                     = null;
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
					UNKNOWN, OFFICIAL, WIKIA, WIKIPEDIA, FACEBOOK, TWITTER, TWITCH, INSTAGRAM, YOUTUBE, IPHONE, IPAD,
					ANDROID, STEAM, REDDIT, DISCORD, GOOGLE_PLUS, TUMBLR, LINKEDIN, PINTEREST, SOUNDCLOUD;

					public static Category from_id(int id)
					{
						switch(id)
						{
							case 1:  return OFFICIAL;
							case 2:  return WIKIA;
							case 3:  return WIKIPEDIA;
							case 4:  return FACEBOOK;
							case 5:  return TWITTER;
							case 6:  return TWITCH;
							case 8:  return INSTAGRAM;
							case 9:  return YOUTUBE;
							case 10: return IPHONE;
							case 11: return IPAD;
							case 12: return ANDROID;
							case 13: return STEAM;
							case 14: return REDDIT;
							case 15: return DISCORD;
							case 16: return GOOGLE_PLUS;
							case 17: return TUMBLR;
							case 18: return LINKEDIN;
							case 19: return PINTEREST;
							case 20: return SOUNDCLOUD;
						}
						return UNKNOWN;
					}

					public int id()
					{
						switch(this)
						{
							case OFFICIAL:    return 1;
							case WIKIA:       return 2;
							case WIKIPEDIA:   return 3;
							case FACEBOOK:    return 4;
							case TWITTER:     return 5;
							case TWITCH:      return 6;
							case INSTAGRAM:   return 8;
							case YOUTUBE:     return 9;
							case IPHONE:      return 10;
							case IPAD:        return 11;
							case ANDROID:     return 12;
							case STEAM:       return 13;
							case REDDIT:      return 14;
							case DISCORD:     return 15;
							case GOOGLE_PLUS: return 16;
							case TUMBLR:      return 17;
							case LINKEDIN:    return 18;
							case PINTEREST:   return 19;
							case SOUNDCLOUD:  return 20;
						}
						return 0;
					}

					public string icon()
					{
						switch(this)
						{
							case STEAM:       return "source-steam-symbolic";
						}
						return "web-browser-symbolic";
					}
				}
			}
		}

		private class Fields
		{
			public const string[] REQUEST_FIELDS = {
				ID, NAME, URL, WEBSITES + _EXPAND,
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
	}
}
