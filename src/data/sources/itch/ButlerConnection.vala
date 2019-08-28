/*
This file is part of GameHub.
Copyright (C) 2018-2019 Anatoliy Kashkin
Copyright (C) 2019 Yaohan Chen

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

namespace GameHub.Data.Sources.Itch
{
	public class ButlerConnection : Object, ForwardsNotifications
	{
		private ButlerClient client;

		public async bool connect(string address, string secret)
		{
			try
			{
				client = new ButlerClient(yield (new SocketClient().connect_to_host_async(address, 0, null)));
				forward_notifications_from(client);

				var res = yield client.call("Meta.Authenticate", Parser.json(j => j.set_member_name("secret").add_string_value(secret)));
				return res != null && res.has_member("ok") && res.get_boolean_member("ok");
			}
			catch(Error e)
			{
				warning("[ButlerConnection.connect] Error: %s", e.message);
			}
			return false;
		}

		public async bool authenticate(string api_key, out string? user_name, out int? user_id)
		{
			user_name = null;
			user_id = null;
			var res = yield client.call("Profile.LoginWithAPIKey", Parser.json(j => j.set_member_name("apiKey").add_string_value(api_key)));
			var user = Parser.json_nested_object(res, {"profile", "user"});

			if(user == null) return false;
			if(user.has_member("username"))
				user_name = user.get_string_member("username");
			if(user.has_member("id"))
				user_id = (int) user.get_int_member("id");
			return true;
		}

		public async ArrayList<Json.Node> get_owned_keys(int profile_id, bool fresh)
		{
			var res = yield client.call("Fetch.ProfileOwnedKeys", Parser.json(j => j
				.set_member_name("profileId").add_int_value(profile_id)
				.set_member_name("fresh").add_boolean_value(fresh)
			));

			ArrayList<Json.Node> items = new ArrayList<Json.Node>();

			var arr = res.has_member("items") ? res.get_array_member("items") : null;
			if(arr != null)
			{
				arr.foreach_element((array, index, node) => {
					items.add(node.get_object().get_member("game"));
				});
				// next page
			}

			return items;
		}

		public async HashMap<int, ArrayList<string>> get_caves(int? game_id=null, out ArrayList<Json.Node> installed_games=null)
		{
			var result = yield client.call("Fetch.Caves", Parser.json(j => {
				if(game_id != null)
				{
					j.set_member_name("filters").begin_object()
						.set_member_name("gameId").add_int_value(game_id)
						.end_object();
				}
			}));

			var caves = new HashMap<int, ArrayList<string>>();

			var installed = new ArrayList<Json.Node>();

			var arr = result.has_member("items") ? result.get_array_member("items") : null;
			if(arr != null)
			{
				arr.foreach_element((array, index, node) => {
					var cave = node.get_object();
					var cave_id = cave.get_string_member("id");
					var game = cave.get_member("game");
					var cave_game_id = (int) game.get_object().get_int_member("id");

					installed.add(game);

					ArrayList<string> caves_for_game;
					if(caves.has_key(cave_game_id))
					{
						caves_for_game = caves.get(cave_game_id);
					}
					else
					{
						caves_for_game = new ArrayList<string>();
						caves.set(cave_game_id, caves_for_game);
					}
					caves_for_game.add(cave_id);
				});
			}

			installed_games = installed;
			return caves;
		}

		public async void install(int game_id, string path, string install_id)
		{
			var install_plan_result = yield client.call("Install.Plan", Parser.json(j => j
				.set_member_name("gameId").add_int_value(game_id)
			));
			var upload_id = install_plan_result
				.get_object_member("info")
				.get_object_member("upload")
				.get_int_member("id");

			var add_location_result = yield client.call("Install.Locations.Add", Parser.json(j => j
				.set_member_name("path").add_string_value(path)
			));
			var install_location_id = add_location_result
				.get_object_member("installLocation")
				.get_string_member("id");

			var install_queue_result = yield client.call("Install.Queue", Parser.json(j => j
				.set_member_name("game").begin_object()
					.set_member_name("id").add_int_value(game_id)
					.end_object()
				.set_member_name("upload").begin_object()
					.set_member_name("id").add_int_value(upload_id)
					.end_object()
				.set_member_name("installLocationId").add_string_value(install_location_id)
				.set_member_name("queueDownload").add_boolean_value(true)
			));
			// install_id = install_queue_result.get_string_member("id");
			var staging_folder = install_queue_result.get_string_member("stagingFolder");

			yield client.call("Install.Perform", Parser.json(j => j
				.set_member_name("id").add_string_value(install_id)
				.set_member_name("stagingFolder").add_string_value(staging_folder)
			));
		}

		public async bool cancel_install(string id)
		{
			var result = yield client.call("Install.Cancel", Parser.json(j => j
				.set_member_name("id").add_string_value(id)
			));
			return result.get_boolean_member("didCancel");
		}

		public async void uninstall(string cave_id)
		{
			yield client.call("Uninstall.Perform", Parser.json(j => j
				.set_member_name("caveId").add_string_value(cave_id)
			));
		}

		public async void run(string cave_id, string prereqs_dir)
		{
			yield client.call("Launch", Parser.json(j => j
				.set_member_name("caveId").add_string_value(cave_id)
				.set_member_name("prereqsDir").add_string_value(prereqs_dir)
			));
		}
	}
}
