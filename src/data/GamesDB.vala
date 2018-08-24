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
			Statement s;

			// v1

			if(db.prepare_v2("SELECT `playtime` FROM `games`", -1, out s) == Sqlite.OK)
			{
				db.exec("DROP TABLE `games`");
			}

			// v2

			db.exec("DROP TABLE IF EXISTS `merged_games`");

			// v3

			db.exec("DROP TABLE IF EXISTS `unsupported_games`");

			if(db.prepare_v2("SELECT `platforms` FROM `games`", -1, out s) != Sqlite.OK)
			{
				db.exec("DROP TABLE `games`");
			}

			// current db format

			db.exec("CREATE TABLE IF NOT EXISTS `games`(
				`source` string not null,
				`id` string not null,
				`name` string not null,
				`icon` string,
				`image` string,
				`install_path` string,
				`platforms` string,
				`info` string,
				`info_detailed` string,
			PRIMARY KEY(`source`, `id`))");

			db.exec("CREATE TABLE IF NOT EXISTS `merges`(`merge` string not null, PRIMARY KEY(`merge`))");
		}
		
		public enum GAMES
		{
			SOURCE, ID, NAME, ICON, IMAGE, INSTALL_PATH, PLATFORMS, INFO, INFO_DETAILED;

			public int column()
			{
				switch(this)
				{
					case GAMES.SOURCE:			return 0;
					case GAMES.ID:				return 1;
					case GAMES.NAME:			return 2;
					case GAMES.ICON:			return 3;
					case GAMES.IMAGE:			return 4;
					case GAMES.INSTALL_PATH:	return 5;
					case GAMES.PLATFORMS:		return 6;
					case GAMES.INFO:			return 7;
					case GAMES.INFO_DETAILED:	return 8;
				}
				assert_not_reached();
			}

			public int column_for_bind()
			{
				return column() + 1;
			}

			public int bind(Statement s, string? str)
			{
				if(str == null) return bind_null(s);
				return s.bind_text(column_for_bind(), str);
			}
			public int bind_int(Statement s, int? i)
			{
				if(i == null) return bind_null(s);
				return s.bind_int(column_for_bind(), i);
			}
			public int bind_int64(Statement s, int64? i)
			{
				if(i == null) return bind_null(s);
				return s.bind_int64(column_for_bind(), i);
			}
			public int bind_value(Statement s, Sqlite.Value? v)
			{
				if(v == null) return bind_null(s);
				return s.bind_value(column_for_bind(), v);
			}
			public int bind_null(Statement s)
			{
				return s.bind_null(column_for_bind());
			}

			public string? get(Statement s)
			{
				return s.column_text(column());
			}
			public int? get_int(Statement s)
			{
				return s.column_int(column());
			}
			public int64? get_int64(Statement s)
			{
				return s.column_int64(column());
			}
			public unowned Sqlite.Value? get_value(Statement s)
			{
				return s.column_value(column());
			}
		}

		public bool add_game(Game game) requires (db != null)
		{
			Statement s;
			int res = db.prepare_v2("INSERT OR REPLACE INTO `games`
				(`source`, `id`, `name`, `icon`, `image`, `install_path`, `platforms`, `info`, `info_detailed`)
				VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", -1, out s);

			assert(res == Sqlite.OK);

			var platforms = "";
			foreach(var p in game.platforms)
			{
				if(platforms.length > 0) platforms += ",";
				platforms += p.id();
			}

			GAMES.SOURCE.bind(s, game.source.id);
			GAMES.ID.bind(s, game.id);
			GAMES.NAME.bind(s, game.name);
			GAMES.ICON.bind(s, game.icon);
			GAMES.IMAGE.bind(s, game.image);
			GAMES.INSTALL_PATH.bind(s, game.install_dir == null || !game.install_dir.query_exists() ? null : game.install_dir.get_path());
			GAMES.PLATFORMS.bind(s, platforms);
			GAMES.INFO.bind(s, game.info);
			GAMES.INFO_DETAILED.bind(s, game.info_detailed);

			res = s.step();

			return res == Sqlite.DONE;
		}
		
		public bool merge(Game first, Game second) requires (db != null)
		{
			Statement s;

			int res = db.prepare_v2("SELECT rowid, * FROM `merges` WHERE `merge` LIKE ? OR `merge` LIKE ?", -1, out s);
			assert(res == Sqlite.OK);

			s.bind_text(1, @"%$(first.source.id):$(first.id)%");
			s.bind_text(2, @"%$(second.source.id):$(second.id)%");

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
					if(game.source.id == src.id)
					{
						if(new_merge != "") new_merge += "|";
						new_merge += @"$(game.source.id):$(game.id)";
					}
				}
			}

			s.bind_text(merge_var, new_merge);

			debug("[GamesDB] Merging: " + new_merge);

			res = s.step();

			return res == Sqlite.DONE;
		}

		public Game? get_game(string src, string id) requires (db != null)
		{
			if(src == null || id == null) return null;

			Statement st;
			int res;

			res = db.prepare_v2("SELECT * FROM `games` WHERE `source` = ? AND `id` = ?", -1, out st);
			res = st.bind_text(1, src);
			res = st.bind_text(2, id);

			assert(res == Sqlite.OK);

			if((res = st.step()) == Sqlite.ROW)
			{
				var s = GameSource.by_id(GAMES.SOURCE.get(st));

				if(s is Steam)
				{
					return new SteamGame.from_db((Steam) s, st);
				}
				else if(s is GOG)
				{
					return new GOGGame.from_db((GOG) s, st);
				}
				else if(s is Humble)
				{
					return new HumbleGame.from_db((Humble) s, st);
				}
			}

			return null;
		}

		public ArrayList<Game> get_games(GameSource? src = null) requires (db != null)
		{
			Statement st;
			int res;
			
			if(src != null)
			{
				res = db.prepare_v2("SELECT * FROM `games` WHERE `source` = ?", -1, out st);
				res = st.bind_text(1, src.id);
			}
			else
			{
				res = db.prepare_v2("SELECT * FROM `games`", -1, out st);
			}
			
			assert(res == Sqlite.OK);
			
			var games = new ArrayList<Game>(Game.is_equal);
			
			while((res = st.step()) == Sqlite.ROW)
			{
				var s = GameSource.by_id(GAMES.SOURCE.get(st));
				
				if(s is Steam)
				{
					games.add(new SteamGame.from_db((Steam) s, st));
				}
				else if(s is GOG)
				{
					games.add(new GOGGame.from_db((GOG) s, st));
				}
				else if(s is Humble)
				{
					games.add(new HumbleGame.from_db((Humble) s, st));
				}
			}
			
			return games;
		}

		public ArrayList<Game>? get_merged_games(Game game) requires (db != null)
		{
			Statement s;

			int res = db.prepare_v2("SELECT * FROM `merges` WHERE `merge` LIKE ? LIMIT 1", -1, out s);
			s.bind_text(1, @"$(game.source.id):$(game.id)|%");

			assert(res == Sqlite.OK);

			while((res = s.step()) == Sqlite.ROW)
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

						var g = get_game(gsrc, gid);

						if(g != null && !games.contains(g) && !Game.is_equal(game, g)) games.add(g);
					}
				}

				return games;
			}

			return null;
		}
		
		public bool is_game_merged(Game game) requires (db != null)
		{
			Statement s;

			int res = db.prepare_v2("SELECT * FROM `merges` WHERE `merge` LIKE ? LIMIT 1", -1, out s);
			s.bind_text(1, @"%|$(game.source.id):$(game.id)%");

			assert(res == Sqlite.OK);

			return s.step() == Sqlite.ROW;
		}

		public bool is_game_merged_as_primary(Game game) requires (db != null)
		{
			Statement s;

			int res = db.prepare_v2("SELECT * FROM `merges` WHERE `merge` LIKE ? LIMIT 1", -1, out s);
			s.bind_text(1, @"$(game.source.id):$(game.id)|%");

			assert(res == Sqlite.OK);

			return s.step() == Sqlite.ROW;
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
