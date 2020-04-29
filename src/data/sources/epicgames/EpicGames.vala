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
		
		public override string id { get { return "epicgames"; } }
		public override string name { get { return "EpicGames"; } }
		public override string icon { get { return "source-epicgames-symbolic"; } }

		private Regex regex = /\*\s*([^(]*)\s\(App\sname:\s([a-zA-Z0-9]+),\sversion:\s([^)]*)\)/;

		private bool enable = true;
		public override bool enabled
		{
			get { return enable; }
			set { enable = value; }
		}


		public LegendaryWrapper? legendary_wrapper { get; private set; }

		public string? user_id { get; protected set; }
		public string? user_name { get; protected set; }

		public EpicGames()
		{
			instance = this;
			legendary_wrapper = new LegendaryWrapper();
		}

		public override bool is_installed(bool refresh)
		{
			debug("[EpicGames] is_installed: NOT IMPLEMENTED");
			return true;
		}

		public override async bool install()
		{
			debug("[EpicGames] install: NOT IMPLEMENTED");
			return true;
		}

		public override async bool authenticate()
		{
			debug("[EpicGames] authenticate: NOT IMPLEMENTED");
			return true;
		}

		public override bool is_authenticated()
		{
			debug("[EpicGames] is_authenticated: NOT IMPLEMENTED");
			return true;
		}

		public override bool can_authenticate_automatically()
		{
			debug("[EpicGames] can_authenticate_automatically: NOT IMPLEMENTED");
			return true;
		}

		public async bool refresh_token()
		{
			debug("[EpicGames] refresh_token: NOT IMPLEMENTED");
			return true;
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
