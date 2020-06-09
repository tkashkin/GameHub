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

using GameHub.Data;
using GameHub.Data.DB;
using GameHub.Utils;
using GameHub.UI.Widgets;

namespace GameHub.UI.Views.GameDetailsView
{
	public class MultipleGamesDetailsView: Grid
	{
		public signal void download_images(ArrayList<Game> games);

		private ArrayList<Game>? _games;
		public ArrayList<Game>? games
		{
			get { return _games; }
			set
			{
				_games = value;
				Idle.add(() => {
					update();
					return Source.REMOVE;
				});
			}
		}

		private Label header;
		private Box actions;
		private GameTagsList tags;

		private ArrayList<Game>? installable;
		private ArrayList<Game>? downloadable;
		private ArrayList<Game>? no_images;
		private ArrayList<Game>? uninstallable;
		private ArrayList<Game>? refreshable;

		public MultipleGamesDetailsView(ArrayList<Game>? games=null)
		{
			Object(games: games);
		}

		construct
		{
			header = Styled.H2Label(null);
			header.halign = Align.START;
			header.wrap = true;
			header.xalign = 0;
			header.hexpand = true;
			header.margin = 24;

			var actions_wrapper = new Box(Orientation.VERTICAL, 0);
			actions_wrapper.expand = true;

			actions = new Box(Orientation.VERTICAL, 0);
			actions.margin = 16;
			actions.margin_top = 0;

			actions_wrapper.add(actions);

			tags = new GameTagsList();
			tags.get_style_context().add_class(Gtk.STYLE_CLASS_VIEW);
			tags.width_request = 200;
			tags.hexpand = false;

			attach(header, 0, 0);
			attach(actions_wrapper, 0, 1);
			attach(new Separator(Orientation.VERTICAL), 1, 0, 1, 2);
			attach(tags, 2, 0, 1, 2);

			show_all();
		}

		private void update()
		{
			if(games == null) return;

			tags.games = games;

			header.label = ngettext("%d game selected", "%d games selected", games.size).printf(games.size);

			actions.foreach(w => w.destroy());

			installable = new ArrayList<Game>();
			downloadable = new ArrayList<Game>();
			no_images = new ArrayList<Game>();
			uninstallable = new ArrayList<Game>();
			refreshable = new ArrayList<Game>();

			foreach(var g in games)
			{
				if(g.status.state == Game.State.INSTALLED)
				{
					uninstallable.add(g);
				}
				else
				{
					if(!(g is Sources.User.UserGame))
					{
						refreshable.add(g);
						if(g.is_installable)
						{
							if(g.status.state == Game.State.UNINSTALLED)
							{
								installable.add(g);
							}
							if(!(g is Sources.Steam.SteamGame))
							{
								downloadable.add(g);
							}
						}
					}
				}
				if(g.image == null)
				{
					no_images.add(g);
				}
			}

			if(installable.size > 0)
			{
				add_action_separator();
				var action_install = add_action("go-down", null, _("Install"), install_games);
				action_install.text += "\n" + """<span size="smaller">%s</span>""".printf(ngettext("%d game will be installed", "%d games will be installed", installable.size).printf(installable.size));
			}

			if(downloadable.size > 0)
			{
				if(installable.size == 0)
				{
					add_action_separator();
				}
				var action_download = add_action("folder-download", null, _("Download"), download_games);
				action_download.text += "\n" + """<span size="smaller">%s</span>""".printf(ngettext("%d game will be downloaded", "%d games will be downloaded", downloadable.size).printf(downloadable.size));
			}

			if(no_images.size > 0)
			{
				add_action_separator();
				var action_download_images = add_action("image-x-generic", null, _("Download images"), download_game_images);
				action_download_images.text += "\n" + """<span size="smaller">%s</span>""".printf(ngettext("Image for %d game will be searched", "Images for %d games will be searched", no_images.size).printf(no_images.size));
			}

			if(uninstallable.size > 0)
			{
				add_action_separator();
				var action_uninstall = add_action("edit-delete", null, _("Uninstall"), uninstall_games);
				action_uninstall.text += "\n" + """<span size="smaller">%s</span>""".printf(ngettext("%d game will be uninstalled", "%d games will be uninstalled", uninstallable.size).printf(uninstallable.size));
			}

			if(refreshable.size > 0)
			{
				add_action_separator();
				var action_refresh = add_action("view-refresh", null, _("Refresh"), refresh_games);
				action_refresh.text += "\n" + """<span size="smaller">%s</span>""".printf(ngettext("%d game will be removed from database. Restart GameHub to fetch new data", "%d games will be removed from database. Restart GameHub to fetch new data", refreshable.size).printf(refreshable.size));
			}

			actions.show_all();
		}

		private void install_games()
		{
			if(installable == null || installable.size == 0) return;

			if(Sources.Steam.Steam.instance.enabled)
			{
				string[] steam_apps = {};
				foreach(var game in installable)
				{
					if(game is Sources.Steam.SteamGame)
					{
						steam_apps += game.id;
					}
				}
				if(steam_apps.length > 0)
				{
					try
					{
						Sources.Steam.Steam.install_multiple_apps(steam_apps);
					}
					catch(Utils.RunError error)
					{
						//FIXME [DEV-ART]: Replace this with inline error display?
						GameHub.UI.Dialogs.QuickErrorDialog.display_and_log.begin(
							this, error, Log.METHOD,
							_("Installing Steam apps “%s” failed").printf(
								string.joinv(_("”, “"), steam_apps)
							)
						);
					}
				}
			}

			foreach(var game in installable)
			{
				if(!(game is Sources.Steam.SteamGame))
				{
					game.install.begin(Runnable.Installer.InstallMode.AUTOMATIC, (obj, res) => {
						try
						{
							game.install.end(res);
						}
						catch(Utils.RunError error)
						{
							//FIXME [DEV-ART]: Replace this with inline error display?
							GameHub.UI.Dialogs.QuickErrorDialog.display_and_log.begin(
								this, error, Log.METHOD,
								_("Installing game “%s” failed").printf(game.name)
							);
						}
					});
				}
			}
			update();
		}

		private void download_games()
		{
			if(downloadable == null || downloadable.size == 0) return;
			foreach(var game in downloadable)
			{
				if(!(game is Sources.Steam.SteamGame))
				{
					game.install.begin(Runnable.Installer.InstallMode.AUTOMATIC_DOWNLOAD);
				}
			}
			update();
		}

		private void download_game_images()
		{
			if(no_images == null || no_images.size == 0) return;
			download_images(no_images);
			update();
		}

		private void uninstall_games()
		{
			if(uninstallable == null || uninstallable.size == 0) return;
			uninstall_games_async.begin(uninstallable);
		}

		private void refresh_games()
		{
			if(refreshable == null || refreshable.size == 0) return;
			foreach(var game in refreshable)
			{
				Tables.Games.remove(game);
			}
			update();
		}

		private async void uninstall_games_async(ArrayList<Game> games)
		{
			foreach(var game in games)
			{
				try
				{
					yield game.uninstall();
				}
				catch(Utils.RunError error)
				{
					//FIXME [DEV-ART]: Replace this with inline error display?
					GameHub.UI.Dialogs.QuickErrorDialog.display_and_log.begin(
						this, error, Log.METHOD,
						_("Uninstalling game “%s” failed").printf(game.name)
					);
				}
			}
			update();
		}

		private void add_action_separator()
		{
			if(actions.get_children().length() == 0) return;
			var separator = new Separator(Orientation.HORIZONTAL);
			separator.margin = 4;
			actions.add(separator);
		}

		private delegate void Action();
		private ActionButton add_action(string icon, string? icon_overlay, string title, Action action)
		{
			var ui_settings = Settings.UI.Appearance.instance;
			var button = new ActionButton(icon + Settings.UI.Appearance.symbolic_icon_suffix, icon_overlay, title, true, ui_settings.icon_style.is_symbolic());
			button.hexpand = true;
			actions.add(button);
			button.clicked.connect(() => action());
			ui_settings.notify["icon-style"].connect(() => {
				button.icon = icon + Settings.UI.Appearance.symbolic_icon_suffix;
				button.compact = ui_settings.icon_style.is_symbolic();
			});
			return button;
		}
	}
}
