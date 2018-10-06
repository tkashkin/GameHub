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

using Gee;
using GameHub.Data.DB;
using GameHub.Utils;

namespace GameHub.Data.Sources.GOG
{
	public class GOG: GameSource
	{
		private const string CLIENT_ID = "46899977096215655";
		private const string CLIENT_SECRET = "9d85c43b1482497dbbce61f6e4aa173a433796eeae2ca8c5f6129f2dc4de46d9";
		private const string REDIRECT = "https%3A%2F%2Fembed.gog.com%2Fon_login_success%3Forigin%3Dclient";

		private const string[] GAMES_BLACKLIST = {"1424856371" /* Hotline Miami 2: Wrong Number - Digital Comics */};

		public override string id { get { return "gog"; } }
		public override string name { get { return "GOG"; } }
		public override string icon { get { return "source-gog-symbolic"; } }

		public override bool enabled
		{
			get { return Settings.Auth.GOG.get_instance().enabled; }
			set { Settings.Auth.GOG.get_instance().enabled = value; }
		}

		public string? user_id { get; protected set; }
		public string? user_name { get; protected set; }

		private string? user_auth_code = null;
		public string? user_token = null;
		private string? user_refresh_token = null;
		private bool token_needs_refresh = false;

		private Settings.Auth.GOG settings;

		public GOG()
		{
			settings = Settings.Auth.GOG.get_instance();
			var access_token = settings.access_token;
			var refresh_token = settings.refresh_token;
			if(access_token.length > 0 && refresh_token.length > 0)
			{
				user_token = access_token;
				user_refresh_token = refresh_token;
				token_needs_refresh = true;
			}
		}

		public override bool is_installed(bool refresh)
		{
			return true;
		}

		public override async bool install()
		{
			return true;
		}

		public override async bool authenticate()
		{
			settings.authenticated = true;

			if(token_needs_refresh && user_refresh_token != null)
			{
				return (yield refresh_token());
			}

			return (yield get_auth_code()) && (yield get_token());
		}

		public override bool is_authenticated()
		{
			return !token_needs_refresh && user_token != null;
		}

		public override bool can_authenticate_automatically()
		{
			return user_refresh_token != null && settings.authenticated;
		}

		private async bool get_auth_code()
		{
			if(user_auth_code != null)
			{
				return true;
			}

			var wnd = new GameHub.UI.Windows.WebAuthWindow(this.name, @"https://auth.gog.com/auth?client_id=$(CLIENT_ID)&redirect_uri=$(REDIRECT)&response_type=code&layout=client2", "https://embed.gog.com/on_login_success?origin=client&code=");

			wnd.finished.connect(code =>
			{
				user_auth_code = code;
				debug("[Auth] GOG auth code: %s", code);
				Idle.add(get_auth_code.callback);
			});

			wnd.canceled.connect(() => Idle.add(get_auth_code.callback));

			wnd.set_size_request(550, 680);
			wnd.show_all();
			wnd.present();

			yield;

			return user_auth_code != null;
		}

		private async bool get_token()
		{
			if(user_token != null)
			{
				return true;
			}

			var url = @"https://auth.gog.com/token?client_id=$(CLIENT_ID)&client_secret=$(CLIENT_SECRET)&grant_type=authorization_code&redirect_uri=$(REDIRECT)&code=$(user_auth_code)";
			var root = (yield Parser.parse_remote_json_file_async(url)).get_object();
			user_token = root.get_string_member("access_token");
			user_refresh_token = root.get_string_member("refresh_token");
			user_id = root.get_string_member("user_id");

			settings.access_token = user_token ?? "";
			settings.refresh_token = user_refresh_token ?? "";

			debug("[Auth] GOG access token: %s", user_token);
			debug("[Auth] GOG refresh token: %s", user_refresh_token);
			debug("[Auth] GOG user id: %s", user_id);

			return user_token != null;
		}

		private async bool refresh_token()
		{
			if(user_refresh_token == null)
			{
				return false;
			}

			debug("[Auth] Refreshing GOG access token with refresh token: %s", user_refresh_token);

			var url = @"https://auth.gog.com/token?client_id=$(CLIENT_ID)&client_secret=$(CLIENT_SECRET)&grant_type=refresh_token&refresh_token=$(user_refresh_token)";
			var root_node = yield Parser.parse_remote_json_file_async(url);
			var root = root_node != null && root_node.get_node_type() == Json.NodeType.OBJECT ? root_node.get_object() : null;

			if(root == null)
			{
				token_needs_refresh = false;
				return false;
			}

			user_token = root.get_string_member("access_token");
			user_refresh_token = root.get_string_member("refresh_token");
			user_id = root.get_string_member("user_id");

			settings.access_token = user_token ?? "";
			settings.refresh_token = user_refresh_token ?? "";

			debug("[Auth] GOG access token: %s", user_token);
			debug("[Auth] GOG refresh token: %s", user_refresh_token);
			debug("[Auth] GOG user id: %s", user_id);

			token_needs_refresh = false;

			return user_token != null;
		}

		private ArrayList<Game> _games = new ArrayList<Game>(Game.is_equal);

		public override ArrayList<Game> games { get { return _games; } }

		public override async ArrayList<Game> load_games(Utils.FutureResult2<Game, bool>? game_loaded=null, Utils.Future? cache_loaded=null)
		{
			if(((user_id == null || user_token == null) && token_needs_refresh) || _games.size > 0)
			{
				return _games;
			}

			Utils.thread("GOGLoading", () => {
				_games.clear();

				var cached = Tables.Games.get_all(this);
				games_count = 0;
				if(cached.size > 0)
				{
					foreach(var g in cached)
					{
						if(!(g.id in GAMES_BLACKLIST) && (!Settings.UI.get_instance().merge_games || !Tables.Merges.is_game_merged(g)))
						{
							//g.update_game_info.begin();
							_games.add(g);
							if(game_loaded != null)
							{
								Idle.add(() => { game_loaded(g, true); return Source.REMOVE; });
								Thread.usleep(100000);
							}
						}
						games_count++;
					}
				}

				if(cache_loaded != null)
				{
					Idle.add(() => { cache_loaded(); return Source.REMOVE; });
				}

				var page = 1;
				var pages = 1;

				while(page <= pages)
				{
					var url = @"https://embed.gog.com/account/getFilteredProducts?mediaType=1&page=$(page)";
					var root_node = Parser.parse_remote_json_file(url, "GET", user_token);
					var root = root_node != null && root_node.get_node_type() == Json.NodeType.OBJECT ? root_node.get_object() : null;

					if(root == null) break;

					page = (int) root.get_int_member("page");
					pages = (int) root.get_int_member("totalPages");

					debug("[GOG] Loading games: page %d of %d", page, pages);

					if(page == 1)
					{
						var tags = root.has_member("tags") ? root.get_array_member("tags") : null;
						if(tags != null)
						{
							foreach(var t in tags.get_elements())
							{
								var id = t.get_object().get_string_member("id");
								var name = t.get_object().get_string_member("name");
								Tables.Tags.add(new Tables.Tags.Tag("gog:" + id, name, icon));
								debug("[GOG] Imported tag: %s (%s)", name, id);
							}
						}
					}

					var products = root.get_array_member("products");

					foreach(var g in products.get_elements())
					{
						var game = new GOGGame(this, g);
						bool is_new_game = !(game.id in GAMES_BLACKLIST) && !_games.contains(game);
						if(is_new_game && (!Settings.UI.get_instance().merge_games || !Tables.Merges.is_game_merged(game)))
						{
							_games.add(game);
							if(game_loaded != null)
							{
								Idle.add(() => { game_loaded(game, false); return Source.REMOVE; });
							}
						}
						if(is_new_game) games_count++;
					}

					page++;
				}

				Idle.add(load_games.callback);
			});

			yield;

			return _games;
		}
	}
}
