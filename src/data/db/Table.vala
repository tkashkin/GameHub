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

using Sqlite;

namespace GameHub.Data.DB
{
	public abstract class Table: Object
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
			public int bind_bool(Statement s, bool? b)
			{
				if(b == null) return bind_null(s);
				return s.bind_int(column_for_bind, b ? 1 : 0);
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
			public int get_int(Statement s)
			{
				return s.column_int(column);
			}
			public bool get_bool(Statement s)
			{
				return get_int(s) == 0 ? false : true;
			}
			public int64 get_int64(Statement s)
			{
				return s.column_int64(column);
			}
			public unowned Sqlite.Value? get_value(Statement s)
			{
				return s.column_value(column);
			}
		}

		protected static Table.Field f(int col)
		{
			return new Table.Field(col);
		}

		public abstract void migrate(Sqlite.Database db, int version);
		public virtual void init(Sqlite.Database db){}
	}
}
