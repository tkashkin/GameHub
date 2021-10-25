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



namespace GameHub.Settings.Providers
{
	namespace Images
	{
		public class SteamGridDB: SettingsSchema
		{
			public bool enabled { get; set; }
			public string api_key { get; set; }

			public SteamGridDB()
			{
				base(Config.RDNN + ".providers.images.steamgriddb");
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

			private static SteamGridDB? _instance;
			public static unowned SteamGridDB instance
			{
				get
				{
					if(_instance == null)
					{
						_instance = new SteamGridDB();
					}
					return _instance;
				}
			}
		}

		public class JinxSGVI: SettingsSchema
		{
			public bool enabled { get; set; }

			public JinxSGVI()
			{
				base(Config.RDNN + ".providers.images.jinx-sgvi");
			}

			private static JinxSGVI? _instance;
			public static unowned JinxSGVI instance
			{
				get
				{
					if(_instance == null)
					{
						_instance = new JinxSGVI();
					}
					return _instance;
				}
			}
		}

		public class Steam: SettingsSchema
		{
			public bool enabled { get; set; }

			public Steam()
			{
				base(Config.RDNN + ".providers.images.steam");
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
	}

	namespace Data
	{
		public class IGDB: SettingsSchema
		{
			public bool enabled { get; set; }
			public string api_key { get; set; }
			public PreferredDescription preferred_description { get; set; }

			public IGDB()
			{
				base(Config.RDNN + ".providers.data.igdb");
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

			private static IGDB? _instance;
			public static unowned IGDB instance
			{
				get
				{
					if(_instance == null)
					{
						_instance = new IGDB();
					}
					return _instance;
				}
			}

			public enum PreferredDescription
			{
				GAME = 0, IGDB = 1, BOTH = 2
			}
		}
	}
}
