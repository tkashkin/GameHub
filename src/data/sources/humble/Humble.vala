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

namespace GameHub.Data.Sources.Humble
{
	public class Humble: GameSource
	{
		public const string AUTH_COOKIE = "_simpleauth_sess";

		public override string id { get { return "humble"; } }
		public override string name { get { return "Humble Bundle"; } }
		public override string icon { get { return "source-humble-symbolic"; } }

		public override bool enabled
		{
			get { return Settings.Auth.Humble.get_instance().enabled; }
			set { Settings.Auth.Humble.get_instance().enabled = value; }
		}

		public string? user_token = null;

		private Settings.Auth.Humble settings;

		public Humble()
		{
			settings = Settings.Auth.Humble.get_instance();
			var access_token = settings.access_token;
			if(access_token.length > 0)
			{
				user_token = access_token;
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

			return yield get_token();
		}

		public override bool is_authenticated()
		{
			return user_token != null;
		}

		public override bool can_authenticate_automatically()
		{
			return user_token != null && settings.authenticated;
		}

		private async bool get_token()
		{
			if(user_token != null)
			{
				return true;
			}

			var wnd = new GameHub.UI.Windows.WebAuthWindow(this.name, "https://www.humblebundle.com/login?goto=home", "https://www.humblebundle.com/home/library", AUTH_COOKIE);

			wnd.finished.connect(token =>
			{
				user_token = token.replace("\"", "");
				settings.access_token = user_token ?? "";
				debug("[Auth] Humble access token: %s", user_token);
				Idle.add(get_token.callback);
			});

			wnd.canceled.connect(() => Idle.add(get_token.callback));

			wnd.show_all();
			wnd.present();

			yield;

			return user_token != null;
		}

		private ArrayList<Game> _games = new ArrayList<Game>(Game.is_equal);

		public override ArrayList<Game> games { get { return _games; } }

		public override async ArrayList<Game> load_games(Utils.FutureResult2<Game, bool>? game_loaded=null, Utils.Future? cache_loaded=null)
		{
			if(user_token == null || _games.size > 0)
			{
				return _games;
			}

			Utils.thread("HumbleLoading", () => {
				_games.clear();

				var cached = Tables.Games.get_all(this);
				games_count = 0;
				if(cached.size > 0)
				{
					foreach(var g in cached)
					{
						if(g.platforms.size == 0) continue;
						if(!Settings.UI.get_instance().merge_games || !Tables.Merges.is_game_merged(g))
						{
							g.update_game_info.begin((obj, res) => {
								g.update_game_info.end(res);
								_games.add(g);
								if(game_loaded != null)
								{
									Idle.add(() => { game_loaded(g, true); return Source.REMOVE; });
								}
							});
							Thread.usleep(100000);
						}
						games_count++;
					}
				}

				if(cache_loaded != null)
				{
					Idle.add(() => { cache_loaded(); return Source.REMOVE; });
				}

				var headers = new HashMap<string, string>();
				headers["Cookie"] = @"$(AUTH_COOKIE)=\"$(user_token)\";";

				var orders = Parser.parse_remote_json_file("https://www.humblebundle.com/api/v1/user/order?ajax=true", "GET", null, headers).get_array();

				foreach(var order in orders.get_elements())
				{
					var key = order.get_object().get_string_member("gamekey");

					var root_node = Parser.parse_remote_json_file(@"https://www.humblebundle.com/api/v1/order/$(key)?ajax=true", "GET", null, headers);

					if(root_node == null || root_node.get_node_type() != Json.NodeType.OBJECT) continue;

					var root = root_node.get_object();

					if(root == null) continue;

					var products = root.get_array_member("subproducts");

					if(products == null) continue;

					foreach(var product in products.get_elements())
					{
						var game = new HumbleGame(this, key, product);
						if(game.platforms.size == 0) continue;
						bool is_new_game = !_games.contains(game);
						if(is_new_game && (!Settings.UI.get_instance().merge_games || !Tables.Merges.is_game_merged(game)))
						{
							game.update_game_info.begin((obj, res) => {
								game.update_game_info.end(res);
								_games.add(game);
								if(game_loaded != null)
								{
									Idle.add(() => { game_loaded(game, false); return Source.REMOVE; });
								}
							});
						}
						if(is_new_game) games_count++;
					}
				}

				Idle.add(load_games.callback);
			});

			yield;

			return _games;
		}
	}
}
