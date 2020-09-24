/*
This file is part of GameHub.
Copyright(C) 2018-2019 Anatoliy Kashkin

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

/* Based on Granite.Widgets.AlertView */

using Gtk;
using AppIndicator;

namespace GameHub.UI.Widgets
{
    public class AppIndicator : Object
    {
        private Indicator appIndicator;
        private const string APP_INDICATOR_ID = "gamehub.indicator";
        List<unowned Window> visibleWindows;

        construct
        {
            appIndicator = new Indicator(APP_INDICATOR_ID, "gamehub-symbolic", IndicatorCategory.APPLICATION_STATUS);
			appIndicator.set_status(IndicatorStatus.ACTIVE);
			appIndicator.set_title("GameHub");

            Gtk.Menu menu = new Gtk.Menu();
            
			Gtk.ImageMenuItem show_item = new Gtk.ImageMenuItem();
			show_item.set_label("Show/Hide");
            show_item.activate.connect(show_hide);
            Gtk.ImageMenuItem quit_item = new Gtk.ImageMenuItem();
            quit_item.set_label("Quit");
            quit_item.activate.connect(quit);
            
            menu.append(show_item);
            menu.append(quit_item);
			menu.show_all();

            appIndicator.set_menu(menu);
        }

		private void show_hide()
		{
            List<unowned Window> activeWindows = Gtk.Window.list_toplevels();
            bool isMainWindowVisible = UI.Windows.MainWindow.instance.visible;

            if (isMainWindowVisible)
            {
                visibleWindows = new List<unowned Window>();
                activeWindows.foreach ((window) =>
                {
                    if (window.visible && window.transient_for == UI.Windows.MainWindow.instance)
                    {
                        visibleWindows.append(window);
                        window.visible = false;
                    }
                });
            }
            else
            {
                visibleWindows.foreach((window) =>
                {
                    window.visible = true;
                });
            }
            UI.Windows.MainWindow.instance.visible = !isMainWindowVisible;
		}

        private void quit()
        {
            UI.Windows.MainWindow.instance.close();
        }
    }
}