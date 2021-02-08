/*
This file is part of GameHub.
Copyright (C) 2018-2019 Anatoliy Kashkin
Copyright (C) 2020 Adam Jordanek

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

namespace GameHub.Data.Sources.EpicGames
{
	public class EpicGames: GameSource
	{
		public static EpicGames instance;

		private bool? installed = null;
		public File? legendary_executable = null;
		
		public override string id { get { return "epicgames"; } }
		public override string name { get { return "EpicGames"; } }
		public override string icon { get { return "source-epicgames-symbolic"; } }

		private Settings.Auth.EpicGames settings;
		private FSUtils.Paths.Settings paths = FSUtils.Paths.Settings.instance;

		public override bool enabled
		{
			get { return settings.enabled; }
			set { settings.enabled = value; }
		}


		public LegendaryWrapper? legendary_wrapper { get; private set; }

		public string? user_id { get; protected set; }
		public string? user_name { get; protected set; }

		public EpicGames()
		{
			instance = this;
			legendary_wrapper = new LegendaryWrapper();
			settings = Settings.Auth.EpicGames.instance;
		}

		public override bool is_installed(bool refresh)
		{
			/*
			Epic games depends on
			*/
			if(installed != null && !refresh)
			{
				return (!) installed;
			}

			//check if legendary exists
			var legendary = Utils.find_executable(paths.legendary_command);

			if(legendary == null || !legendary.query_exists())
			{
				debug("[EpicGames] is_installed: Legendary not found");

			}
			else
			{
				debug("[EpicGames] is_installed: LegendaryYES");
			}

			legendary_executable = legendary;
			installed = legendary_executable != null && legendary_executable.query_exists();

			return (!) installed;
		}

		public override async bool install()
		{
			return true;
		}

		public override async bool authenticate()
		{
			debug("[EpicGames] Performing auth");
			var username = yield legendary_wrapper.auth();
			settings.authenticated = username != null;
			if(username != null) {
				user_name = username;
				return true;
			}else return false;
		}

		public override bool is_authenticated()
		{
			var result = legendary_wrapper.is_authenticated();
			settings.authenticated = result;
			
			if (result) {
				legendary_wrapper.get_username.begin ((obj, res) => {
					user_name = legendary_wrapper.get_username.end (res);
				});
			}
			
			return result;
		}

		public override bool can_authenticate_automatically()
		{
			debug("[EpicGames] can_authenticate_automatically: NOT IMPLEMENTED");
			return false;
		}

		private ArrayList<Game> _games = new ArrayList<Game>(Game.is_equal);

		public override ArrayList<Game> games { get { return _games; } }

		public override async ArrayList<Game> load_games(Utils.FutureResult2<Game, bool>? game_loaded=null, Utils.Future? cache_loaded=null)
		{
			if(_games.size > 0)
			{
				return _games;
			}

			debug("[EpicGames] Load games");

			Utils.thread("EpicGamesLoading", () => {
				_games.clear();
				
				games_count = 0;
				
				var cached = Tables.Games.get_all(this);
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
				
				var games = legendary_wrapper.getGames();
				foreach(var game in games)
				{
					var g = new EpicGamesGame(this, game.name,  game.id);
					bool is_new_game =  !_games.contains(g);
					if(is_new_game && (!Settings.UI.Behavior.instance.merge_games || !Tables.Merges.is_game_merged(g)))
					{
						_games.add(g);
						if(game_loaded != null)
						{
							game_loaded(g, false);
						}
					}

					if(is_new_game) {
						g.save();
						if(game_loaded != null)
						{
							game_loaded(g, true);
						}
						_games.add(g);
						games_count++;
					} else {
						var index = _games.index_of(g);
						_games.get(index).update_status();
					}
				}
				Idle.add(load_games.callback);
			});
			yield;
			return _games;
		}


	}
}
