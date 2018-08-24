using Gtk;
using Gdk;
using Gee;
using Granite;
using GameHub.Data;
using GameHub.Utils;
using GameHub.UI.Widgets;
using WebKit;

namespace GameHub.UI.Views.GameDetailsView
{
	public class GameDetailsView: BaseView
	{
		private Game? _game;

		public int content_margin = 8;

		public Game? game
		{
			get { return _game; }
			set
			{
				_game = value;
				Idle.add(update);
			}
		}

		public GameDetailsView(Game? game=null)
		{
			Object(game: game);
		}

		private Stack stack;
		private StackSwitcher stack_switcher;

		construct
		{
			var overlay = new Overlay();

			stack = new Stack();
			stack.transition_type = StackTransitionType.SLIDE_LEFT_RIGHT;
			stack.expand = true;

			stack_switcher = new StackSwitcher();
			stack_switcher.valign = Align.START;
			stack_switcher.halign = Align.CENTER;
			stack_switcher.margin = 8;
			stack_switcher.visible = false;
			stack_switcher.stack = stack;
			stack_switcher.get_style_context().add_class(Gtk.STYLE_CLASS_BACKGROUND);

			overlay.add(stack);
			overlay.add_overlay(stack_switcher);

			add(overlay);

			stack.notify["visible-child"].connect(() => {
				var page = stack.visible_child as GameDetailsPage;
				if(page != null) page.update();
			});

			get_style_context().add_class("gameinfo-background");
			var ui_settings = GameHub.Settings.UI.get_instance();
			ui_settings.notify["dark-theme"].connect(() => {
				get_style_context().remove_class("dark");
				if(ui_settings.dark_theme) get_style_context().add_class("dark");
			});
			ui_settings.notify_property("dark-theme");

			Idle.add(update);
		}

		private bool update()
		{
			stack.foreach(p => stack.remove(p));

			if(_game == null) return Source.REMOVE;

			var merges = Settings.UI.get_instance().merge_games ? GamesDB.get_instance().get_merged_games(game) : null;
			bool merged = merges != null && merges.size > 0;

			stack_switcher.visible = merged;

			add_page(_game);

			if(merged)
			{
				foreach(var g in merges)
				{
					add_page(g);
				}
			}

			stack.show_all();

			return Source.REMOVE;
		}

		private void add_page(Game g)
		{
			if(stack.get_child_by_name(g.source.name) != null) return;

			var page = new GameDetailsPage(g);
			page.content.margin = content_margin;
			page.content.margin_top = stack_switcher.visible ? 40 : content_margin;
			stack.add_titled(page, g.source.id, g.source.name);
		}
	}
}
