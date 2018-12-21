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
	public class Trove: Humble
	{
		public const string PAGE_URL = "https://www.humblebundle.com/monthly/trove";
		public const string SIGN_URL = "https://www.humblebundle.com/api/v1/user/download/sign";
		public const string FAKE_ORDER = "humble-trove";
		public const string TROVE_INTRO_ID = "trove_intro";

		public override string id { get { return "humble-trove"; } }
		public override string name { get { return "Humble Trove"; } }
		public override string icon { get { return "source-humble-trove-symbolic"; } }

		public override bool enabled
		{
			get { return Settings.Auth.Humble.get_instance().enabled && Settings.Auth.Humble.get_instance().load_trove_games; }
			set { Settings.Auth.Humble.get_instance().load_trove_games = value; }
		}

		private ArrayList<Game> _games = new ArrayList<Game>(Game.is_equal);

		public override ArrayList<Game> games { get { return _games; } }

		public override async ArrayList<Game> load_games(Utils.FutureResult2<Game, bool>? game_loaded=null, Utils.Future? cache_loaded=null)
		{
			if(user_token == null || _games.size > 0)
			{
				return _games;
			}

			Utils.thread("HumbleTroveLoading", () => {
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

				var html = Parser.parse_remote_html_file(Trove.PAGE_URL, "GET", null, headers);

				if(html != null)
				{
					var xpath = new Xml.XPath.Context(html);

					var trove_json = xpath.eval("//script[@id='webpack-monthly-trove-data']/text()")->nodesetval->item(0)->content.strip();

					if(trove_json != null)
					{
						var trove_root_node = Parser.parse_json(trove_json);
						var trove_root = Parser.json_object(trove_root_node, { "displayItemData" });

						if(trove_root != null)
						{
							trove_root.foreach_member((trove_root_obj, key, node) => {
								if(key == TROVE_INTRO_ID) return;

								var obj = node.get_object();
								var downloads = obj.get_object_member("downloads");

								downloads.foreach_member((downloads_obj, dl_os, dl_node) => {
									var dl_obj = dl_node.get_object();
									var dl_name = dl_obj.get_string_member("machine_name");
									var dl_id = dl_obj.get_object_member("url").get_string_member("web");
									dl_obj.set_string_member("download_identifier", dl_id);
									var signed_url = sign_url(dl_name, dl_id, user_token);
									dl_obj.get_object_member("url").set_string_member("web", signed_url ?? "humble-trove-unsigned://" + dl_name + "/_gh_dl_/" + dl_id);
								});

								var game = new HumbleGame(this, Trove.FAKE_ORDER, node);

								if(game.platforms.size == 0) return;
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
							});
						}
					}
				}

				delete html;

				Idle.add(load_games.callback);
			});

			yield;

			return _games;
		}

		public static string? sign_url(string machine_name, string filename, string humble_token)
		{
			var headers = new HashMap<string, string>();
			headers["Cookie"] = @"$(AUTH_COOKIE)=\"$(humble_token)\";";

			var data = new HashMap<string, string>();
			data["machine_name"] = machine_name;
			data["filename"] = filename;

			var signed_node = Parser.parse_remote_json_file(Trove.SIGN_URL, "POST", null, headers, data);
			var signed = signed_node != null && signed_node.get_node_type() == Json.NodeType.OBJECT ? signed_node.get_object() : null;

			return signed != null && signed.has_member("signed_url") ? signed.get_string_member("signed_url") : null;
		}
	}
}
