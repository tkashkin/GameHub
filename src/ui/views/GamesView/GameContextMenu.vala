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
			run_with_compat.activate.connect(() => game.run_with_compat.begin());

			var install = new Gtk.MenuItem.with_label(_("Install"));
			install.activate.connect(() => game.install.begin());

			var details = new Gtk.MenuItem.with_label(_("Details"));
			details.activate.connect(() => new Dialogs.GameDetailsDialog(game).show_all());

			var favorite = new Gtk.CheckMenuItem.with_label(C_("game_context_menu", "Favorite"));
			favorite.active = game.has_tag(Tables.Tags.BUILTIN_FAVORITES);
			favorite.toggled.connect(() => game.toggle_tag(Tables.Tags.BUILTIN_FAVORITES));

			var hidden = new Gtk.CheckMenuItem.with_label(C_("game_context_menu", "Hidden"));
			hidden.active = game.has_tag(Tables.Tags.BUILTIN_HIDDEN);
			hidden.toggled.connect(() => game.toggle_tag(Tables.Tags.BUILTIN_HIDDEN));

			var properties = new Gtk.MenuItem.with_label(_("Properties"));
			properties.activate.connect(() => new Dialogs.GamePropertiesDialog(game).show_all());

			if(game.status.state == Game.State.INSTALLED)
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
			}
			else if(game.status.state == Game.State.UNINSTALLED)
			{
				add(install);
				add(new Gtk.SeparatorMenuItem());
			}

			add(details);

			add(new Gtk.SeparatorMenuItem());

			add(favorite);
			add(hidden);

			if(game.status.state == Game.State.INSTALLED || game is Sources.User.UserGame)
			{
				var uninstall = new Gtk.MenuItem.with_label((game is Sources.User.UserGame) ? _("Remove") : _("Uninstall"));
				uninstall.activate.connect(() => game.uninstall.begin());
				add(new Gtk.SeparatorMenuItem());
				add(uninstall);
			}

			add(new Gtk.SeparatorMenuItem());

			add(properties);

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
	}
}
