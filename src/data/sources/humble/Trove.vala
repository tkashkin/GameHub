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

					var items = xpath.eval("//div[starts-with(@class, 'trove-grid-item')]")->nodesetval;
					if(items != null && !items->is_empty())
					{
						for(int i = 0; i < items->length(); i++)
						{
							var item = items->item(i);
							var id = item->get_prop("data-machine-name");
							var xr = @"//div[starts-with(@class, 'trove-product-detail')][@data-machine-name='$(id)']";

							var dl_btn = xpath.eval(@"$(xr)//button[contains(@class, 'js-download-button')]")->nodesetval;

							if(dl_btn == null || dl_btn->is_empty())
							{
								continue; // no dl button, can't download
							}

							var image = Parser.html_subnode(item, "img")->get_prop("src");

							var name = xpath.eval(@"$(xr)//h1[@class='product-human-name']/text()")->nodesetval->item(0)->content;

							var desc_nodes = xpath.eval(@"$(xr)//div[@class='trove-product-description']/node()")->nodesetval;

							string desc = "";

							if(desc_nodes != null && desc_nodes->length() > 0)
							{
								for(int dn = 0; dn < desc_nodes->length(); dn++)
								{
									desc += Parser.xml_node_to_string(desc_nodes->item(dn));
								}
								desc = desc.strip();
							}

							var json = new Json.Object();
							json.set_string_member("machine_name", id);
							json.set_string_member("human_name", name);
							json.set_string_member("icon", image);
							json.set_string_member("_gamehub_description", desc);

							var dl_nodes = xpath.eval(@"$(xr)//div[starts-with(@class, 'trove-platform-selector')]")->nodesetval;

							var dls = new Json.Array();

							if(dl_nodes != null && !dl_nodes->is_empty())
							{
								for(int d = 0; d < dl_nodes->length(); d++)
								{
									var dn = dl_nodes->item(d);
									var dl = new Json.Object();

									dl.set_string_member("platform", dn->get_prop("data-platform"));
									dl.set_string_member("download_identifier", dn->get_prop("data-url"));
									dl.set_string_member("machine_name", dn->get_prop("data-machine-name"));

									var signed_url = sign_url(dn->get_prop("data-machine-name"), dn->get_prop("data-url"), user_token);

									var dl_struct = new Json.Object();
									dl_struct.set_string_member("name", @"$(name) (Trove)");

									var urls = new Json.Object();
									urls.set_string_member("web", signed_url);

									dl_struct.set_object_member("url", urls);

									var dl_struct_arr = new Json.Array();
									dl_struct_arr.add_object_element(dl_struct);

									dl.set_array_member("download_struct", dl_struct_arr);

									dls.add_object_element(dl);
								}
							}

							json.set_array_member("downloads", dls);

							var json_node = new Json.Node(Json.NodeType.OBJECT);
							json_node.set_object(json);

							var game = new HumbleGame(this, Trove.FAKE_ORDER, json_node);

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
