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

using GameHub.Data;
using GameHub.Data.DB;
using GameHub.Data.Tweaks;
using GameHub.Data.Runnables;

namespace GameHub.Data.Runnables.Traits.Game
{
	public interface SupportsTweaks: Runnables.Game
	{
		public abstract string[]? tweaks { get; set; default = null; }

		protected void dbinit_tweaks(Sqlite.Statement s)
		{
			var tweaks_string = Tables.Games.TWEAKS.get(s);
			if(tweaks_string != null)
			{
				tweaks = tweaks_string.split(",");
			}
		}

		public Tweak[] get_enabled_tweaks(CompatTool? tool=null)
		{
			Tweak[] enabled_tweaks = {};
			var all_tweaks = Tweak.load_tweaks();
			foreach(var tweak in all_tweaks.values)
			{
				if(tweak.is_enabled(this) && tweak.is_applicable_to(this, tool))
				{
					enabled_tweaks += tweak;
				}
			}
			return enabled_tweaks;
		}
	}
}
