/*
This file is part of GameHub.
Copyright (C) Anatoliy Kashkin

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

using GameHub.Data;
using GameHub.Data.Compat;
using GameHub.Data.Compat.Tools;

namespace GameHub.Data.DB.Tables
{
	public class CompatTools: Table
	{
		public static CompatTools instance;

		public static Table.Field TOOL;
		public static Table.Field ID;
		public static Table.Field NAME;
		public static Table.Field EXECUTABLE;
		public static Table.Field INFO;
		public static Table.Field OPTIONS;

		public CompatTools()
		{
			instance   = this;

			TOOL       = f(0);
			ID         = f(1);
			NAME       = f(2);
			EXECUTABLE = f(3);
			INFO       = f(4);
			OPTIONS    = f(5);
		}

		public override void migrate(Sqlite.Database db, int version)
		{
			for(int ver = version; ver < Database.VERSION; ver++)
			{
				switch(ver)
				{
					case 11:
						db.exec("CREATE TABLE `compat_tools`(
							`tool`       string not null,
							`id`         string not null,
							`name`       string not null,
							`executable` string,
							`info`       string,
							`options`    string,
						PRIMARY KEY(`tool`, `id`))");
						break;
				}
			}
		}

		public static bool add(CompatTool tool)
		{
			unowned Sqlite.Database? db = Database.instance.db;
			if(db == null) return false;

			Statement s;
			int res = db.prepare_v2("INSERT OR REPLACE INTO `compat_tools`(
					`tool`,
					`id`,
					`name`,
					`executable`,
					`info`,
					`options`)
				VALUES (?, ?, ?, ?, ?, ?)", -1, out s);

			if(res != Sqlite.OK)
			{
				warning("[Database.CompatTools.add] Can't prepare INSERT query (%d): %s", db.errcode(), db.errmsg());
				return false;
			}

			TOOL.bind(s, tool.tool);
			ID.bind(s, tool.id);
			NAME.bind(s, tool.name);
			EXECUTABLE.bind(s, tool.executable.get_path());
			INFO.bind(s, tool.info);
			OPTIONS.bind(s, tool.options);

			res = s.step();

			if(res != Sqlite.DONE)
			{
				warning("[Database.CompatTools.add] Error (%d): %s", db.errcode(), db.errmsg());
				return false;
			}

			return true;
		}

		public static ArrayList<CompatTool>? get_all(string tool)
		{
			unowned Sqlite.Database? db = Database.instance.db;
			if(db == null) return null;

			Statement s;
			int res = db.prepare_v2("SELECT * FROM `compat_tools` WHERE `tool` = ?", -1, out s);

			if(res != Sqlite.OK)
			{
				warning("[Database.CompatTools.get_all] Can't prepare SELECT query (%d): %s", db.errcode(), db.errmsg());
				return null;
			}

			res = s.bind_text(1, tool);

			var tools = new ArrayList<CompatTool>();
			while((res = s.step()) == Sqlite.ROW)
			{
				switch(tool)
				{
					case "wine":
						tools.add(new Tools.Wine.Wine.from_db(s));
						break;
					case "proton":
						tools.add(new Tools.Proton.Proton.from_db(s));
						break;
					case "steamct":
						tools.add(new Tools.SteamCompatTool.from_db(s));
						break;
				}
			}
			return tools;
		}
	}
}
