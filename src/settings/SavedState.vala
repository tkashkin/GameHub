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

using Granite;

namespace GameHub.Settings.SavedState
{
	public class Window: Granite.Services.Settings
	{
		public int width { get; set; }
		public int height { get; set; }
		public Window.State state { get; set; }
		public int x { get; set; }
		public int y { get; set; }

		public Window()
		{
			base(ProjectConfig.PROJECT_NAME + ".saved-state.window");
		}

		private static Window? _instance;
		public static unowned Window instance
		{
			get
			{
				if(_instance == null)
				{
					_instance = new Window();
				}
				return _instance;
			}
		}

		public enum State
		{
			NORMAL = 0, MAXIMIZED = 1, FULLSCREEN = 2
		}
	}

	public class GamesView: Granite.Services.Settings
	{
		public GamesView.Style style { get; set; }
		public GamesView.SortMode sort_mode { get; set; }
		public string filter_source { get; set; }
		public GamesView.PlatformFilter filter_platform { get; set; }

		public GamesView()
		{
			base(ProjectConfig.PROJECT_NAME + ".saved-state.games-view");
		}

		private static GamesView? _instance;
		public static unowned GamesView instance
		{
			get
			{
				if(_instance == null)
				{
					_instance = new GamesView();
				}
				return _instance;
			}
		}

		public enum Style
		{
			GRID = 0, LIST = 1
		}

		public enum SortMode
		{
			NAME = 0, LAST_LAUNCH = 1, PLAYTIME = 2;

			public string name()
			{
				switch(this)
				{
					case SortMode.NAME:        return C_("sort_mode", "By name");
					case SortMode.LAST_LAUNCH: return C_("sort_mode", "By last launch");
					case SortMode.PLAYTIME:    return C_("sort_mode", "By playtime");
				}
				assert_not_reached();
			}

			public string icon()
			{
				switch(this)
				{
					case SortMode.NAME:        return "insert-text-symbolic";
					case SortMode.LAST_LAUNCH: return "document-open-recent-symbolic";
					case SortMode.PLAYTIME:    return "preferences-system-time-symbolic";
				}
				assert_not_reached();
			}
		}

		public enum PlatformFilter
		{
			ALL = 0, LINUX = 1, WINDOWS = 2, MACOS = 3, EMULATED = 4;

			public const PlatformFilter[] FILTERS = { PlatformFilter.ALL, PlatformFilter.LINUX, PlatformFilter.WINDOWS, PlatformFilter.MACOS, PlatformFilter.EMULATED };

			public Data.Platform platform()
			{
				switch(this)
				{
					case PlatformFilter.LINUX:    return Data.Platform.LINUX;
					case PlatformFilter.WINDOWS:  return Data.Platform.WINDOWS;
					case PlatformFilter.MACOS:    return Data.Platform.MACOS;
					case PlatformFilter.EMULATED: return Data.Platform.EMULATED;
				}
				assert_not_reached();
			}
		}
	}
}
