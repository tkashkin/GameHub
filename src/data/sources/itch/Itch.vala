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
	public class Itch: GameSource
	{
		public static Itch instance;

		public File? butler_executable = null;
		private ButlerDaemon? butler_daemon = null;

		public Itch()
		{
			instance = this;
		}

		public override string id { get { return "itch"; } }
		public override string name { get { return "itch.io"; } }
		public override string icon { get { return "source-itch-symbolic"; } }
		public override string auth_description
		{
			owned get
			{
				return "";
			}
		}
		public override bool enabled
		{
			get { return Settings.Auth.Itch.instance.enabled; }
			set { Settings.Auth.Itch.instance.enabled = value; }
		}

		public int? user_id { get; protected set; }
		public string? user_name { get; protected set; }

		private bool? installed = null;

		public override bool is_installed(bool refresh)
		{
			if(installed != null && !refresh)
			{
				return (!) installed;
			}

			var butler = Utils.find_executable("butler");

			if(butler == null || !butler.query_exists())
			{
				var version_file = FSUtils.file(FSUtils.Paths.Itch.Home, FSUtils.Paths.Itch.ButlerCurrentVersion);
				if(version_file != null && version_file.query_exists())
				{
					try
					{
						string version;
						FileUtils.get_contents(version_file.get_path(), out version);
						butler = FSUtils.file(FSUtils.Paths.Itch.Home, FSUtils.Paths.Itch.ButlerExecutable.printf(version));
					}
					catch(Error e)
					{
						warning("[Itch.is_installed] Error while reading butler version: %s", e.message);
					}
				}
			}

			butler_executable = butler;

			if(butler_executable != null && butler_executable.query_exists())
			{
				installed = true;
			}

			return (!) installed;
		}

		public override async bool install()
		{
			return true;
		}

		public override async bool authenticate()
		{
			yield butler_connect();

			Settings.Auth.Itch.instance.authenticated = true;
			if(is_authenticated()) return true;

			var api_key = Settings.Auth.Itch.instance.api_key;

			string? user_name;
			int? user_id;
			var success = yield butler_daemon.authenticate(api_key, out user_name, out user_id);
			this.user_name = user_name;
			this.user_id = user_id;
			return success;
		}

		public override bool is_authenticated()
		{
			return user_id != null;
		}

		public override bool can_authenticate_automatically()
		{
			return Settings.Auth.Itch.instance.authenticated && Settings.Auth.Itch.instance.api_key != null && Settings.Auth.Itch.instance.api_key.length > 0;
		}

		private ArrayList<Game> _games = new ArrayList<Game>(null);

		public override ArrayList<Game> games { get { return _games; } }

		public override async ArrayList<Game> load_games(Utils.FutureResult2<Game, bool>? game_loaded=null, Utils.Future? cache_loaded=null)
		{
			if(!is_authenticated() || _games.size > 0)
			{
				return _games;
			}

			ArrayList<Json.Node> items = yield butler_daemon.get_owned_keys(user_id, true);

			_games.clear();
			foreach(var node in items) {
				var game = new ItchGame(this, node);
				if(game_loaded != null) {
					game_loaded(game, false);
				}
				_games.add(game);
				games_count = _games.size;
			}

			if(cache_loaded != null)
			{
				cache_loaded();
			}
			
			return _games;
		}

		private async void butler_connect()
		{
			if(butler_daemon == null && butler_executable != null || butler_executable.query_exists())
			{
				butler_daemon = new ButlerDaemon(butler_executable);
				yield butler_daemon.connect();
			}
		}
	}
}
