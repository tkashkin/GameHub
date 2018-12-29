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
using Gdk;
using Granite;
using GameHub.Data;
using GameHub.Data.DB;
using GameHub.Utils;
using GameHub.UI.Widgets;

namespace GameHub.UI.Views.GamesView
{
	public class GameContextMenu: Gtk.Menu
	{
		public Game game { get; construct; }

		public Widget target { get; construct; }

		public GameContextMenu(Game game, Widget target)
		{
			Object(game: game, target: target);
		}

		construct
		{
			var run = new Gtk.MenuItem.with_label(_("Run"));
			run.activate.connect(() => game.run.begin());

			var run_with_compat = new Gtk.MenuItem.with_label(_("Run with compatibility layer"));
			run_with_compat.sensitive = Settings.UI.get_instance().use_compat;
			run_with_compat.activate.connect(() => game.run_with_compat.begin(true));

			var install = new Gtk.MenuItem.with_label(_("Install"));
			install.sensitive = game.is_installable;
			install.activate.connect(() => game.install.begin());

			var details = new Gtk.MenuItem.with_label(_("Details"));
			details.activate.connect(() => new Dialogs.GameDetailsDialog(game).show_all());

			var favorite = new Gtk.CheckMenuItem.with_label(C_("game_context_menu", "Favorite"));
			favorite.active = game.has_tag(Tables.Tags.BUILTIN_FAVORITES);
			favorite.toggled.connect(() => game.toggle_tag(Tables.Tags.BUILTIN_FAVORITES));

			var hidden = new Gtk.CheckMenuItem.with_label(C_("game_context_menu", "Hidden"));
			hidden.active = game.has_tag(Tables.Tags.BUILTIN_HIDDEN);
			hidden.toggled.connect(() => game.toggle_tag(Tables.Tags.BUILTIN_HIDDEN));

			var fs_overlays = new Gtk.MenuItem.with_label(_("Overlays"));
			fs_overlays.activate.connect(() => new Dialogs.GameFSOverlaysDialog(game).show_all());

			var properties = new Gtk.MenuItem.with_label(_("Properties"));
			properties.activate.connect(() => new Dialogs.GamePropertiesDialog(game).show_all());

			if(game.status.state == Game.State.INSTALLED && !(game is Sources.GOG.GOGGame.DLC))
			{
				if(game.use_compat)
				{
					add(run_with_compat);
				}
				else
				{
					add(run);
				}
				add(new Gtk.SeparatorMenuItem());

				if(game.actions != null && game.actions.size > 0)
				{
					var compat_tool = CompatTool.by_id(game.compat_tool);
					foreach(var action in game.actions)
					{
						var action_item = new Gtk.MenuItem.with_label(action.name);
						action_item.get_style_context().add_class("menuitem-game-action");
						if(action.is_primary)
						{
							action_item.get_style_context().add_class("primary");
						}
						action_item.sensitive = action.is_available(compat_tool);
						action_item.activate.connect(() => action.invoke.begin(compat_tool));
						add(action_item);
					}
					add(new Gtk.SeparatorMenuItem());
				}
			}
			else if(game.status.state == Game.State.UNINSTALLED)
			{
				add(install);
				add(new Gtk.SeparatorMenuItem());
			}

			add(details);

			if(!(game is Sources.GOG.GOGGame.DLC))
			{
				add(new Gtk.SeparatorMenuItem());
				add(favorite);
				add(hidden);
			}

			bool add_dirs_separator = true;

			if(game.status.state == Game.State.INSTALLED && game.install_dir != null && game.install_dir.query_exists())
			{
				if(add_dirs_separator) add(new Gtk.SeparatorMenuItem());
				add_dirs_separator = false;
				var open_directory = new Gtk.MenuItem.with_label(_("Open installation directory"));
				open_directory.activate.connect(open_game_directory);
				add(open_directory);
			}
			if(game.installers_dir != null && game.installers_dir.query_exists())
			{
				if(add_dirs_separator) add(new Gtk.SeparatorMenuItem());
				add_dirs_separator = false;
				var open_installers_directory = new Gtk.MenuItem.with_label(_("Open installers collection directory"));
				open_installers_directory.activate.connect(open_installer_collection_directory);
				add(open_installers_directory);
			}
			if(game is GameHub.Data.Sources.GOG.GOGGame && (game as GameHub.Data.Sources.GOG.GOGGame).bonus_content_dir != null && (game as GameHub.Data.Sources.GOG.GOGGame).bonus_content_dir.query_exists())
			{
				if(add_dirs_separator) add(new Gtk.SeparatorMenuItem());
				add_dirs_separator = false;
				var open_bonuses_directory = new Gtk.MenuItem.with_label(_("Open bonus collection directory"));
				open_bonuses_directory.activate.connect(open_bonus_collection_directory);
				add(open_bonuses_directory);
			}

			if((game.status.state == Game.State.INSTALLED || game is Sources.User.UserGame) && !(game is Sources.GOG.GOGGame.DLC))
			{
				var uninstall = new Gtk.MenuItem.with_label((game is Sources.User.UserGame) ? _("Remove") : _("Uninstall"));
				uninstall.activate.connect(() => game.uninstall.begin());
				add(new Gtk.SeparatorMenuItem());
				add(uninstall);

				add(new Gtk.SeparatorMenuItem());
				add(fs_overlays);
			}

			if(!(game is Sources.GOG.GOGGame.DLC))
			{
				add(new Gtk.SeparatorMenuItem());
				add(properties);
			}

			show_all();
		}

		public void open(Event e, bool at_pointer=true)
		{
			#if GTK_3_22
			if(at_pointer)
			{
				popup_at_pointer(e);
			}
			else
			{
				popup_at_widget(target, Gravity.SOUTH, Gravity.NORTH, e);
			}
			#else
			popup(null, null, null, 0, ((EventButton) e).time);
			#endif
		}

		private void open_game_directory()
		{
			if(game != null && game.status.state == Game.State.INSTALLED)
			{
				Utils.open_uri(game.install_dir.get_uri());
			}
		}

		private void open_installer_collection_directory()
		{
			if(game != null && game.installers_dir != null && game.installers_dir.query_exists())
			{
				Utils.open_uri(game.installers_dir.get_uri());
			}
		}

		private void open_bonus_collection_directory()
		{
			if(game != null && game is GameHub.Data.Sources.GOG.GOGGame)
			{
				var gog_game = game as GameHub.Data.Sources.GOG.GOGGame;
				if(gog_game != null && gog_game.bonus_content_dir != null && gog_game.bonus_content_dir.query_exists())
				{
					Utils.open_uri(gog_game.bonus_content_dir.get_uri());
				}
			}
		}
	}
}
