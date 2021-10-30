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

using Gtk;
using Gdk;

using GameHub.Data;
using GameHub.Data.DB;
using GameHub.Data.Runnables;
using GameHub.Utils;
using GameHub.UI.Widgets;

namespace GameHub.UI.Views.GamesView
{
	public class GameContextMenu: Gtk.Menu
	{
		public Game game { get; construct; }
		public Widget? target { get; construct; default = null; }
		public bool is_merge_submenu { private get; construct; default = false; }

		public GameContextMenu(Game game, Widget? target=null, bool is_merge_submenu=false)
		{
			Object(game: game, target: target, is_merge_submenu: is_merge_submenu);
		}

		construct
		{
			if(game.status.state == Game.State.INSTALLED && !(game is Sources.GOG.GOGGame.DLC) && !(game is Sources.EpicGames.EpicGame.DLC))
			{
				var run = new Gtk.MenuItem.with_label(_("Run"));
				run.sensitive = game.can_be_launched();
				run.activate.connect(() => game.run_as_task.begin());
				add(run);

				add(new Gtk.SeparatorMenuItem());

				/*if(game.actions != null && game.actions.size > 0)
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
				}*/
			}
			else if(game.status.state == Game.State.UNINSTALLED)
			{
				var install = new Gtk.MenuItem.with_label(_("Install"));
				install.sensitive = game.is_installable;
				install.activate.connect(() => game.install.begin());
				add(install);
				add(new Gtk.SeparatorMenuItem());
			}

			var details = new Gtk.MenuItem.with_label(_("Details"));
			details.activate.connect(() => new Dialogs.GameDetailsDialog(game).show_all());
			add(details);

			if(!(game is Sources.GOG.GOGGame.DLC) && !(game is Sources.EpicGames.EpicGame.DLC))
			{
				if(Settings.UI.Behavior.instance.merge_games && !is_merge_submenu)
				{
					var merges = DB.Tables.Merges.get(game);
					var primary = DB.Tables.Merges.get_primary(game);
					if(primary != null || (merges != null && merges.size > 0))
					{
						add(new Gtk.SeparatorMenuItem());
						if(primary != null)
						{
							add_merged_game_submenu(primary);
							merges = DB.Tables.Merges.get(primary);
						}
						if(merges != null)
						{
							foreach(var g in merges)
							{
								if(g == game) continue;
								add_merged_game_submenu(g);
							}
						}
					}
				}

				add(new Gtk.SeparatorMenuItem());
				var favorite = new Gtk.CheckMenuItem.with_label(C_("game_context_menu", "Favorite"));
				favorite.active = game.has_tag(Tables.Tags.BUILTIN_FAVORITES);
				favorite.toggled.connect(() => game.toggle_tag(Tables.Tags.BUILTIN_FAVORITES));
				add(favorite);
				var hidden = new Gtk.CheckMenuItem.with_label(C_("game_context_menu", "Hidden"));
				hidden.active = game.has_tag(Tables.Tags.BUILTIN_HIDDEN);
				hidden.toggled.connect(() => game.toggle_tag(Tables.Tags.BUILTIN_HIDDEN));
				add(hidden);
			}

			bool add_dirs_separator = true;

			if(game.status.state == Game.State.INSTALLED && game.install_dir != null && game.install_dir.query_exists())
			{
				if(add_dirs_separator) add(new Gtk.SeparatorMenuItem());
				add_dirs_separator = false;
				var open_dir = new Gtk.MenuItem.with_label(_("Open installation directory"));
				open_dir.activate.connect(() => Utils.open_uri(game.install_dir.get_uri()));
				add(open_dir);
			}

			/*if(game.installers_dir != null && game.installers_dir.query_exists())
			{
				if(add_dirs_separator) add(new Gtk.SeparatorMenuItem());
				add_dirs_separator = false;
				var open_installers_dir = new Gtk.MenuItem.with_label(_("Open installers collection directory"));
				open_installers_dir.activate.connect(open_installer_collection_directory);
				add(open_installers_dir);
			}

			if(game is GameHub.Data.Sources.GOG.GOGGame && (game as GameHub.Data.Sources.GOG.GOGGame).bonus_content_dir != null && (game as GameHub.Data.Sources.GOG.GOGGame).bonus_content_dir.query_exists())
			{
				if(add_dirs_separator) add(new Gtk.SeparatorMenuItem());
				add_dirs_separator = false;
				var open_bonuses_dir = new Gtk.MenuItem.with_label(_("Open bonus collection directory"));
				open_bonuses_dir.activate.connect(open_bonus_collection_directory);
				add(open_bonuses_dir);
			}

			if(game is GameHub.Data.Sources.Steam.SteamGame && (game as GameHub.Data.Sources.Steam.SteamGame).screenshots_dir != null && (game as GameHub.Data.Sources.Steam.SteamGame).screenshots_dir.query_exists())
			{
				if(add_dirs_separator) add(new Gtk.SeparatorMenuItem());
				add_dirs_separator = false;
				var open_screenshots_dir = new Gtk.MenuItem.with_label(_("Open screenshots directory"));
				open_screenshots_dir.activate.connect(open_screenshots_directory);
				add(open_screenshots_dir);
			}*/

			if((game.status.state == Game.State.INSTALLED || game is Sources.User.UserGame) && !(game is Sources.GOG.GOGGame.DLC) && !(game is Sources.EpicGames.EpicGame.DLC))
			{
				var uninstall = new Gtk.MenuItem.with_label((game is Sources.User.UserGame) ? _("Remove") : _("Uninstall"));
				uninstall.activate.connect(() => game.uninstall.begin());
				add(new Gtk.SeparatorMenuItem());
				add(uninstall);
			}

			if(!(game is Sources.GOG.GOGGame.DLC) && !(game is Sources.EpicGames.EpicGame.DLC))
			{
				add(new Gtk.SeparatorMenuItem());
				var properties = new Gtk.MenuItem.with_label(_("Properties"));
				properties.activate.connect(() => new Dialogs.GamePropertiesDialog.GamePropertiesDialog(game).show_all());
				add(properties);
			}

			show_all();
		}

		public void open(Event e, bool at_pointer=true)
		{
			if(at_pointer)
			{
				popup_at_pointer(e);
			}
			else
			{
				popup_at_widget(target, Gravity.SOUTH, Gravity.NORTH, e);
			}
		}

		private void add_merged_game_submenu(Game g)
		{
			var item = new Gtk.MenuItem.with_label("""<span weight="600" size="smaller">%s</span>%s""".printf(g.source.name, "\n" + g.name.replace("&amp;", "&").replace("&", "&amp;")));
			((Label) item.get_child()).use_markup = true;
			item.get_style_context().add_class("menuitem-merged-game");
			item.submenu = new GameContextMenu(g, null, true);
			add(item);
		}
	}
}
