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
		private string address;
		private string secret;

		public ButlerDaemon(File? executable)
		{
			butler_executable = executable;
			start_daemon();
		}

		public async ButlerConnection create_connection()
		{
			if(address == null || secret == null)
			{
				yield get_credentials();
			}

			var connection = new ButlerConnection();
			yield connection.connect(address, secret);
			return connection;
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
				butler_path, "daemon", "--json", "--transport", "tcp", "--keep-alive",
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

		private async void get_credentials()
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
	}
}
