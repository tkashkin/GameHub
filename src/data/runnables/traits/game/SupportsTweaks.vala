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
using GameHub.Utils;

namespace GameHub.Data.Runnables.Traits.Game
{
	public interface SupportsTweaks: Runnables.Game
	{
		public abstract TweakSet? tweaks { get; set; default = null; }

		protected void init_tweaks()
		{
			tweaks = new TweakSet.from_json(false, null);
			_tweaks_init();
		}

		protected void dbinit_tweaks(Sqlite.Statement s)
		{
			tweaks = new TweakSet.from_json(false, Parser.parse_json(Tables.Games.TWEAKS.get(s)));
			_tweaks_init();
		}

		private void _tweaks_init()
		{
			tweaks.changed.connect(() => {
				save();
			});
		}
	}
}
