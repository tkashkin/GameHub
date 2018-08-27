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

			// current db format

			Tables.Games.init(db);
			Tables.Tags.init(db);

			db.exec("CREATE TABLE IF NOT EXISTS `merges`(`merge` string not null, PRIMARY KEY(`merge`))");
		}
		
		public class Tables
		{
			public abstract class DBTable
			{
				public class Field
				{
					public int column = 0;
					public int column_for_bind = 0;
					public Field(int col)
					{
						column = col;
						column_for_bind = col + 1;
					}

					public int bind(Statement s, string? str)
					{
						if(str == null) return bind_null(s);
						return s.bind_text(column_for_bind, str);
					}
					public int bind_int(Statement s, int? i)
					{
						if(i == null) return bind_null(s);
						return s.bind_int(column_for_bind, i);
					}
					public int bind_int64(Statement s, int64? i)
					{
						if(i == null) return bind_null(s);
						return s.bind_int64(column_for_bind, i);
					}
					public int bind_value(Statement s, Sqlite.Value? v)
					{
						if(v == null) return bind_null(s);
						return s.bind_value(column_for_bind, v);
					}
					public int bind_null(Statement s)
					{
						return s.bind_null(column_for_bind);
					}

					public string? get(Statement s)
					{
						return s.column_text(column);
					}
					public int? get_int(Statement s)
					{
						return s.column_int(column);
					}
					public int64? get_int64(Statement s)
					{
						return s.column_int64(column);
					}
					public unowned Sqlite.Value? get_value(Statement s)
					{
						return s.column_value(column);
					}
				}

				protected static DBTable.Field f(int col)
				{
					return new DBTable.Field(col);
				}
			}

			public class Games: DBTable
			{
				public static DBTable.Field SOURCE;
				public static DBTable.Field ID;
				public static DBTable.Field NAME;
				public static DBTable.Field ICON;
				public static DBTable.Field IMAGE;
				public static DBTable.Field INSTALL_PATH;
				public static DBTable.Field PLATFORMS;
				public static DBTable.Field INFO;
				public static DBTable.Field INFO_DETAILED;
				public static DBTable.Field TAGS;

				public static void init(Database? db) requires (db != null)
				{
					Statement s;
					if(db.prepare_v2("SELECT `platforms` FROM `games`", -1, out s) != Sqlite.OK)
					{
						db.exec("DROP TABLE `games`");
					}

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
						`tags` string,
					PRIMARY KEY(`source`, `id`))");

					if(db.prepare_v2("SELECT `tags` FROM `games`", -1, out s) != Sqlite.OK)
					{
						db.exec("ALTER TABLE `games` ADD `tags` string");
					}

					SOURCE        = f(0);
					ID            = f(1);
					NAME          = f(2);
					ICON          = f(3);
					IMAGE         = f(4);
					INSTALL_PATH  = f(5);
					PLATFORMS     = f(6);
					INFO          = f(7);
					INFO_DETAILED = f(8);
					TAGS          = f(9);
				}
			}

			public class Tags: DBTable
			{
				public static DBTable.Field ID;
				public static DBTable.Field NAME;
				public static DBTable.Field ICON;

				public static ArrayList<Tag> TAGS;

				public class Tag: Object
				{
					public const string BUILTIN_PREFIX = "builtin:";

					public enum Builtin
					{
						FAVORITES, HIDDEN;

						public string id()
						{
							switch(this)
							{
								case Builtin.FAVORITES: return "favorites";
								case Builtin.HIDDEN:    return "hidden";
							}
							assert_not_reached();
						}

						public string name()
						{
							switch(this)
							{
								case Builtin.FAVORITES: return _("Favorites");
								case Builtin.HIDDEN:    return _("Hidden");
							}
							assert_not_reached();
						}

						public string icon()
						{
							switch(this)
							{
								case Builtin.FAVORITES: return "user-bookmarks-symbolic";
								case Builtin.HIDDEN:    return "window-close-symbolic";
							}
							assert_not_reached();
						}
					}

					public string? id { get; construct set; }
					public string? name { get; construct set; }
					public string icon { get; construct; }

					public Tag(string? id, string? name, string icon="tag-symbolic")
					{
						Object(id: id, name: name, icon: icon);
					}
					public Tag.from_db(Statement s)
					{
						this(ID.get(s), NAME.get(s), ICON.get(s));
					}
					public Tag.from_builtin(Builtin t)
					{
						this(BUILTIN_PREFIX + t.id(), t.name(), t.icon());
					}

					public static bool is_equal(Tag first, Tag second)
					{
						return first == second || first.id == second.id;
					}
				}

				public static void init(Database? db) requires (db != null)
				{
					db.exec("CREATE TABLE IF NOT EXISTS `tags`(`id` string, `name` string, `icon` string, PRIMARY KEY(`id`))");

					ID            = f(0);
					NAME          = f(1);
					ICON          = f(2);

					TAGS = new ArrayList<Tag>(Tag.is_equal);
					TAGS.add(new Tag.from_builtin(Tag.Builtin.FAVORITES));
					TAGS.add(new Tag.from_builtin(Tag.Builtin.HIDDEN));

					foreach(var t in TAGS)
					{
						GamesDB.get_instance().add_tag(t);
					}

					Statement s;
					int res = db.prepare_v2("SELECT * FROM `tags`", -1, out s);
					while((res = s.step()) == Sqlite.ROW)
					{
						var tag = new Tag.from_db(s);
						if(!TAGS.contains(tag)) TAGS.add(tag);
					}
				}
			}
		}

		public bool add_game(Game game) requires (db != null)
		{
			if(game is Sources.GOG.GOGGame.DLC) return false;

			Statement s;
			int res = db.prepare_v2("INSERT OR REPLACE INTO `games`
				(`source`, `id`, `name`, `icon`, `image`, `install_path`, `platforms`, `info`, `info_detailed`, `tags`)
				VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", -1, out s);

			assert(res == Sqlite.OK);

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

			Tables.Games.SOURCE.bind(s, game.source.id);
			Tables.Games.ID.bind(s, game.id);
			Tables.Games.NAME.bind(s, game.name);
			Tables.Games.ICON.bind(s, game.icon);
			Tables.Games.IMAGE.bind(s, game.image);
			Tables.Games.INSTALL_PATH.bind(s, game.install_dir == null || !game.install_dir.query_exists() ? null : game.install_dir.get_path());
			Tables.Games.PLATFORMS.bind(s, platforms);
			Tables.Games.INFO.bind(s, game.info);
			Tables.Games.INFO_DETAILED.bind(s, game.info_detailed);
			Tables.Games.TAGS.bind(s, tags);

			res = s.step();

			return res == Sqlite.DONE;
		}

		public bool add_tag(Tables.Tags.Tag tag) requires (db != null)
		{
			Statement s;
			int res = db.prepare_v2("INSERT OR REPLACE INTO `tags` (`id`, `name`, `icon`) VALUES (?, ?, ?)", -1, out s);

			assert(res == Sqlite.OK);

			Tables.Tags.ID.bind(s, tag.id);
			Tables.Tags.NAME.bind(s, tag.name);
			Tables.Tags.ICON.bind(s, tag.icon);

			res = s.step();

			if(!Tables.Tags.TAGS.contains(tag)) Tables.Tags.TAGS.add(tag);

			return res == Sqlite.DONE;
		}
		
		public bool merge(Game first, Game second) requires (db != null)
		{
			if(first is Sources.GOG.GOGGame.DLC || second is Sources.GOG.GOGGame.DLC) return false;

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
				var s = GameSource.by_id(Tables.Games.SOURCE.get(st));

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
				res = db.prepare_v2("SELECT * FROM `games` WHERE `source` = ? ORDER BY `name` ASC", -1, out st);
				res = st.bind_text(1, src.id);
			}
			else
			{
				res = db.prepare_v2("SELECT * FROM `games` ORDER BY `name` ASC", -1, out st);
			}
			
			assert(res == Sqlite.OK);
			
			var games = new ArrayList<Game>(Game.is_equal);
			
			while((res = st.step()) == Sqlite.ROW)
			{
				var s = GameSource.by_id(Tables.Games.SOURCE.get(st));
				
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
