using Gtk;
using Gdk;
using Gee;
using Sqlite;

using GameHub.Utils;

using GameHub.Data.Sources.Steam;
using GameHub.Data.Sources.GOG;
using GameHub.Data.Sources.Humble;

namespace GameHub.Data
{
	public class GamesDB
	{
		private Database? db = null;
		
		public GamesDB()
		{
			var path = FSUtils.expand(FSUtils.Paths.Cache.GamesDB);
			
			if(Database.open(path, out db) != Sqlite.OK)
			{
				warning("Can't open games database: " + db.errmsg());
				db = null;
				return;
			}
		} 
		
		public void create_tables() requires (db != null)
		{
			Statement stmt;
			if(db.prepare_v2("SELECT `playtime` FROM `games`", -1, out stmt) == Sqlite.OK) // migrate from v1
			{
				db.exec("DROP TABLE `games`");
			}
			
			db.exec("DROP TABLE IF EXISTS `merged_games`"); // migrate from v2

			db.exec("CREATE TABLE IF NOT EXISTS `games`(`source` string not null, `id` string not null, `name` string not null, `icon` string, `image` string, `custom_info` string, PRIMARY KEY(`source`, `id`))");
			db.exec("CREATE TABLE IF NOT EXISTS `unsupported_games`(`source` string not null, `id` string not null, PRIMARY KEY(`source`, `id`))");
			db.exec("CREATE TABLE IF NOT EXISTS `merges`(`merge` string not null, PRIMARY KEY(`merge`))");
		}
		
		public bool add_game(Game game) requires (db != null)
		{
			Statement stmt;
			int res = db.prepare_v2("INSERT OR REPLACE INTO `games`(`source`, `id`, `name`, `icon`, `image`, `custom_info`) VALUES (?, ?, ?, ?, ?, ?)", -1, out stmt);
			assert(res == Sqlite.OK);

			stmt.bind_text(1, game.source.name);
			stmt.bind_text(2, game.id);
			stmt.bind_text(3, game.name);
			stmt.bind_text(4, game.icon);
			stmt.bind_text(5, game.image);
			stmt.bind_text(6, game.custom_info);

			res = stmt.step();

			return res == Sqlite.DONE;
		}
		
		public bool add_unsupported_game(GameSource src, string id) requires (db != null)
		{
			Statement stmt;
			int res = db.prepare_v2("INSERT OR REPLACE INTO `unsupported_games`(`source`, `id`) VALUES (?, ?)", -1, out stmt);
			assert(res == Sqlite.OK);

			stmt.bind_text(1, src.name);
			stmt.bind_text(2, id);

			res = stmt.step();

			return res == Sqlite.DONE;
		}
		
		public bool merge(Game first, Game second) requires (db != null)
		{
			Statement stmt;

			int res = db.prepare_v2("SELECT rowid, * FROM `merges` WHERE `merge` LIKE ? OR `merge` LIKE ?", -1, out stmt);
			assert(res == Sqlite.OK);

			stmt.bind_text(1, @"%$(first.source.name):$(first.id)%");
			stmt.bind_text(2, @"%$(second.source.name):$(second.id)%");

			int64? row = null;
			int merge_var = 1;

			string old_merge = null;

			if((res = stmt.step()) == Sqlite.ROW)
			{
				row = stmt.column_int64(0);
				old_merge = stmt.column_text(1);
				merge_var = 2;
				res = db.prepare_v2("INSERT OR REPLACE INTO `merges`(rowid, `merge`) VALUES (?, ?)", -1, out stmt);
			}
			else
			{
				res = db.prepare_v2("INSERT OR REPLACE INTO `merges`(`merge`) VALUES (?)", -1, out stmt);
			}
			assert(res == Sqlite.OK);

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

					var game = get_game(gsrc, gid);

					if(game != null && !games.contains(game)) games.add(game);
				}
			}

			foreach(var src in GameSources)
			{
				foreach(var game in games)
				{
					if(game.source.name == src.name)
					{
						if(new_merge != "") new_merge += "|";
						new_merge += @"$(game.source.name):$(game.id)";
					}
				}
			}

			stmt.bind_text(merge_var, new_merge);

			debug("[GamesDB] Merging: " + new_merge);

			res = stmt.step();

			return res == Sqlite.DONE;
		}

		public Game? get_game(string src, string id) requires (db != null)
		{
			if(src == null || id == null) return null;

			Statement stmt;
			int res;

			res = db.prepare_v2("SELECT * FROM `games` WHERE `source` = ? AND `id` = ?", -1, out stmt);
			res = stmt.bind_text(1, src);
			res = stmt.bind_text(2, id);

			assert(res == Sqlite.OK);

			if((res = stmt.step()) == Sqlite.ROW)
			{
				var s = GameSource.by_name(stmt.column_text(0));

				if(s is Steam)
				{
					return new SteamGame.from_db((Steam) s, stmt);
				}
				else if(s is GOG)
				{
					return new GOGGame.from_db((GOG) s, stmt);
				}
				else if(s is Humble)
				{
					return new HumbleGame.from_db((Humble) s, stmt);
				}
			}

			return null;
		}

		public ArrayList<Game> get_games(GameSource? src = null) requires (db != null)
		{
			Statement stmt;
			int res;
			
			if(src != null)
			{
				res = db.prepare_v2("SELECT * FROM `games` WHERE `source` = ?", -1, out stmt);
				res = stmt.bind_text(1, src.name);
			}
			else
			{
				res = db.prepare_v2("SELECT * FROM `games`", -1, out stmt);
			}
			
			assert(res == Sqlite.OK);
			
			var games = new ArrayList<Game>(Game.is_equal);
			
			while((res = stmt.step()) == Sqlite.ROW)
			{
				var s = GameSource.by_name(stmt.column_text(0));
				
				if(s is Steam)
				{
					games.add(new SteamGame.from_db((Steam) s, stmt));
				}
				else if(s is GOG)
				{
					games.add(new GOGGame.from_db((GOG) s, stmt));
				}
				else if(s is Humble)
				{
					games.add(new HumbleGame.from_db((Humble) s, stmt));
				}
			}
			
			return games;
		}

		public ArrayList<Game>? get_merged_games(Game game) requires (db != null)
		{
			Statement stmt;

			int res = db.prepare_v2("SELECT * FROM `merges` WHERE `merge` LIKE ? LIMIT 1", -1, out stmt);
			stmt.bind_text(1, @"$(game.source.name):$(game.id)|%");

			assert(res == Sqlite.OK);

			while((res = stmt.step()) == Sqlite.ROW)
			{
				var games = new ArrayList<Game>(Game.is_equal);
				var merge = stmt.column_text(0);

				if(merge != null)
				{
					foreach(var gameid in merge.split("|"))
					{
						var gparts = gameid.split(":");
						var gsrc = gparts[0];
						var gid = gparts[1];

						if(gsrc == null || gid == null) continue;

						var g = get_game(gsrc, gid);

						if(g != null && !games.contains(g) && !Game.is_equal(game, g)) games.add(g);
					}
				}

				return games;
			}

			return null;
		}
		
		public ArrayList<string> get_unsupported_games(GameSource src) requires (db != null)
		{
			Statement stmt;
			int res;
			
			res = db.prepare_v2("SELECT * FROM `unsupported_games` WHERE `source` = ?", -1, out stmt);
			stmt.bind_text(1, src.name);
			
			var games = new ArrayList<string>();
			
			while((res = stmt.step()) == Sqlite.ROW)
			{
				games.add(stmt.column_text(1));
			}
			
			return games;
		}
		
		public bool is_game_unsupported(GameSource src, string id) requires (db != null)
		{
			Statement stmt;
			int res;
			
			res = db.prepare_v2("SELECT * FROM `unsupported_games` WHERE `source` = ? AND `id` = ? LIMIT 1", -1, out stmt);
			stmt.bind_text(1, src.name);
			stmt.bind_text(2, id);
			
			return stmt.step() == Sqlite.ROW;
		}
		
		public bool is_game_merged(Game game) requires (db != null)
		{
			Statement stmt;

			int res = db.prepare_v2("SELECT * FROM `merges` WHERE `merge` LIKE ? LIMIT 1", -1, out stmt);
			stmt.bind_text(1, @"%|$(game.source.name):$(game.id)%");

			assert(res == Sqlite.OK);

			return stmt.step() == Sqlite.ROW;
		}

		public bool is_game_merged_as_primary(Game game) requires (db != null)
		{
			Statement stmt;

			int res = db.prepare_v2("SELECT * FROM `merges` WHERE `merge` LIKE ? LIMIT 1", -1, out stmt);
			stmt.bind_text(1, @"$(game.source.name):$(game.id)|%");

			assert(res == Sqlite.OK);

			return stmt.step() == Sqlite.ROW;
		}

		private static GamesDB? instance;
		public static unowned GamesDB get_instance()
		{
			if(instance == null)
			{
				instance = new GamesDB();
			}
			return instance;
		}
		
		public static void init()
		{
			GamesDB.get_instance().create_tables();
		}
	}
}
