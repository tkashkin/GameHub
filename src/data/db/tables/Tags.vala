using Gee;
using Sqlite;

using GameHub.Utils;

using GameHub.Data.Sources.Steam;
using GameHub.Data.Sources.GOG;
using GameHub.Data.Sources.Humble;

namespace GameHub.Data.DB.Tables
{
	public class Tags: Table
	{
		public static Tags instance;

		public static Table.Field ID;
		public static Table.Field NAME;
		public static Table.Field ICON;
		public static Table.Field SELECTED;

		public static ArrayList<Tag> TAGS;

		public static Tag BUILTIN_FAVORITES;
		public static Tag BUILTIN_INSTALLED;
		public static Tag BUILTIN_HIDDEN;

		public signal void tags_updated();

		public Tags()
		{
			instance = this;

			ID       = f(0);
			NAME     = f(1);
			ICON     = f(2);
			SELECTED = f(3);

			TAGS = new ArrayList<Tag>(Tag.is_equal);
		}

		public override void migrate(Sqlite.Database db, int version)
		{
			switch(version)
			{
				case 0:
					debug("%d", version);
					db.exec("CREATE TABLE `tags`(
						`id` string,
						`name` string,
						`icon` string,
						`selected` int,
					PRIMARY KEY(`id`))");
					migrate(db, 1);
					break;
			}
		}

		public override void init(Sqlite.Database db)
		{
			Statement s;

			int res = db.prepare_v2("SELECT * FROM `tags` ORDER BY SUBSTR(`id`, 1, 1) ASC, `name` ASC", -1, out s);
			while((res = s.step()) == Sqlite.ROW)
			{
				var tag = new Tag.from_db(s);
				if(!TAGS.contains(tag)) TAGS.add(tag);

				if(BUILTIN_FAVORITES == null && tag.id == Tag.BUILTIN_PREFIX + Tag.Builtin.FAVORITES.id()) BUILTIN_FAVORITES = tag;
				if(BUILTIN_INSTALLED == null && tag.id == Tag.BUILTIN_PREFIX + Tag.Builtin.INSTALLED.id()) BUILTIN_INSTALLED = tag;
				if(BUILTIN_HIDDEN == null && tag.id == Tag.BUILTIN_PREFIX + Tag.Builtin.HIDDEN.id()) BUILTIN_HIDDEN = tag;
			}

			Tag.Builtin[] builtin = { Tag.Builtin.FAVORITES, Tag.Builtin.INSTALLED, Tag.Builtin.HIDDEN };

			foreach(var bt in builtin)
			{
				var tag = new Tag.from_builtin(bt);
				Tags.add(tag);

				if(BUILTIN_FAVORITES == null && tag.id == Tag.BUILTIN_PREFIX + Tag.Builtin.FAVORITES.id()) BUILTIN_FAVORITES = tag;
				if(BUILTIN_INSTALLED == null && tag.id == Tag.BUILTIN_PREFIX + Tag.Builtin.INSTALLED.id()) BUILTIN_INSTALLED = tag;
				if(BUILTIN_HIDDEN == null && tag.id == Tag.BUILTIN_PREFIX + Tag.Builtin.HIDDEN.id()) BUILTIN_HIDDEN = tag;
			}

			tags_updated();
		}

		public static bool add(Tag tag, bool replace=false)
		{
			unowned Sqlite.Database? db = Database.instance.db;
			if(db == null) return false;

			Statement s;
			int res = db.prepare_v2("INSERT OR " + (replace ? "REPLACE" : "IGNORE") + " INTO `tags` (`id`, `name`, `icon`, `selected`) VALUES (?, ?, ?, ?)", -1, out s);

			if(res != Sqlite.OK)
			{
				warning("[Database.Tags.add] Can't prepare INSERT query (%d): %s", db.errcode(), db.errmsg());
				return false;
			}

			ID.bind(s, tag.id);
			NAME.bind(s, tag.name);
			ICON.bind(s, tag.icon);
			SELECTED.bind_bool(s, tag.selected);

			res = s.step();

			if(!TAGS.contains(tag))
			{
				TAGS.add(tag);
				instance.tags_updated();
			}

			if(res != Sqlite.DONE)
			{
				warning("[Database.Tags.add] Error (%d): %s", db.errcode(), db.errmsg());
				return false;
			}

			return true;
		}

		public class Tag: Object
		{
			public const string BUILTIN_PREFIX = "builtin:";
			public const string USER_PREFIX    = "user:";

			public enum Builtin
			{
				FAVORITES, INSTALLED, HIDDEN;

				public string id()
				{
					switch(this)
					{
						case Builtin.FAVORITES: return "favorites";
						case Builtin.INSTALLED: return "installed";
						case Builtin.HIDDEN:    return "hidden";
					}
					assert_not_reached();
				}

				public string name()
				{
					switch(this)
					{
						case Builtin.FAVORITES: return C_("tag", "Favorites");
						case Builtin.INSTALLED: return C_("tag", "Installed");
						case Builtin.HIDDEN:    return C_("tag", "Hidden");
					}
					assert_not_reached();
				}

				public string icon()
				{
					switch(this)
					{
						case Builtin.FAVORITES: return "gh-tag-favorites-symbolic";
						case Builtin.INSTALLED: return "gh-tag-symbolic";
						case Builtin.HIDDEN:    return "gh-tag-hidden-symbolic";
					}
					assert_not_reached();
				}
			}

			public string? id { get; construct set; }
			public string? name { get; construct set; }
			public string icon { get; construct set; }
			public bool selected { get; construct set; default = true; }

			public Tag(string? id, string? name, string icon="gh-tag-symbolic", bool selected=true)
			{
				Object(id: id, name: name, icon: icon, selected: selected);
			}
			public Tag.from_db(Statement s)
			{
				this(ID.get(s), NAME.get(s), ICON.get(s), SELECTED.get_bool(s));
			}
			public Tag.from_builtin(Builtin t)
			{
				this(BUILTIN_PREFIX + t.id(), t.name(), t.icon(), true);
			}
			public Tag.from_name(string name)
			{
				this(USER_PREFIX + Utils.md5(name), name);
			}

			public static bool is_equal(Tag first, Tag second)
			{
				return first == second || first.id == second.id;
			}
		}
	}
}
