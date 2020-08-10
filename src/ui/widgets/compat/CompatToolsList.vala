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

using Gtk;
using Gdk;
using Gee;

using GameHub.UI.Widgets;
using GameHub.UI.Widgets.Settings;

using GameHub.Data;
using GameHub.Data.Tweaks;
using GameHub.Data.Runnables;

namespace GameHub.UI.Widgets.Compat
{
	public class CompatToolsList: Notebook
	{
		public Runnable? runnable { get; construct; default = null; }

		public CompatToolsList(Runnable? runnable = null)
		{
			Object(runnable: runnable, show_border: false, expand: true, scrollable: true);
		}

		construct
		{
			update();
		}

		private void update()
		{
			this.foreach(w => w.destroy());

			append_page(new Box(Orientation.VERTICAL, 0), new Label("Wine"));
			append_page(new Box(Orientation.VERTICAL, 0), new Label("Proton"));
		}
	}
}
