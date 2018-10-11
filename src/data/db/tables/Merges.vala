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
using Sqlite;

using GameHub.Utils;

using GameHub.Data.Sources.Steam;
using GameHub.Data.Sources.GOG;
using GameHub.Data.Sources.Humble;

namespace GameHub.Data.DB.Tables
{
	public class Merges: Table
	{
		public static Merges instance;

		public static Table.Field MERGE;

		public Merges()
		{
			instance = this;

			MERGE    = f(0);
		}

		public override void migrate(Sqlite.Database db, int version)
		{
			for(int ver = version; ver < Database.VERSION; ver++)
			{
				switch(ver)
				{
					case 0:
						db.exec("CREATE TABLE `merges`(
							`merge` string not null,
						PRIMARY KEY(`merge`))");
						break;
				}
			}
		}

		public static bool add(Game first, Game second)
		{
			if(first is Sources.GOG.GOGGame.DLC || second is Sources.GOG.GOGGame.DLC) return false;

			unowned Sqlite.Database? db = Database.instance.db;
			if(db == null) return false;

			Statement s;

			int res = db.prepare_v2("SELECT rowid, * FROM `merges` WHERE `merge` LIKE ? OR `merge` LIKE ?", -1, out s);

			if(res != Sqlite.OK)
			{
				warning("[Database.Merges.add] Can't prepare SELECT query (%d): %s", db.errcode(), db.errmsg());
				return false;
			}

			s.bind_text(1, @"%$(first.full_id)%");
			s.bind_text(2, @"%$(second.full_id)%");

			int64? row = null;
			int merge_var = 1;

			string old_merge = null;

			if((res = s.step()) == Sqlite.ROW)
			{
				row = s.column_int64(0);
				old_merge = s.column_text(1);
				merge_var = 2;
				res = db.prepare_v2("INSERT OR REPLACE INTO `merges`(rowid, `merge`) VALUES (?, ?)", -1, out s);
			}
			else
			{
				res = db.prepare_v2("INSERT OR REPLACE INTO `merges`(`merge`) VALUES (?)", -1, out s);
			}

			if(res != Sqlite.OK)
			{
				warning("[Database.Merges.add] Can't prepare INSERT query (%d): %s", db.errcode(), db.errmsg());
				return false;
			}

			string new_merge = "";

			var games = new ArrayList<Game>(Game.is_equal);
			games.add(first);
			games.add(second);
			if(old_merge != null)
			{
				foreach(var gameid in old_merge.split("|"))
				{
					var gparts = gameid.split(":");
					var gsrc = gparts[0];
					var gid = gparts[1];

					if(gsrc == null || gid == null) continue;

					var game = Games.get(gsrc, gid);

					if(game != null && !games.contains(game)) games.add(game);
				}
			}

			foreach(var src in GameSources)
			{
				foreach(var game in games)
				{
					if(game.source.id == src.id)
					{
						if(new_merge != "") new_merge += "|";
						new_merge += game.full_id;
					}
				}
			}

			s.bind_text(merge_var, new_merge);

			res = s.step();

			if(res != Sqlite.DONE)
			{
				warning("[Database.Merges.add] Error (%d): %s", db.errcode(), db.errmsg());
				return false;
			}

			return true;
		}

		public static new ArrayList<Game>? get(Game game)
		{
			unowned Sqlite.Database? db = Database.instance.db;
			if(db == null) return null;

			Statement s;

			int res = db.prepare_v2("SELECT * FROM `merges` WHERE `merge` LIKE ? LIMIT 1", -1, out s);

			if(res != Sqlite.OK)
			{
				warning("[Database.Merges.get] Can't prepare SELECT query (%d): %s", db.errcode(), db.errmsg());
				return null;
			}

			s.bind_text(1, @"$(game.full_id)|%");

			if((res = s.step()) == Sqlite.ROW)
			{
				var games = new ArrayList<Game>(Game.is_equal);
				var merge = s.column_text(0);

				if(merge != null)
				{
					foreach(var gameid in merge.split("|"))
					{
						var gparts = gameid.split(":");
						var gsrc = gparts[0];
						var gid = gparts[1];

						if(gsrc == null || gid == null) continue;

						var g = Games.get(gsrc, gid);

						if(g != null && !games.contains(g) && !Game.is_equal(game, g)) games.add(g);
					}
				}

				return games;
			}

			return null;
		}

		public static bool is_game_merged(Game game)
		{
			unowned Sqlite.Database? db = Database.instance.db;
			if(db == null) return false;

			Statement s;

			int res = db.prepare_v2("SELECT * FROM `merges` WHERE `merge` LIKE ? LIMIT 1", -1, out s);

			if(res != Sqlite.OK)
			{
				warning("[Database.Merges.is_game_merged] Can't prepare SELECT query (%d): %s", db.errcode(), db.errmsg());
				return false;
			}

			s.bind_text(1, @"%|$(game.full_id)%");

			return s.step() == Sqlite.ROW;
		}

		public static bool is_game_merged_as_primary(Game game)
		{
			unowned Sqlite.Database? db = Database.instance.db;
			if(db == null) return false;

			Statement s;

			int res = db.prepare_v2("SELECT * FROM `merges` WHERE `merge` LIKE ? LIMIT 1", -1, out s);

			if(res != Sqlite.OK)
			{
				warning("[Database.Merges.is_game_merged_as_primary] Can't prepare SELECT query (%d): %s", db.errcode(), db.errmsg());
				return false;
			}

			s.bind_text(1, @"$(game.full_id)|%");

			return s.step() == Sqlite.ROW;
		}
	}
}
