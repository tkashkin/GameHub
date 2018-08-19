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
			if(db.prepare_v2("SELECT `playtime` FROM `games`", -1, out stmt) == Sqlite.OK)	// migrate from v1
			{
				db.exec("DROP TABLE `games`");
			}
			
			db.exec("CREATE TABLE IF NOT EXISTS `games`(`source` string not null, `id` string not null, `name` string not null, `icon` string, `image` string, `custom_info` string, PRIMARY KEY(`source`, `id`))");
			db.exec("CREATE TABLE IF NOT EXISTS `unsupported_games`(`source` string not null, `id` string not null, PRIMARY KEY(`source`, `id`))");
			db.exec("CREATE TABLE IF NOT EXISTS `merged_games`(`primary_source` string not null, `primary_id` string not null, `secondary_source` string not null, `secondary_id` string not null, PRIMARY KEY(`primary_source`, `primary_id`, `secondary_source`, `secondary_id`))");
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
		
		public bool merge(Game primary, Game secondary) requires (db != null)
		{
			Statement stmt;
			int res = db.prepare_v2("INSERT OR REPLACE INTO `merged_games`(`primary_source`, `primary_id`, `secondary_source`, `secondary_id`) VALUES (?, ?, ?, ?)", -1, out stmt);
			assert(res == Sqlite.OK);

			stmt.bind_text(1, primary.source.name);
			stmt.bind_text(2, primary.id);
			stmt.bind_text(3, secondary.source.name);
			stmt.bind_text(4, secondary.id);

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

		public ArrayList<Game> get_merged_games(Game primary) requires (db != null)
		{
			Statement stmt;

			int res = db.prepare_v2("SELECT * FROM `merged_games` WHERE `primary_source` = ? AND `primary_id` = ? LIMIT 1", -1, out stmt);
			stmt.bind_text(1, primary.source.name);
			stmt.bind_text(2, primary.id);

			assert(res == Sqlite.OK);

			var games = new ArrayList<Game>(Game.is_equal);

			while((res = stmt.step()) == Sqlite.ROW)
			{
				var src = stmt.column_text(2);
				var id = stmt.column_text(3);

				if(src == null || id == null) continue;

				var game = get_game(src, id);
				if(game != null)
				{
					games.add(game);
				}
			}

			return games;
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
			int res;

			res = db.prepare_v2("SELECT * FROM `merged_games` WHERE `secondary_source` = ? AND `secondary_id` = ? LIMIT 1", -1, out stmt);
			stmt.bind_text(1, game.source.name);
			stmt.bind_text(2, game.id);

			return stmt.step() == Sqlite.ROW;
		}

		public bool is_game_merged_as_primary(Game game) requires (db != null)
		{
			Statement stmt;
			int res;

			res = db.prepare_v2("SELECT * FROM `merged_games` WHERE `primary_source` = ? AND `primary_id` = ? LIMIT 1", -1, out stmt);
			stmt.bind_text(1, game.source.name);
			stmt.bind_text(2, game.id);

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
