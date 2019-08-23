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
	public class ButlerDaemon
	{
		private File? butler_executable = null;
		private DataInputStream stdout_stream;
		private ButlerClient client;

		public ButlerDaemon(File? executable)
		{
			butler_executable = executable;
			start_daemon();
		}

		private void start_daemon()
		{
			if(butler_executable == null || !butler_executable.query_exists())
			{
				warning("[ButlerDaemon.start_daemon] butler executable is not found");
				return;
			}

			var butler_path = butler_executable.get_path();
			var db_path = FSUtils.expand(FSUtils.Paths.Itch.Home, FSUtils.Paths.Itch.Database);

			string[] cmd = {
				butler_path, "daemon", "--json", "--transport", "tcp",
				"--dbpath", db_path
			};
			int stdout_fd;

			try
			{
				if(Application.log_verbose)
				{
					debug("[ButlerDaemon.start_daemon] Starting butler daemon ('%s') with dbpath='%s'", butler_path, db_path);
				}
				Process.spawn_async_with_pipes(null, cmd, null, SpawnFlags.SEARCH_PATH, null, null, null, out stdout_fd, null);
				stdout_stream = new DataInputStream(new UnixInputStream(stdout_fd, false));
			}
			catch(Error e)
			{
				warning("[ButlerDaemon.start_daemon] Error while running butler: %s", e.message);
			}
		}

		private async void get_credentials(out string? address, out string? secret)
		{
			address = null;
			secret = null;
			while(stdout_stream != null)
			{
				try
				{
					var line = yield stdout_stream.read_line_async();

					var json_node = Parser.parse_json(line);
					if(json_node != null && json_node.get_node_type() == Json.NodeType.OBJECT)
					{
						var json_object = json_node.get_object();

						if(json_object.get_string_member("type") == "butlerd/listen-notification")
						{
							address = json_object.get_object_member("tcp").get_string_member("address");
							secret = json_object.get_string_member("secret");
							return;
						}
					}
				}
				catch(Error e)
				{
					warning("[ButlerDaemon.get_credentials] Error: %s", e.message);
				}
			}
		}

		public async bool connect()
		{
			try
			{
				string? address;
				string? secret;
				yield get_credentials(out address, out secret);

				if(address == null || secret == null) return false;
				client = new ButlerClient(yield (new SocketClient().connect_to_host_async(address, 0, null)));

				var res = yield client.call("Meta.Authenticate", Parser.json(j => j.set_member_name("secret").add_string_value(secret)));
				return res != null && res.has_member("ok") && res.get_boolean_member("ok");
			}
			catch(Error e)
			{
				warning("[ButlerDaemon.connect] Error: %s", e.message);
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
	}
}
