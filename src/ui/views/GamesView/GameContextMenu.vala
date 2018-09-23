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

		public GameContextMenu(Game game)
		{
			Object(game: game);
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

			add(new Gtk.SeparatorMenuItem());

			add(properties);

			show_all();
		}

		public void open(Widget widget, Event e)
		{
			#if GTK_3_22
			popup_at_pointer(e);
			#else
			popup(null, null, null, 0, ((EventButton) e).time);
			#endif
		}
	}
}
