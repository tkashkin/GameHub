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



namespace GameHub.Settings
{
	public class Tweaks: SettingsSchema
	{
		public string[] global { get; set; }

		public Tweaks()
		{
			base(ProjectConfig.PROJECT_NAME + ".tweaks");
		}

		private static Tweaks? _instance;
		public static unowned Tweaks instance
		{
			get
			{
				if(_instance == null)
				{
					_instance = new Tweaks();
				}
				return _instance;
			}
		}
	}
}
