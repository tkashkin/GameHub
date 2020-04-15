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
using GameHub.Data.Runnables;
using GameHub.Utils;
using GameHub.UI.Widgets;

namespace GameHub.UI.Views.GameDetailsView
{
	public class GameDetailsView: BaseView
	{
		private Game? _game;
		private ArrayList<Game>? _selected_games;

		public GameSource? preferred_source { get; set; }

		public int content_margin = 8;

		public Game? game
		{
			get { return _game; }
			set
			{
				_game = value;
				_selected_games = null;
				navigation.clear();
				navigation.add(game);
				Idle.add(() => {
					update();
					return Source.REMOVE;
				});
			}
		}

		public ArrayList<Game>? selected_games
		{
			get { return _selected_games; }
			set
			{
				_selected_games = value;
				_game = null;
				Idle.add(() => {
					update_selected_games();
					return Source.REMOVE;
				});
			}
		}

		public GameDetailsView(Game? game=null)
		{
			Object(game: game);
		}

		private Stack root_stack;
		public MultipleGamesDetailsView selected_games_view;
		private Box game_box;

		private Stack stack;

		private Button back_button;
		private ExtendedStackSwitcher stack_tabs;

		private Revealer actions;

		private ArrayList<Game> navigation = new ArrayList<Game>(Game.is_equal);

		construct
		{
			root_stack = new Stack();
			root_stack.transition_type = StackTransitionType.NONE;
			root_stack.expand = true;

			stack = new Stack();
			stack.transition_type = StackTransitionType.SLIDE_LEFT_RIGHT;
			stack.expand = true;

			stack_tabs = new ExtendedStackSwitcher(stack);
			stack_tabs.valign = Align.CENTER;
			stack_tabs.halign = Align.CENTER;
			stack_tabs.expand = false;
			stack_tabs.visible = false;

			back_button = new Button.with_label("");
			back_button.tooltip_text = _("Back");
			back_button.valign = Align.CENTER;
			back_button.expand = false;
			back_button.visible = false;
			back_button.margin_top = back_button.margin_bottom = 6;
			StyleClass.add(back_button, StyleClass.BACK_BUTTON);

			back_button.clicked.connect(() => {
				if(navigation.size > 1)
				{
					navigation.remove_at(navigation.size - 1);
				}
				Idle.add(() => {
					update();
					return Source.REMOVE;
				});
			});

			game_box = new Box(Orientation.VERTICAL, 0);

			actions = new Revealer();
			actions.transition_type = RevealerTransitionType.SLIDE_DOWN;
			actions.reveal_child = false;

			var actionbar = new ActionBar();
			actionbar.get_style_context().add_class("gameinfo-toolbar");
			actionbar.pack_start(back_button);
			actionbar.set_center_widget(stack_tabs);

			actions.add(actionbar);

			game_box.add(actions);
			game_box.add(stack);

			selected_games_view = new MultipleGamesDetailsView();

			root_stack.add(game_box);
			root_stack.add(selected_games_view);

			root_stack.visible_child = game_box;

			add(root_stack);

			stack.notify["visible-child"].connect(() => {
				var page = stack.visible_child as GameDetailsPage;
				if(page != null)
				{
					Idle.add(() => {
						page.update();
						return Source.REMOVE;
					});
				}
			});

			get_style_context().add_class("gameinfo-background");
			var ui_settings = GameHub.Settings.UI.Appearance.instance;
			ui_settings.notify["dark-theme"].connect(() => {
				get_style_context().remove_class("dark");
				if(ui_settings.dark_theme) get_style_context().add_class("dark");
			});
			ui_settings.notify_property("dark-theme");

			notify["preferred-source"].connect(() => {
				if(preferred_source != null)
				{
					var id = preferred_source.id;
					foreach(var page in stack.get_children())
					{
						var page_id = Value(typeof(string));
						stack.child_get_property(page, "name", ref page_id);
						if(page_id.holds(typeof(string)) && page_id.get_string().has_prefix(@"$(id):"))
						{
							stack.set_visible_child_full(page_id.get_string(), StackTransitionType.NONE);
						}
					}
				}
			});

			Idle.add(() => {
				update();
				return Source.REMOVE;
			});
		}

		public void navigate(Game g)
		{
			navigation.add(g);

			Idle.add(() => {
				update();
				return Source.REMOVE;
			});
		}

		private void update()
		{
			root_stack.visible_child = game_box;

			stack_tabs.clear();

			back_button.visible = false;
			if(navigation.size > 1)
			{
				back_button.visible = true;
				back_button.label = navigation.get(navigation.size - 2).name;
			}

			var g = navigation.get(navigation.size - 1);

			if(g == null) return;

			var primary = Settings.UI.Behavior.instance.merge_games ? Tables.Merges.get_primary(g) : null;
			var merges = Settings.UI.Behavior.instance.merge_games ? Tables.Merges.get(g) : null;
			bool merged = merges != null && merges.size > 0;

			stack_tabs.visible = merged || primary != null;

			add_page(g);

			if(primary != null)
			{
				if(!Game.is_equal(g, primary))
				{
					add_page(primary);
				}
				merges = Tables.Merges.get(primary);
				merged = merges != null && merges.size > 0;
			}

			if(merged)
			{
				/*foreach(var m in merges)
				{
					if(Game.is_equal(g, m)
						|| !m.is_supported(null)
						|| (g is Sources.GOG.GOGGame.DLC && Game.is_equal((g as Sources.GOG.GOGGame.DLC).game, m)))
					{
						continue;
					}

					add_page(m);
				}*/
			}

			stack_tabs.visible = stack.get_children().length() > 1;

			actions.reveal_child = back_button.visible || stack_tabs.visible;

			stack.show_all();

			Idle.add(() => {
				notify_property("preferred-source");
				return Source.REMOVE;
			});
		}

		private void add_page(Game g)
		{
			if(stack.get_child_by_name(g.full_id) != null) return;

			var label = """<span weight="600" size="smaller">%s</span>%s""".printf(g.source.name, "\n" + g.name.replace("&amp;", "&").replace("&", "&amp;"));

			var page = new GameDetailsPage(g, this);
			page.content.margin = content_margin;
			stack_tabs.add_tab(page, g.full_id, label, true, g.source.icon);
		}

		private void update_selected_games()
		{
			if(selected_games == null) return;
			selected_games_view.games = selected_games;
			root_stack.visible_child = selected_games_view;
		}
	}
}
