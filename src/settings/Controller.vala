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

namespace GameHub.Settings
{
	public class Controller: SettingsSchema
	{
		public bool enabled { get; set; }
		public bool focus_window { get; set; }

		public string[] known_controllers { get; set; }
		public string[] ignored_controllers { get; set; }

		public Controller()
		{
			base(Config.RDNN + ".controller");
		}

		private static Controller? _instance;
		public static unowned Controller instance
		{
			get
			{
				if(_instance == null)
				{
					_instance = new Controller();
				}
				return _instance;
			}
		}
	}
}
