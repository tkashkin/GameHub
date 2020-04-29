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
using GameHub.Data.Sources.EpicGames;
using GameHub.Data.Sources.GOG;
using GameHub.Data.Sources.Humble;
using GameHub.Data.Sources.Itch;
using GameHub.Data.Sources.User;

namespace GameHub.Data.DB.Tables
{
	public class Games: Table
	{
		public static Games instance;

		private static HashMap<string, Game> cache;

		public static Table.Field SOURCE;
		public static Table.Field ID;
		public static Table.Field NAME;
		public static Table.Field INFO;
		public static Table.Field INFO_DETAILED;
		public static Table.Field ICON;
		public static Table.Field IMAGE;
		public static Table.Field TAGS;
		public static Table.Field INSTALL_PATH;
		public static Table.Field EXECUTABLE;
		public static Table.Field PLATFORMS;
		public static Table.Field COMPAT_TOOL;
		public static Table.Field COMPAT_TOOL_SETTINGS;
		public static Table.Field ARGUMENTS;
		public static Table.Field LAST_LAUNCH;
		public static Table.Field PLAYTIME_SOURCE;
		public static Table.Field PLAYTIME_TRACKED;
		public static Table.Field IMAGE_VERTICAL;
		public static Table.Field TWEAKS;
		public static Table.Field WORK_DIR;

		public Games()
		{
			instance             = this;

			cache                = new HashMap<string, Game>();

			SOURCE               = f(0);
			ID                   = f(1);
			NAME                 = f(2);
			INFO                 = f(3);
			INFO_DETAILED        = f(4);
			ICON                 = f(5);
			IMAGE                = f(6);
			TAGS                 = f(7);
			INSTALL_PATH         = f(8);
			EXECUTABLE           = f(9);
			PLATFORMS            = f(10);
			COMPAT_TOOL          = f(11);
			COMPAT_TOOL_SETTINGS = f(12);
			ARGUMENTS            = f(13);
			LAST_LAUNCH          = f(14);
			PLAYTIME_SOURCE      = f(15);
			PLAYTIME_TRACKED     = f(16);
			IMAGE_VERTICAL       = f(17);
			TWEAKS               = f(18);
			WORK_DIR             = f(19);
		}

		public override void migrate(Sqlite.Database db, int version)
		{
			for(int ver = version; ver < Database.VERSION; ver++)
			{
				switch(ver)
				{
					case 0:
						db.exec("CREATE TABLE `games`(
							`source`               string not null,
							`id`                   string not null,
							`name`                 string not null,
							`info`                 string,
							`info_detailed`        string,
							`icon`                 string,
							`image`                string,
							`tags`                 string,
							`install_path`         string,
							`executable`           string,
							`platforms`            string,
							`compat_tool`          string,
							`compat_tool_settings` string,
						PRIMARY KEY(`source`, `id`))");
						break;

					case 1:
						db.exec("ALTER TABLE `games` ADD `arguments` string");
						break;

					case 2:
						db.exec("ALTER TABLE `games` ADD `last_launch` integer not null default 0");
						break;

					case 4:
						db.exec("ALTER TABLE `games` ADD `playtime_source` integer not null default 0");
						db.exec("ALTER TABLE `games` ADD `playtime_tracked` integer not null default 0");
						break;

					case 8:
						db.exec("ALTER TABLE `games` ADD `image_vertical` string");
						break;

					case 9:
						db.exec("ALTER TABLE `games` ADD `tweaks` string");
						break;

					case 10:
						db.exec("ALTER TABLE `games` ADD `work_dir` string");
						break;
				}
			}
		}

		public static bool add(Game game)
		{
			lock(cache)
			{
				if(!cache.has_key(game.full_id))
				{
					cache.set(game.full_id, game);
				}
			}

			if(game is Sources.GOG.GOGGame.DLC) return false;

			unowned Sqlite.Database? db = Database.instance.db;
			if(db == null) return false;

			Statement s;
			int res = db.prepare_v2("INSERT OR REPLACE INTO `games`(
					`source`,
					`id`,
					`name`,
					`info`,
					`info_detailed`,
					`icon`,
					`image`,
					`tags`,
					`install_path`,
					`executable`,
					`platforms`,
					`compat_tool`,
					`compat_tool_settings`,
					`arguments`,
					`last_launch`,
					`playtime_source`,
					`playtime_tracked`,
					`image_vertical`,
					`tweaks`,
					`work_dir`)
				VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", -1, out s);

			if(res != Sqlite.OK)
			{
				warning("[Database.Games.add] Can't prepare INSERT query (%d): %s", db.errcode(), db.errmsg());
				return false;
			}

			var platforms = "";
			foreach(var p in game.platforms)
			{
				if(platforms.length > 0) platforms += ",";
				platforms += p.id();
			}

			var tags = "";
			foreach(var t in game.tags)
			{
				if(tags.length > 0) tags += ",";
				tags += t.id;
			}

			string? tweaks = null;
			if(game is TweakableGame && ((TweakableGame) game).tweaks != null)
			{
				tweaks = "";
				foreach(var t in ((TweakableGame) game).tweaks)
				{
					if(tweaks.length > 0) tweaks += ",";
					tweaks += t;
				}
			}

			SOURCE.bind(s, game.source.id);
			ID.bind(s, game.id);
			NAME.bind(s, game.name);
			INFO.bind(s, game.info);
			INFO_DETAILED.bind(s, game.info_detailed);
			ICON.bind(s, game.icon);
			IMAGE.bind(s, game.image);
			TAGS.bind(s, tags);
			EXECUTABLE.bind(s, game.executable_path == null ? null : game.executable_path);
			INSTALL_PATH.bind(s, game.install_dir == null ? null : game.install_dir.get_path());
			PLATFORMS.bind(s, platforms);
			COMPAT_TOOL.bind(s, game.compat_tool);
			COMPAT_TOOL_SETTINGS.bind(s, game.compat_tool_settings);
			ARGUMENTS.bind(s, game.arguments);
			LAST_LAUNCH.bind_int64(s, game.last_launch);
			PLAYTIME_SOURCE.bind_int64(s, game.playtime_source);
			PLAYTIME_TRACKED.bind_int64(s, game.playtime_tracked);
			IMAGE_VERTICAL.bind(s, game.image_vertical);
			TWEAKS.bind(s, tweaks);
			WORK_DIR.bind(s, game.work_dir == null ? null : game.work_dir_path);

			res = s.step();

			if(res != Sqlite.DONE)
			{
				warning("[Database.Games.add] Error (%d): %s", db.errcode(), db.errmsg());
				return false;
			}

			return true;
		}

		public static bool remove(Game game)
		{
			lock(cache)
			{
				if(cache.has_key(game.full_id))
				{
					cache.unset(game.full_id);
				}
			}

			unowned Sqlite.Database? db = Database.instance.db;
			if(db == null) return false;

			Statement s;
			int res = db.prepare_v2("DELETE FROM `games` WHERE `source` = ? AND `id` = ?", -1, out s);

			if(res != Sqlite.OK)
			{
				warning("[Database.Games.remove] Can't prepare DELETE query (%d): %s", db.errcode(), db.errmsg());
				return false;
			}

			res = s.bind_text(1, game.source.id);
			res = s.bind_text(2, game.id);

			res = s.step();

			if(res != Sqlite.DONE)
			{
				warning("[Database.Games.remove] Error (%d): %s", db.errcode(), db.errmsg());
				return false;
			}

			return true;
		}

		public static new Game? get(string src, string id)
		{
			if(src == null || id == null) return null;

			lock(cache)
			{
				if(cache.has_key(@"$(src):$(id)"))
				{
					return cache.get(@"$(src):$(id)");
				}
			}

			unowned Sqlite.Database? db = Database.instance.db;
			if(db == null) return null;

			Statement st;
			int res;

			res = db.prepare_v2("SELECT * FROM `games` WHERE `source` = ? AND `id` = ?", -1, out st);
			res = st.bind_text(1, src);
			res = st.bind_text(2, id);

			if(res != Sqlite.OK)
			{
				warning("[Database.Games.get] Can't prepare SELECT query (%d): %s", db.errcode(), db.errmsg());
				return null;
			}

			if((res = st.step()) == Sqlite.ROW)
			{
				var s = GameSource.by_id(SOURCE.get(st));
				Game? g = null;

				if(s is Steam)
				{
					g = new SteamGame.from_db((Steam) s, st);
				}
				else if(s is EpicGames)
				{
					g = new EpicGamesGame.from_db((EpicGames) s, st);
				}
				else if(s is GOG)
				{
					g = new GOGGame.from_db((GOG) s, st);
				}
				else if(s is Trove)
				{
					g = new HumbleGame.from_db((Trove) s, st);
				}
				else if(s is Humble)
				{
					g = new HumbleGame.from_db((Humble) s, st);
				}
				else if(s is Itch)
				{
					g = new ItchGame.from_db((Itch) s, st);
				}
				else if(s is User)
				{
					g = new UserGame.from_db((User) s, st);
				}

				if(g != null)
				{
					lock(cache)
					{
						cache.set(g.full_id, g);
					}
				}

				return g;
			}

			return null;
		}

		public static ArrayList<Game>? get_all(GameSource? src = null)
		{
			unowned Sqlite.Database? db = Database.instance.db;
			if(db == null) return null;

			Statement st;
			int res;

			if(src != null)
			{
				res = db.prepare_v2("SELECT * FROM `games` WHERE `source` = ? ORDER BY (CASE WHEN `tags` LIKE ? THEN 1 ELSE 2 END), `name` ASC", -1, out st);
				res = st.bind_text(1, src.id);
				res = st.bind_text(2, "%" + Tags.BUILTIN_INSTALLED.id + "%");
			}
			else
			{
				res = db.prepare_v2("SELECT * FROM `games` ORDER BY (CASE WHEN `tags` LIKE ? THEN 1 ELSE 2 END), `name` ASC", -1, out st);
				res = st.bind_text(1, "%" + Tags.BUILTIN_INSTALLED.id + "%");
			}

			if(res != Sqlite.OK)
			{
				warning("[Database.Games.get_all] Can't prepare SELECT query (%d): %s", db.errcode(), db.errmsg());
				return null;
			}

			var games = new ArrayList<Game>(Game.is_equal);

			while((res = st.step()) == Sqlite.ROW)
			{
				var s = GameSource.by_id(SOURCE.get(st));

				Game? g = null;

				var full_id = SOURCE.get(st) + ":" + ID.get(st);

				lock(cache)
				{
					if(cache.has_key(full_id))
					{
						g = cache.get(full_id);
					}
				}

				if(g == null)
				{
					if(s is Steam)
					{
						g = new SteamGame.from_db((Steam) s, st);
					}
					else if(s is EpicGames)
					{
						g = new EpicGamesGame.from_db((EpicGames) s, st);
					}
					else if(s is GOG)
					{
						g = new GOGGame.from_db((GOG) s, st);
					}
					else if(s is Trove)
					{
						g = new HumbleGame.from_db((Trove) s, st);
					}
					else if(s is Humble)
					{
						g = new HumbleGame.from_db((Humble) s, st);
					}
					else if(s is Itch)
					{
						g = new ItchGame.from_db((Itch) s, st);
					}
					else if(s is User)
					{
						g = new UserGame.from_db((User) s, st);
					}
				}

				if(g != null)
				{
					games.add(g);
					lock(cache)
					{
						if(!cache.has_key(g.full_id))
						{
							cache.set(g.full_id, g);
						}
					}
				}
			}

			return games;
		}
	}
}
