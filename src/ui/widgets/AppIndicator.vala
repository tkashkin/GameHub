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

using Gee;
using Gtk;
using AppIndicator;
using GameHub.Data;
using GameHub.Utils;
using GameHub.Data.Adapters;
using GameHub.UI.Views.GamesView;

namespace GameHub.UI.Widgets
{
    public class AppIndicator : Object
    {
        public static AppIndicator instance;
        private Indicator app_indicator;
        private const string APP_INDICATOR_ID = "gamehub.indicator";
        private GLib.List<unowned Window> visible_windows;
        private Gtk.Menu menu;

        private const int RECENT_GAMES_COUNT = 10;

        public bool visible {
            get { return app_indicator.get_status() == IndicatorStatus.ACTIVE; }
            set { app_indicator.set_status(value ? IndicatorStatus.ACTIVE : IndicatorStatus.PASSIVE); }
        }

        construct
        {
            app_indicator = new Indicator(APP_INDICATOR_ID, "com.github.tkashkin.gamehub", IndicatorCategory.APPLICATION_STATUS);
			app_indicator.set_status(IndicatorStatus.ACTIVE);
			app_indicator.set_title("GameHub");

            if (GamesView.instance != null)
            {
                connect_games_adapter(GamesView.instance.get_games_adapter());
            }
            else
            {
                setup_menu();
            }

            instance = this;
        }

        public static void set_games_adapter(GamesAdapter games_adapter) {
            if (instance != null) {
                instance.connect_games_adapter(games_adapter);
            }
        }

        private void connect_games_adapter(GamesAdapter games_adapter) {
            setup_menu(games_adapter.get_last_launched_games(RECENT_GAMES_COUNT));
            games_adapter.cache_loaded.connect(() => { setup_menu(games_adapter.get_last_launched_games(RECENT_GAMES_COUNT)); });
        }

        private void setup_menu(Gee.List<Game>? games = null)
        {
            menu = new Gtk.Menu();

			Gtk.ImageMenuItem show_item = new Gtk.ImageMenuItem.with_label("Show/Hide");
            Gtk.Image show_icon = new Gtk.Image.from_icon_name("games-config-tiles", IconSize.MENU);
            show_item.set_image(show_icon);
            show_item.activate.connect(show_hide);
            menu.append(show_item);

            if (games != null)
            {
                Gtk.SeparatorMenuItem separator_pre = new Gtk.SeparatorMenuItem();
                menu.append(separator_pre);
                foreach (Game game in games)
                {
                    Gtk.ImageMenuItem game_item = new Gtk.ImageMenuItem.with_label(game.name);

                    ImageCache.load(game.icon, @"games/$(game.source.id)/$(game.id)/icons/", (obj, res) =>
                    {
                        Gtk.Image game_icon = new Gtk.Image.from_pixbuf(ImageCache.load.end(res));
                        game_item.set_image(game_icon);
                    });

                    game_item.activate.connect(() => {
                        if (game.can_be_launched()) {
                            if(game.use_compat) {
                                game.run_with_compat.begin(true);
                            } else {
                                game.run.begin();
                            }
                        }
                    });
                    menu.append(game_item);
                }
                Gtk.SeparatorMenuItem separator_post = new Gtk.SeparatorMenuItem();
                menu.append(separator_post);
            }

            Gtk.ImageMenuItem quit_item = new Gtk.ImageMenuItem.with_label("Quit");
            Gtk.Image quit_icon = new Gtk.Image.from_icon_name("application-exit", IconSize.MENU);
            quit_item.set_image(quit_icon);
            quit_item.activate.connect(quit);
            menu.append(quit_item);
            
            menu.show_all();
            app_indicator.set_menu(menu);
        }

		private void show_hide()
		{
            GLib.List<unowned Window> active_windows = Gtk.Window.list_toplevels();
            bool is_main_window_visible = UI.Windows.MainWindow.instance.visible;

            if (is_main_window_visible)
            {
                visible_windows = new GLib.List<unowned Window>();
                active_windows.foreach ((window) =>
                {
                    if (window.visible && window.transient_for == UI.Windows.MainWindow.instance)
                    {
                        visible_windows.append(window);
                        window.visible = false;
                    }
                });
            }
            else
            {
                visible_windows.foreach((window) =>
                {
                    window.visible = true;
                });
            }
            UI.Windows.MainWindow.instance.visible = !is_main_window_visible;
		}

        private void quit()
        {
            visible = false;
            UI.Windows.MainWindow.instance.close();
        }
    }
}