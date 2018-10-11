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
using Gee;
using Granite;
using GameHub.Data;
using GameHub.Data.DB;
using GameHub.Utils;
using GameHub.UI.Widgets;
using WebKit;

namespace GameHub.UI.Views.GameDetailsView
{
	public class GameDetailsView: BaseView
	{
		private Game? _game;

		public GameSource? preferred_source { get; set; }

		public int content_margin = 8;

		public Game? game
		{
			get { return _game; }
			set
			{
				_game = value;
				navigation.clear();
				navigation.add(game);
				Idle.add(update);
			}
		}

		public GameDetailsView(Game? game=null)
		{
			Object(game: game);
		}

		private Stack stack;

		private Button back_button;
		private StackSwitcher stack_switcher;

		private Revealer actions;

		private ArrayList<Game> navigation = new ArrayList<Game>(Game.is_equal);

		construct
		{
			stack = new Stack();
			stack.transition_type = StackTransitionType.SLIDE_LEFT_RIGHT;
			stack.expand = true;

			stack_switcher = new StackSwitcher();
			stack_switcher.valign = Align.CENTER;
			stack_switcher.halign = Align.CENTER;
			stack_switcher.expand = false;
			stack_switcher.visible = false;
			stack_switcher.stack = stack;

			back_button = new Button.with_label("");
			back_button.tooltip_text = _("Back");
			back_button.valign = Align.CENTER;
			back_button.expand = false;
			back_button.visible = false;
			back_button.get_style_context().add_class(Granite.STYLE_CLASS_BACK_BUTTON);

			back_button.clicked.connect(() => {
				if(navigation.size > 1)
				{
					navigation.remove_at(navigation.size - 1);
				}
				update();
			});

			actions = new Revealer();
			actions.transition_type = RevealerTransitionType.SLIDE_DOWN;
			actions.reveal_child = false;

			var actionbar = new ActionBar();
			actionbar.get_style_context().add_class("gameinfo-toolbar");
			actionbar.pack_start(back_button);
			actionbar.set_center_widget(stack_switcher);

			actions.add(actionbar);

			attach(actions, 0, 0);
			attach(stack, 0, 1);

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

			notify["preferred-source"].connect(() => {
				if(preferred_source != null)
				{
					var name = preferred_source.id;
					if(stack.get_child_by_name(name) != null)
					{
						stack.set_visible_child_full(name, StackTransitionType.NONE);
					}
				}
			});

			Idle.add(update);
		}

		public void navigate(Game g)
		{
			navigation.add(g);

			Idle.add(update);
		}

		private bool update()
		{
			stack.foreach(p => stack.remove(p));

			back_button.visible = false;
			if(navigation.size > 1)
			{
				back_button.visible = true;
				back_button.label = navigation.get(navigation.size - 2).name;
			}

			var g = navigation.get(navigation.size - 1);

			if(g == null) return Source.REMOVE;

			var merges = Settings.UI.get_instance().merge_games ? Tables.Merges.get(game) : null;
			bool merged = merges != null && merges.size > 0;

			stack_switcher.visible = merged;

			add_page(g);

			if(merged)
			{
				foreach(var m in merges)
				{
					if(Game.is_equal(g, m)
						|| (!Settings.UI.get_instance().show_unsupported_games && !m.is_supported(null, Settings.UI.get_instance().use_compat))
						|| (g is Sources.GOG.GOGGame.DLC && Game.is_equal((g as Sources.GOG.GOGGame.DLC).game, m)))
					{
						continue;
					}

					add_page(m);
				}
			}

			stack_switcher.visible = stack.get_children().length() > 1;

			actions.reveal_child = back_button.visible || stack_switcher.visible;

			stack.show_all();

			Idle.add(() => {
				notify_property("preferred-source");
				return Source.REMOVE;
			});

			return Source.REMOVE;
		}

		private void add_page(Game g)
		{
			if(stack.get_child_by_name(g.source.id) != null) return;

			var page = new GameDetailsPage(g, this);
			page.content.margin = content_margin;
			stack.add_titled(page, g.source.id, g.source.name);
		}
	}
}
