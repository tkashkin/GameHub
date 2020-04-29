/*
This file is part of GameHub.
Copyright (C) 2018-2019 Anatoliy Kashkin

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

using Gtk;
using Gee;
using GameHub.Utils;
using GameHub.Data.Sources.Steam;
using GameHub.Data.Sources.GOG;
using GameHub.Data.Sources.EpicGames;

namespace GameHub.Data
{
	public abstract class GameSource
	{
		public virtual string id { get { return ""; } }
		public virtual string name { get { return ""; } }
		public virtual string name_from { owned get { return _("%s games").printf(name); } }
		public virtual string icon { get { return ""; } }
		public virtual string auth_description { owned get { return ""; } }

		public abstract bool enabled { get; set; }

		public int games_count { get; protected set; }

		public abstract bool is_installed(bool refresh=false);

		public abstract async bool install();

		public abstract async bool authenticate();
		public abstract bool is_authenticated();
		public abstract bool can_authenticate_automatically();

		public abstract ArrayList<Game> games { get; }

		public abstract async ArrayList<Game> load_games(Utils.FutureResult2<Game, bool>? game_loaded=null, Utils.Future? cache_loaded=null);

		public static GameSource? by_id(string id)
		{
			foreach(var src in GameSources)
			{
				if(src.id == id) return src;
			}
			return null;
		}

		public static GameSource? by_name(string name)
		{
			foreach(var src in GameSources)
			{
				if(src.name == name) return src;
			}
			return null;
		}
	}

	public static GameSource[] GameSources;
}
