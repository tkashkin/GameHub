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

using Gee;
using Sqlite;

using GameHub.Utils;

using GameHub.Data.Sources.Steam;
using GameHub.Data.Sources.GOG;
using GameHub.Data.Sources.Humble;
using GameHub.Data.Sources.EpicGames;

namespace GameHub.Data.DB.Tables
{
	public class IGDBData: Table
	{
		public static IGDBData instance;

		public static Table.Field GAME;
		public static Table.Field DATA;
		public static Table.Field INDEX;

		public IGDBData()
		{
			instance = this;

			GAME  = f(0);
			DATA  = f(1);
			INDEX = f(2);
		}

		public override void migrate(Sqlite.Database db, int version)
		{
			for(int ver = version; ver < Database.VERSION; ver++)
			{
				switch(ver)
				{
					case 7:
						db.exec("CREATE TABLE `igdb_data`(
							`game` string not null,
							`data` string,
						PRIMARY KEY(`game`))");
						break;

					case 8:
						db.exec("ALTER TABLE `igdb_data` ADD `index` integer not null default 0");
						break;
				}
			}
		}

		public static bool add(Game game, string? data)
		{
			unowned Sqlite.Database? db = Database.instance.db;
			if(db == null || data == null) return false;

			Statement s;
			int res = db.prepare_v2("INSERT OR REPLACE INTO `igdb_data`(
					`game`,
					`data`)
				VALUES (?, ?)", -1, out s);

			if(res != Sqlite.OK)
			{
				warning("[Database.IGDBData.add] Can't prepare INSERT query (%d): %s", db.errcode(), db.errmsg());
				return false;
			}

			GAME.bind(s, game.full_id);
			DATA.bind(s, data);

			res = s.step();

			if(res != Sqlite.DONE)
			{
				warning("[Database.IGDBData.add] Error (%d): %s", db.errcode(), db.errmsg());
				return false;
			}

			return true;
		}

		public static bool set_index(Game game, int index)
		{
			unowned Sqlite.Database? db = Database.instance.db;
			if(db == null) return false;

			Statement s;
			int res = db.prepare_v2("UPDATE `igdb_data` SET `index` = ? WHERE `game` = ?", -1, out s);

			if(res != Sqlite.OK)
			{
				warning("[Database.IGDBData.set_index] Can't prepare UPDATE query (%d): %s", db.errcode(), db.errmsg());
				return false;
			}

			s.bind_int(1, index);
			s.bind_text(2, game.full_id);

			res = s.step();

			if(res != Sqlite.DONE)
			{
				warning("[Database.IGDBData.set_index] Error (%d): %s", db.errcode(), db.errmsg());
				return false;
			}

			return true;
		}

		public static new string? get(Game game)
		{
			unowned Sqlite.Database? db = Database.instance.db;
			if(db == null) return null;

			Statement s;

			int res = db.prepare_v2("SELECT * FROM `igdb_data` WHERE `game` = ? LIMIT 1", -1, out s);

			if(res != Sqlite.OK)
			{
				warning("[Database.IGDBData.get] Can't prepare SELECT query (%d): %s", db.errcode(), db.errmsg());
				return null;
			}

			s.bind_text(1, game.full_id);

			if((res = s.step()) == Sqlite.ROW)
			{
				return DATA.get(s);
			}

			return null;
		}

		public static int get_index(Game game)
		{
			unowned Sqlite.Database? db = Database.instance.db;
			if(db == null) return 0;

			Statement s;

			int res = db.prepare_v2("SELECT * FROM `igdb_data` WHERE `game` = ? LIMIT 1", -1, out s);

			if(res != Sqlite.OK)
			{
				warning("[Database.IGDBData.get_index] Can't prepare SELECT query (%d): %s", db.errcode(), db.errmsg());
				return 0;
			}

			s.bind_text(1, game.full_id);

			if((res = s.step()) == Sqlite.ROW)
			{
				return INDEX.get_int(s);
			}

			return 0;
		}

		public static bool remove(Game game)
		{
			unowned Sqlite.Database? db = Database.instance.db;
			if(db == null) return false;

			Statement s;
			int res = db.prepare_v2("DELETE FROM `igdb_data` WHERE `game` = ?", -1, out s);

			if(res != Sqlite.OK)
			{
				warning("[Database.IGDBData.remove] Can't prepare DELETE query (%d): %s", db.errcode(), db.errmsg());
				return false;
			}

			res = s.bind_text(1, game.full_id);

			res = s.step();

			if(res != Sqlite.DONE)
			{
				warning("[Database.IGDBData.remove] Error (%d): %s", db.errcode(), db.errmsg());
				return false;
			}

			return true;
		}
	}
}
