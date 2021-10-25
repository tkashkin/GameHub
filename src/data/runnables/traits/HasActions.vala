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

using GameHub.Data;
using GameHub.Data.Compat;
using GameHub.Data.DB;
using GameHub.Data.Runnables;
using GameHub.Utils;

namespace GameHub.Data.Runnables.Traits
{
	public interface HasActions: Runnable
	{
		public abstract ArrayList<Action>? actions { get; protected set; default = null; }

		public abstract class Action
		{
			public HasActions runnable     { get; protected set; }

			public bool       is_primary   { get; protected set; default = false; }
			public bool       is_hidden    { get; protected set; default = false; }
			public string     name         { get; protected set; }
			public File?      file         { get; protected set; }
			public File?      workdir      { get; protected set; }
			public string?    args         { get; protected set; }
			public Type?[]    compat_tools { get; protected set; default = { null }; }
			public string?    uri          { get; protected set; }

			public bool is_available(CompatTool? tool=null)
			{
				if(file == null && uri != null)
				{
					return true;
				}

				if(tool == null)
				{
					return compat_tools.length == 0 || compat_tools[0] == null;
				}

				var t = tool.get_type();

				foreach(var type in compat_tools)
				{
					if(type != null && t.is_a(type))
					{
						return true;
					}
				}

				return false;
			}

			public async void invoke(CompatTool? tool=null)
			{
				if(file == null && uri != null)
				{
					Utils.open_uri(uri);
					return;
				}

				var runnable = runnable.cast<Traits.SupportsCompatTools>();
				/*if(runnable != null && is_available(tool) && tool.can_run_action(runnable, this))
				{
					yield tool.run_action(runnable, this);
				}*/
			}
		}
	}
}
