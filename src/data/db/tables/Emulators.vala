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

using GameHub.Data;

namespace GameHub.Data.DB.Tables
{
	public class Emulators: Table
	{
		public static Emulators instance;

		public static Table.Field ID;
		public static Table.Field NAME;
		public static Table.Field INSTALL_PATH;
		public static Table.Field EXECUTABLE;
		public static Table.Field COMPAT_TOOL;
		public static Table.Field COMPAT_TOOL_SETTINGS;
		public static Table.Field ARGUMENTS;

		public Emulators()
		{
			instance             = this;

			ID                   = f(0);
			NAME                 = f(1);
			INSTALL_PATH         = f(2);
			EXECUTABLE           = f(3);
			COMPAT_TOOL          = f(4);
			COMPAT_TOOL_SETTINGS = f(5);
			ARGUMENTS            = f(6);
		}

		public override void migrate(Sqlite.Database db, int version)
		{
			for(int ver = version; ver < Database.VERSION; ver++)
			{
				switch(ver)
				{
					case 3:
						db.exec("CREATE TABLE `emulators`(
							`id`                   string not null,
							`name`                 string not null,
							`install_path`         string,
							`executable`           string,
							`compat_tool`          string,
							`compat_tool_settings` string,
							`arguments`            string,
						PRIMARY KEY(`id`))");
						break;
				}
			}
		}

		public static bool add(Emulator emu)
		{
			unowned Sqlite.Database? db = Database.instance.db;
			if(db == null) return false;

			Statement s;
			int res = db.prepare_v2("INSERT OR REPLACE INTO `emulators`(
					`id`,
					`name`,
					`install_path`,
					`executable`,
					`compat_tool`,
					`compat_tool_settings`,
					`arguments`)
				VALUES (?, ?, ?, ?, ?, ?, ?)", -1, out s);

			if(res != Sqlite.OK)
			{
				warning("[Database.Emulators.add] Can't prepare INSERT query (%d): %s", db.errcode(), db.errmsg());
				return false;
			}

			ID.bind(s, emu.id);
			NAME.bind(s, emu.name);
			EXECUTABLE.bind(s, emu.executable == null || !emu.executable.query_exists() ? null : emu.executable.get_path());
			INSTALL_PATH.bind(s, emu.install_dir == null || !emu.install_dir.query_exists() ? null : emu.install_dir.get_path());
			COMPAT_TOOL.bind(s, emu.compat_tool);
			COMPAT_TOOL_SETTINGS.bind(s, emu.compat_tool_settings);
			ARGUMENTS.bind(s, emu.arguments);

			res = s.step();

			if(res != Sqlite.DONE)
			{
				warning("[Database.Emulators.add] Error (%d): %s", db.errcode(), db.errmsg());
				return false;
			}

			return true;
		}

		public static bool remove(Emulator emu)
		{
			unowned Sqlite.Database? db = Database.instance.db;
			if(db == null) return false;

			Statement s;
			int res = db.prepare_v2("DELETE FROM `emulators` WHERE `id` = ?", -1, out s);

			if(res != Sqlite.OK)
			{
				warning("[Database.Emulators.remove] Can't prepare DELETE query (%d): %s", db.errcode(), db.errmsg());
				return false;
			}

			res = s.bind_text(1, emu.id);

			res = s.step();

			if(res != Sqlite.DONE)
			{
				warning("[Database.Emulators.remove] Error (%d): %s", db.errcode(), db.errmsg());
				return false;
			}

			return true;
		}

		public static new Emulator? get(string id)
		{
			if(id == null) return null;

			unowned Sqlite.Database? db = Database.instance.db;
			if(db == null) return null;

			Statement st;
			int res = db.prepare_v2("SELECT * FROM `emulators` WHERE `id` = ?", -1, out st);

			if(res != Sqlite.OK)
			{
				warning("[Database.Emulators.get] Can't prepare SELECT query (%d): %s", db.errcode(), db.errmsg());
				return null;
			}

			res = st.bind_text(1, id);

			if((res = st.step()) == Sqlite.ROW)
			{
				return new Emulator.from_db(st);
			}

			return null;
		}

		public static Emulator? by_name(string name)
		{
			if(name == null) return null;

			unowned Sqlite.Database? db = Database.instance.db;
			if(db == null) return null;

			Statement st;
			int res = db.prepare_v2("SELECT * FROM `emulators` WHERE `name` = ?", -1, out st);

			if(res != Sqlite.OK)
			{
				warning("[Database.Emulators.get] Can't prepare SELECT query (%d): %s", db.errcode(), db.errmsg());
				return null;
			}

			res = st.bind_text(1, name);

			if((res = st.step()) == Sqlite.ROW)
			{
				return new Emulator.from_db(st);
			}

			return null;
		}

		public static ArrayList<Emulator>? get_all()
		{
			unowned Sqlite.Database? db = Database.instance.db;
			if(db == null) return null;

			Statement st;
			int res = db.prepare_v2("SELECT * FROM `emulators` ORDER BY `name` ASC", -1, out st);

			if(res != Sqlite.OK)
			{
				warning("[Database.Emulators.get_all] Can't prepare SELECT query (%d): %s", db.errcode(), db.errmsg());
				return null;
			}

			var emus = new ArrayList<Emulator>(Emulator.is_equal);

			while((res = st.step()) == Sqlite.ROW)
			{
				emus.add(new Emulator.from_db(st));
			}

			return emus;
		}
	}
}
