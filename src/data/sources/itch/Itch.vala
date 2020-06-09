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
using GameHub.Data;
using GameHub.Data.DB;

namespace GameHub.Data.Sources.Itch
{
	public class Itch: GameSource
	{
		public static Itch instance;

		public File? butler_executable = null;
		private ButlerDaemon? butler_daemon = null;
		private ButlerConnection? butler_connection = null;

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

			installed = butler_executable != null && butler_executable.query_exists();

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
			var success = yield butler_connection.authenticate(api_key, out user_name, out user_id);
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

		private ArrayList<Game> _games = new ArrayList<Game>(Game.is_equal);

		public override ArrayList<Game> games { get { return _games; } }

		public override async ArrayList<Game> load_games(Utils.FutureResult2<Game, bool>? game_loaded=null, Utils.Future? cache_loaded=null)
		{
			if(!is_authenticated() || _games.size > 0)
			{
				return _games;
			}

			Utils.thread("ItchLoading", () => {
				_games.clear();

				var cached = Tables.Games.get_all(this);
				games_count = 0;
				if(cached.size > 0)
				{
					foreach(var g in cached)
					{
						if(!Settings.UI.Behavior.instance.merge_games || !Tables.Merges.is_game_merged(g))
						{
							_games.add(g);
							if(game_loaded != null)
							{
								game_loaded(g, true);
							}
						}
						games_count++;
					}
				}

				if(cache_loaded != null)
				{
					cache_loaded();
				}

				load_games_from_butler.begin(game_loaded, (obj, res) => {
					load_games_from_butler.end(res);
					Idle.add(load_games.callback);
				});
			});

			yield;

			return _games;
		}

		private async void load_games_from_butler(Utils.FutureResult2<Game, bool>? game_loaded=null)
		{
			ArrayList<Json.Node> owned_games = yield butler_connection.get_owned_keys(user_id, true);
			ArrayList<Json.Node> installed_games;

			var caves = yield butler_connection.get_caves(null, out installed_games);

			ArrayList<Json.Node>[] game_arrays = { owned_games, installed_games };
			foreach(var arr in game_arrays)
			{
				foreach(var node in arr)
				{
					var game = new ItchGame(this, node);
					bool is_new_game = !_games.contains(game);
					if(is_new_game && (!Settings.UI.Behavior.instance.merge_games || !Tables.Merges.is_game_merged(game)))
					{
						_games.add(game);
						if(game_loaded != null)
						{
							game_loaded(game, false);
						}
					}
					if(is_new_game)
					{
						games_count++;
						game.save();
					}
				}
			}

			foreach(var g in _games)
			{
				yield update_game_state((ItchGame) g, caves);
			}
		}

		public async ArrayList<Json.Object>? get_game_uploads(ItchGame game)
		{
			return yield butler_connection.get_game_uploads(game.int_id);
		}

		public async void install_game(ItchGame.Installer installer)
		{
			yield ItchDownloader.get_instance().download(installer, butler_daemon);
			yield update_game_state(installer.game);
		}

		public async void uninstall_game(ItchGame game)
		{
			yield butler_connection.uninstall(game.cave_id);
			yield update_game_state(game);
		}

		public async void update_game_state(ItchGame game, HashMap<int, ArrayList<Cave>>? caves_map=null)
		{
			caves_map = caves_map ?? yield butler_connection.get_caves(game.int_id);
			game.update_caves(caves_map);
		}

		public async void run_game(ItchGame game)
		{
			var connection = yield butler_daemon.create_connection();
			connection.server_call.connect((method, args, responder) => {
				File? file = null;
				switch(method)
				{
					case "ShellLaunch":
						file = FSUtils.file(args.get_string_member("itemPath"));
						break;

					case "HTMLLaunch":
						file = FSUtils.file(args.get_string_member("rootFolder"), args.get_string_member("indexPath"));
						break;

					case "URLLaunch":
						file = File.new_for_uri(args.get_string_member("url"));
						break;
				}
				if(file != null)
				{
					try
					{
						Utils.open_uri(file.get_uri());
					}
					catch(Utils.RunError e)
					{
						//XXX: Should this be propagated to the UI?
						warning(
							"[Sources.Itch] Error while processing %s action: %s-(%s:%d)",
							method, e.message, e.domain.to_string(), e.code
						);
					}
				}
				responder.respond();
			});
			yield connection.run(game.cave_id);
		}

		private async void butler_connect()
		{
			if(butler_daemon == null && butler_executable != null || butler_executable.query_exists())
			{
				butler_daemon = new ButlerDaemon(butler_executable);
				butler_connection = yield butler_daemon.create_connection();
			}
		}
	}
}
