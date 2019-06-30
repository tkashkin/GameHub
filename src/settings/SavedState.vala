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

using GameHub.Data.Adapters;

namespace GameHub.Settings.SavedState
{
	public class Window: SettingsSchema
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

	public class GamesView: SettingsSchema
	{
		public GamesView.Style style { get; set; }
		public GamesAdapter.SortMode sort_mode { get; set; }
		public GamesAdapter.GroupMode group_mode { get; set; }
		public string filter_source { get; set; }
		public GamesAdapter.PlatformFilter filter_platform { get; set; }

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
	}
}
