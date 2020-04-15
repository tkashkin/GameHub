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
using GameHub.Data.Runnables;

namespace GameHub.Data.Runnables.Traits.Game
{
	public interface HasAchievements: Runnables.Game
	{
		public abstract ArrayList<Achievement>? achievements { get; protected set; default = null; }
		public virtual async ArrayList<Achievement>? load_achievements() { return null; }

		public abstract class Achievement
		{
			public string    id                { get; protected set; }
			public string    name              { get; protected set; }
			public string    description       { get; protected set; }
			public bool      unlocked          { get; protected set; default = false; }
			public DateTime? unlock_date       { get; protected set; default = null; }
			public string?   unlock_time       { get; protected set; default = null; }
			public float     global_percentage { get; protected set; default = 0; }
			public string?   image_locked      { get; protected set; default = null; }
			public string?   image_unlocked    { get; protected set; default = null; }
			public string?   image             { get { return unlocked ? image_unlocked : image_locked; } }
		}
	}
}
