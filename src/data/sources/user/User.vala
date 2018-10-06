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

namespace GameHub.Data.Sources.User
{
	public class User: GameSource
	{
		public static User instance;

		public override string id { get { return "user"; } }
		public override string name { get { return _("User games"); } }
		public override string icon { get { return "avatar-default-symbolic"; } }

		public User()
		{
			instance = this;
		}

		public override bool enabled
		{
			get { return true; }
			set {}
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
			return true;
		}

		public override bool is_authenticated()
		{
			return true;
		}

		public override bool can_authenticate_automatically()
		{
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

			Utils.thread("UserGamesLoading", () => {
				_games.clear();

				var cached = Tables.Games.get_all(this);
				games_count = 0;
				if(cached.size > 0)
				{
					foreach(var g in cached)
					{
						if(!Settings.UI.get_instance().merge_games || !Tables.Merges.is_game_merged(g))
						{
							g.update_game_info.begin();
							_games.add(g);
							if(game_loaded != null)
							{
								Idle.add(() => { game_loaded(g, true); return Source.REMOVE; });
							}
							((UserGame) g).removed.connect(() => {
								_games.remove(g);
							});
						}
						games_count++;
					}
				}

				if(cache_loaded != null)
				{
					Idle.add(() => { cache_loaded(); return Source.REMOVE; });
				}

				Idle.add(load_games.callback);
			});

			yield;

			return _games;
		}
	}
}
