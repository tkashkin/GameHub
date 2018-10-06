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
using Granite;
using GameHub.UI.Windows;

namespace GameHub.UI.Views
{
	public abstract class BaseView: Grid
	{
		protected MainWindow window;
		protected HeaderBar titlebar;

		construct
		{
			titlebar = new HeaderBar();
			titlebar.title = "GameHub";
			titlebar.show_close_button = true;
		}

		public virtual void attach_to_window(MainWindow wnd)
		{
			window = wnd;
			show();
		}

		public virtual void on_show()
		{
			titlebar.show_all();
			window.set_titlebar(titlebar);
		}

		public virtual void on_window_focus()
		{

		}
	}
}
