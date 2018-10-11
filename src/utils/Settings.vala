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

using Gtk;
using GLib;
using Granite;

namespace GameHub.Settings
{
	public enum WindowState
	{
		NORMAL = 0,
		MAXIMIZED = 1,
		FULLSCREEN = 2
	}

	public enum GamesView
	{
		GRID = 0,
		LIST = 1
	}

	public class SavedState: Granite.Services.Settings
	{
		public int window_width { get; set; }
		public int window_height { get; set; }
		public WindowState window_state { get; set; }
		public int window_x { get; set; }
		public int window_y { get; set; }

		public GamesView games_view { get; set; }

		public SavedState()
		{
			base(ProjectConfig.PROJECT_NAME + ".saved-state");
		}

		private static SavedState? instance;
		public static unowned SavedState get_instance()
		{
			if(instance == null)
			{
				instance = new SavedState();
			}
			return instance;
		}
	}

	public class UI: Granite.Services.Settings
	{
		public bool dark_theme { get; set; }
		public bool compact_list { get; set; }

		public bool merge_games { get; set; }

		public bool show_unsupported_games { get; set; }
		public bool use_compat { get; set; }

		public UI()
		{
			base(ProjectConfig.PROJECT_NAME + ".ui");
		}

		private static UI? instance;
		public static unowned UI get_instance()
		{
			if(instance == null)
			{
				instance = new UI();
			}
			return instance;
		}
	}

	namespace Auth
	{
		public class Steam: Granite.Services.Settings
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


			private static Steam? instance;
			public static unowned Steam get_instance()
			{
				if(instance == null)
				{
					instance = new Steam();
				}
				return instance;
			}
		}

		public class GOG: Granite.Services.Settings
		{
			public bool enabled { get; set; }
			public bool authenticated { get; set; }
			public string access_token { get; set; }
			public string refresh_token { get; set; }

			public GOG()
			{
				base(ProjectConfig.PROJECT_NAME + ".auth.gog");
			}

			private static GOG? instance;
			public static unowned GOG get_instance()
			{
				if(instance == null)
				{
					instance = new GOG();
				}
				return instance;
			}
		}

		public class Humble: Granite.Services.Settings
		{
			public bool enabled { get; set; }
			public bool authenticated { get; set; }
			public string access_token { get; set; }

			public bool load_trove_games { get; set; }

			public Humble()
			{
				base(ProjectConfig.PROJECT_NAME + ".auth.humble");
			}

			private static Humble? instance;
			public static unowned Humble get_instance()
			{
				if(instance == null)
				{
					instance = new Humble();
				}
				return instance;
			}
		}
	}
}
