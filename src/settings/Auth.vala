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

namespace GameHub.Settings.Auth
{
	public class Steam: SettingsSchema
	{
		public bool enabled { get; set; }
		public bool authenticated { get; set; }
		public string api_key { get; set; }

		public Steam()
		{
			base(ProjectConfig.PROJECT_NAME + ".auth.steam");
		}

		protected override void verify(string key)
		{
			switch(key)
			{
				case "api-key":
					if(api_key.length != 32)
					{
						schema.reset("api-key");
					}
					break;
			}
		}

		private static Steam? _instance;
		public static unowned Steam instance
		{
			get
			{
				if(_instance == null)
				{
					_instance = new Steam();
				}
				return _instance;
			}
		}
	}

	public class EpicGames: SettingsSchema
	{
		public bool enabled { get; set; }
		public bool authenticated { get; set; }
		public string sid { get; set; }

		public EpicGames()
		{
			base(ProjectConfig.PROJECT_NAME + ".auth.epicgames");
		}

		private static EpicGames? _instance;
		public static unowned EpicGames instance
		{
			get
			{
				if(_instance == null)
				{
					_instance = new EpicGames();
				}
				return _instance;
			}
		}
	}

	public class GOG: SettingsSchema
	{
		public bool enabled { get; set; }
		public bool authenticated { get; set; }
		public string access_token { get; set; }
		public string refresh_token { get; set; }

		public GOG()
		{
			base(ProjectConfig.PROJECT_NAME + ".auth.gog");
		}

		private static GOG? _instance;
		public static unowned GOG instance
		{
			get
			{
				if(_instance == null)
				{
					_instance = new GOG();
				}
				return _instance;
			}
		}
	}

	public class Humble: SettingsSchema
	{
		public bool enabled { get; set; }
		public bool authenticated { get; set; }
		public string access_token { get; set; }

		public bool load_trove_games { get; set; }

		public Humble()
		{
			base(ProjectConfig.PROJECT_NAME + ".auth.humble");
		}

		private static Humble? _instance;
		public static unowned Humble instance
		{
			get
			{
				if(_instance == null)
				{
					_instance = new Humble();
				}
				return _instance;
			}
		}
	}

	public class Itch: SettingsSchema
	{
		public bool enabled { get; set; }
		public bool authenticated { get; set; }
		public string api_key { get; set; }

		public Itch()
		{
			base(ProjectConfig.PROJECT_NAME + ".auth.itch");
		}

		private static Itch? _instance;
		public static unowned Itch instance
		{
			get
			{
				if(_instance == null)
				{
					_instance = new Itch();
				}
				return _instance;
			}
		}
	}
}
