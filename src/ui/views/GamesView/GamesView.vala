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
using GLib;
using Gee;
using Granite;
using GameHub.Data;
using GameHub.Data.DB;
using GameHub.Utils;

namespace GameHub.UI.Views.GamesView
{
	public class GamesView: BaseView
	{
		public static GamesView instance;

		private ArrayList<GameSource> sources = new ArrayList<GameSource>();

		private Box messages;

		private Stack stack;

		private Granite.Widgets.AlertView empty_alert;

		private ScrolledWindow games_grid_scrolled;
		private FlowBox games_grid;

		private Paned games_list_paned;
		private ListBox games_list;
		private GameDetailsView.GameDetailsView games_list_details;

		private Granite.Widgets.ModeButton view;

		private Granite.Widgets.ModeButton filter;
		private SearchEntry search;

		private Spinner spinner;
		private int loading_sources = 0;
		private bool new_games_added = false;

		private Button settings;

		private MenuButton downloads;
		private Popover downloads_popover;
		private ListBox downloads_list;
		private int downloads_count = 0;

		private MenuButton filters;
		private FiltersPopover filters_popover;

		private MenuButton add_game_button;
		private AddGamePopover add_game_popover;

		private Settings.UI ui_settings;
		private Settings.SavedState saved_state;

		private bool view_update_interval_started = false;
		private bool view_update_pending = false;
		private int view_update_no_updates_cycles = 0;

		construct
		{
			instance = this;

			ui_settings = Settings.UI.get_instance();
			saved_state = Settings.SavedState.get_instance();

			foreach(var src in GameSources)
			{
				if(src.enabled && src.is_authenticated()) sources.add(src);
			}

			stack = new Stack();
			stack.transition_type = StackTransitionType.CROSSFADE;

			empty_alert = new Granite.Widgets.AlertView(_("No games"), _("Get some games or enable some game sources in settings"), "dialog-warning");
			empty_alert.show_action(_("Reload"));

			games_grid = new FlowBox();
			games_grid.get_style_context().add_class("games-grid");
			games_grid.margin = 4;

			games_grid.activate_on_single_click = false;
			games_grid.homogeneous = false;
			games_grid.min_children_per_line = 2;
			games_grid.selection_mode = SelectionMode.NONE;
			games_grid.valign = Align.START;

			games_grid_scrolled = new ScrolledWindow(null, null);
			games_grid_scrolled.expand = true;
			games_grid_scrolled.hscrollbar_policy = PolicyType.NEVER;
			games_grid_scrolled.add(games_grid);

			games_list_paned = new Paned(Orientation.HORIZONTAL);

			games_list = new ListBox();
			games_list.selection_mode = SelectionMode.BROWSE;

			games_list_details = new GameDetailsView.GameDetailsView(null);
			games_list_details.content_margin = 16;

			var games_list_scrolled = new ScrolledWindow(null, null);
			games_list_scrolled.hscrollbar_policy = PolicyType.EXTERNAL;
			games_list_scrolled.add(games_list);
			games_list_scrolled.set_size_request(220, -1);

			games_list_paned.pack1(games_list_scrolled, false, false);
			games_list_paned.pack2(games_list_details, true, true);

			stack.add(empty_alert);
			stack.add(games_grid_scrolled);
			stack.add(games_list_paned);

			messages = new Box(Orientation.VERTICAL, 0);

			attach(messages, 0, 0);
			attach(stack, 0, 1);

			view = new Granite.Widgets.ModeButton();
			view.halign = Align.CENTER;
			view.valign = Align.CENTER;

			add_view_button("view-grid-symbolic", _("Grid view"));
			add_view_button("view-list-symbolic", _("List view"));

			view.mode_changed.connect(() => {
				postpone_view_update();
			});

			titlebar.pack_start(view);

			filter = new Granite.Widgets.ModeButton();
			filter.halign = Align.CENTER;
			filter.valign = Align.CENTER;

			add_filter_button("sources-all-symbolic", _("All games"));

			foreach(var src in sources)
			{
				add_filter_button(src.icon, _("%s games").printf(src.name));
			}

			filter.set_active(sources.size > 1 ? 0 : 1);

			downloads = new MenuButton();
			downloads.tooltip_text = _("Downloads");
			downloads.image = new Image.from_icon_name("emblem-downloads", IconSize.LARGE_TOOLBAR);
			downloads_popover = new Popover(downloads);
			downloads_list = new ListBox();
			downloads_list.get_style_context().add_class("downloads-list");

			var downloads_scrolled = new ScrolledWindow(null, null);
			#if GTK_3_22
			downloads_scrolled.propagate_natural_width = true;
			downloads_scrolled.propagate_natural_height = true;
			downloads_scrolled.max_content_height = 440;
			#else
			downloads_scrolled.min_content_height = 440;
			#endif
			downloads_scrolled.add(downloads_list);
			downloads_scrolled.show_all();

			downloads_popover.add(downloads_scrolled);
			downloads_popover.position = PositionType.BOTTOM;
			downloads_popover.set_size_request(384, -1);
			downloads.popover = downloads_popover;
			downloads.sensitive = false;

			filters = new MenuButton();
			filters.tooltip_text = _("Filters");
			filters.image = new Image.from_icon_name("tag", IconSize.LARGE_TOOLBAR);
			filters_popover = new FiltersPopover(filters);
			filters_popover.position = PositionType.BOTTOM;
			filters.popover = filters_popover;

			add_game_button = new MenuButton();
			add_game_button.tooltip_text = _("Add game");
			add_game_button.image = new Image.from_icon_name("list-add", IconSize.LARGE_TOOLBAR);
			add_game_popover = new AddGamePopover(add_game_button);
			add_game_popover.position = PositionType.BOTTOM;
			add_game_button.popover = add_game_popover;

			search = new SearchEntry();
			search.placeholder_text = _("Search");
			search.halign = Align.CENTER;
			search.valign = Align.CENTER;

			settings = new Button();
			settings.tooltip_text = _("Settings");
			settings.image = new Image.from_icon_name("open-menu", IconSize.LARGE_TOOLBAR);

			settings.clicked.connect(() => new Dialogs.SettingsDialog.SettingsDialog());

			if(sources.size > 1) titlebar.pack_start(filter);

			games_grid.set_sort_func((child1, child2) => {
				var item1 = child1 as GameCard;
				var item2 = child2 as GameCard;
				if(item1 != null && item2 != null)
				{
					return item1.game.name.collate(item2.game.name);
				}
				return 0;
			});

			games_list.set_sort_func((row1, row2) => {
				var item1 = row1 as GameListRow;
				var item2 = row2 as GameListRow;
				if(item1 != null && item2 != null)
				{
					var s1 = item1.game.status.state;
					var s2 = item2.game.status.state;

					var f1 = item1.game.has_tag(Tables.Tags.BUILTIN_FAVORITES);
					var f2 = item2.game.has_tag(Tables.Tags.BUILTIN_FAVORITES);

					if(f1 && !f2) return -1;
					if(f2 && !f1) return 1;

					if(s1 == Game.State.DOWNLOADING && s2 != Game.State.DOWNLOADING) return -1;
					if(s1 != Game.State.DOWNLOADING && s2 == Game.State.DOWNLOADING) return 1;
					if(s1 == Game.State.INSTALLING && s2 != Game.State.INSTALLING) return -1;
					if(s1 != Game.State.INSTALLING && s2 == Game.State.INSTALLING) return 1;
					if(s1 == Game.State.INSTALLED && s2 != Game.State.INSTALLED) return -1;
					if(s1 != Game.State.INSTALLED && s2 == Game.State.INSTALLED) return 1;

					return item1.game.name.collate(item2.game.name);
				}
				return 0;
			});

			games_grid.set_filter_func(child => {
				var item = child as GameCard;
				return games_filter(item.game);
			});

			games_list.set_filter_func(row => {
				var item = row as GameListRow;
				return games_filter(item.game);
			});

			games_list.set_header_func((row, prev) => {
				var item = row as GameListRow;
				var prev_item = prev as GameListRow;
				var s = item.game.status.state;
				var ps = prev_item != null ? prev_item.game.status.state : s;
				var f = item.game.has_tag(Tables.Tags.BUILTIN_FAVORITES);
				var pf = prev_item != null ? prev_item.game.has_tag(Tables.Tags.BUILTIN_FAVORITES) : f;

				if(prev_item != null && f == pf && (f || s == ps)) row.set_header(null);
				else
				{
					var label = new HeaderLabel(f ? C_("status_header", "Favorites") : item.game.status.header);
					label.get_style_context().add_class("games-list-header");
					label.set_size_request(1024, -1); // ugly hack
					row.set_header(label);
				}
			});

			games_list.row_selected.connect(row => {
				var item = row as GameListRow;
				games_list_details.game = item != null ? item.game : null;
			});

			filter.mode_changed.connect(postpone_view_update);
			search.search_changed.connect(postpone_view_update);

			ui_settings.notify["show-unsupported-games"].connect(postpone_view_update);
			ui_settings.notify["use-proton"].connect(postpone_view_update);

			filters_popover.filters_changed.connect(postpone_view_update);

			add_game_popover.game_added.connect(g => add_game(g));

			spinner = new Spinner();

			titlebar.pack_start(filters);
			titlebar.pack_end(settings);
			titlebar.pack_end(downloads);
			titlebar.pack_end(search);
			titlebar.pack_end(add_game_button);
			titlebar.pack_end(spinner);

			show_all();
			games_grid_scrolled.show_all();
			games_grid.show_all();

			empty_alert.action_activated.connect(() => load_games());

			stack.set_visible_child(empty_alert);

			view.opacity = 0;
			view.sensitive = false;
			filter.opacity = 0;
			filter.sensitive = false;
			search.opacity = 0;
			search.sensitive = false;
			downloads.opacity = 0;
			filters.opacity = 0;
			filters.sensitive = false;

			Downloader.get_instance().dl_started.connect(dl => {
				downloads_list.add(new DownloadProgressView(dl));
				downloads.sensitive = true;
				downloads_count++;
			});
			Downloader.get_instance().dl_ended.connect(dl => {
				downloads_count--;
				if(downloads_count < 0) downloads_count = 0;
				downloads.sensitive = downloads_count > 0;
				if(downloads_count == 0)
				{
					#if GTK_3_22
					downloads_popover.popdown();
					#else
					downloads_popover.hide();
					#endif
				}
			});

			load_games();
		}

		private void postpone_view_update()
		{
			view_update_pending = true;
			if(!view_update_interval_started)
			{
				Utils.thread("GamesViewUpdate", () => {
					view_update_interval_started = true;
					view_update_no_updates_cycles = 0;
					while(view_update_no_updates_cycles < 10)
					{
						if(view_update_pending)
						{
							Idle.add(() => { update_view(); return Source.REMOVE; });
							view_update_no_updates_cycles = 0;
						}
						else
						{
							view_update_no_updates_cycles++;
						}
						view_update_pending = false;
						Thread.usleep(500000);
					}
					view_update_interval_started = false;
				});
			}
		}

		private void update_view()
		{
			show_games();

			games_grid.invalidate_filter();
			games_list.invalidate_filter();

			var f = filter.selected;
			GameSource? src = null;
			if(f > 0) src = sources[f - 1];
			var games = src == null ? games_grid.get_children().length() : src.games_count;
			titlebar.subtitle = (src == null ? "" : src.name + ": ") + ngettext("%u game", "%u games", games).printf(games);

			games_list_details.preferred_source = src;

			if(src != null && src.games_count == 0)
			{
				empty_alert.title = _("No %s games").printf(src.name);
				empty_alert.description = _("Get some Linux-compatible games");
				empty_alert.icon_name = src.icon;
				stack.set_visible_child(empty_alert);
				return;
			}
			else if(search.text.strip().length > 0)
			{
				var something_shown = false;

				foreach(var card in games_grid.get_children())
				{
					if(games_filter(((GameCard) card).game))
					{
						something_shown = true;
						break;
					}
				}

				if(!something_shown)
				{
					empty_alert.title = _("No games matching “%s”").printf(search.text.strip());
					empty_alert.description = null;
					empty_alert.icon_name = null;
					if(src != null)
					{
						empty_alert.title = _("No %1$s games matching “%2$s”").printf(src.name, search.text.strip());
					}
					empty_alert.hide_action();
					stack.set_visible_child(empty_alert);
					return;
				}
			}

			var tab = view.selected == 0 ? (Widget) games_grid_scrolled : (Widget) games_list_paned;
			stack.set_visible_child(tab);
			saved_state.games_view = view.selected == 0 ? Settings.GamesView.GRID : Settings.GamesView.LIST;

			Timeout.add(100, () => { games_list_select_first_visible_row(); return false; });
		}

		private void show_games()
		{
			if(view.opacity != 0 || stack.visible_child != empty_alert) return;

			view.set_active(saved_state.games_view == Settings.GamesView.LIST ? 1 : 0);
			stack.set_visible_child(saved_state.games_view == Settings.GamesView.LIST ? (Widget) games_list_paned : (Widget) games_grid_scrolled);

			view.opacity = 1;
			view.sensitive = true;
			filter.opacity = 1;
			filter.sensitive = true;
			search.opacity = 1;
			search.sensitive = true;
			downloads.opacity = 1;
			filters.opacity = 1;
			filters.sensitive = true;
		}

		private void add_game(Game g, bool cached=false)
		{
			var card = new GameCard(g);
			var row = new GameListRow(g);

			g.tags_update.connect(postpone_view_update);

			games_grid.add(card);
			games_list.add(row);

			card.show();
			row.show();

			if(!cached)
			{
				merge_game(g);
				new_games_added = true;
			}

			postpone_view_update();

			if(games_list.get_selected_row() == null)
			{
				Idle.add(() => {
					games_list.select_row(games_list.get_row_at_index(0));
					return Source.REMOVE;
				});
			}

			if(g is Sources.User.UserGame)
			{
				((Sources.User.UserGame) g).removed.connect(() => {
					remove_game(g);
				});
			}
		}

		private void load_games()
		{
			messages.get_children().foreach(c => messages.remove(c));

			foreach(var src in sources)
			{
				loading_sources++;
				spinner.active = loading_sources > 0;
				src.load_games.begin(add_game, postpone_view_update, (obj, res) => {
					src.load_games.end(res);

					loading_sources--;
					spinner.active = loading_sources > 0;

					if(loading_sources == 0)
					{
						if(new_games_added) merge_games();
						update_games();
					}
					postpone_view_update();

					if(src.games_count == 0)
					{
						if(src is GameHub.Data.Sources.Steam.Steam)
						{
							var msg = message(_("No games were loaded from Steam. Set your games list privacy to public or use your own Steam API key in settings."), MessageType.WARNING);
							msg.add_button(_("Privacy"), 1);
							msg.add_button(_("Settings"), 2);

							msg.close.connect(() => {
								#if GTK_3_22
								msg.revealed = false;
								#endif
								Timeout.add(250, () => { messages.remove(msg); return false; });
							});

							msg.response.connect(r => {
								switch(r)
								{
									case 1:
										Utils.open_uri("steam://openurl/https://steamcommunity.com/my/edit/settings");
										break;

									case 2:
										settings.clicked();
										break;

									case ResponseType.CLOSE:
										msg.close();
										break;
								}
							});
						}
					}
				});
			}
		}

		private void add_view_button(string icon, string tooltip)
		{
			var image = new Image.from_icon_name(icon, IconSize.MENU);
			image.tooltip_text = tooltip;
			view.append(image);
		}

		private void add_filter_button(string icon, string tooltip)
		{
			var image = new Image.from_icon_name(icon, IconSize.MENU);
			image.tooltip_text = tooltip;
			filter.append(image);
		}

		private bool games_filter(Game game)
		{
			if(!ui_settings.show_unsupported_games && !game.is_supported(null, ui_settings.use_compat)) return false;

			var f = filter.selected;
			GameSource? src = null;
			if(f > 0) src = sources[f - 1];

			bool same_src = (src == null || game == null || src == game.source);
			bool merged_src = false;

			ArrayList<Game>? merges = null;

			if(ui_settings.merge_games)
			{
				merges = Tables.Merges.get(game);
				if(!same_src && merges != null && merges.size > 0)
				{
					foreach(var g in merges)
					{
						if(g.source == src)
						{
							merged_src = true;
							break;
						}
					}
				}
			}

			var tags = filters_popover.selected_tags;
			bool tags_all_enabled = tags == null || tags.size == 0 || tags.size == Tables.Tags.TAGS.size;
			bool tags_all_except_hidden_enabled = tags != null && tags.size == Tables.Tags.TAGS.size - 1 && !(Tables.Tags.BUILTIN_HIDDEN in tags);
			bool tags_match = false;
			bool tags_match_merged = false;

			if(!tags_all_enabled)
			{
				foreach(var tag in tags)
				{
					tags_match = game.has_tag(tag);
					if(tags_match) break;
				}
				if(!tags_match && merges != null && merges.size > 0)
				{
					foreach(var g in merges)
					{
						foreach(var tag in tags)
						{
							tags_match_merged = g.has_tag(tag);
							if(tags_match_merged) break;
						}
					}
				}
			}

			bool hidden = game.has_tag(Tables.Tags.BUILTIN_HIDDEN) && (tags == null || tags.size == 0 || !(Tables.Tags.BUILTIN_HIDDEN in tags));

			return (same_src || merged_src) && (tags_all_enabled || tags_all_except_hidden_enabled || tags_match || tags_match_merged) && !hidden && Utils.strip_name(search.text).casefold() in Utils.strip_name(game.name).casefold();
		}

		private void games_list_select_first_visible_row()
		{
			var row = games_list.get_selected_row() as GameListRow?;
			if(row != null && games_filter(row.game)) return;
			row = games_list.get_row_at_y(32) as GameListRow?;
			games_list.select_row(row);
		}

		private InfoBar message(string text, MessageType type=MessageType.OTHER)
		{
			var bar = new InfoBar();
			bar.message_type = type;

			#if GTK_3_22
			bar.revealed = false;
			#endif

			bar.show_close_button = true;
			bar.get_content_area().add(new Label(text));

			messages.add(bar);

			bar.show_all();

			#if GTK_3_22
			bar.revealed = true;
			#endif

			return bar;
		}

		private void remove_game(Game game)
		{
			games_list.foreach(r => {
				var gr = r as GameListRow;
				if(gr.game == game)
				{
					games_list.remove(gr);
					return;
				}
			});
			games_grid.foreach(c => {
				var gc = c as GameCard;
				if(gc.game == game)
				{
					games_grid.remove(gc);
					return;
				}
			});
		}

		private void update_games()
		{
			if(in_destruction()) return;
			Utils.thread("Updating", () => {
				foreach(var src in sources)
				{
					foreach(var game in src.games)
					{
						game.update_game_info.begin();
						Thread.usleep(50000);
					}
				}
			});
		}

		private void merge_games()
		{
			if(!ui_settings.merge_games || in_destruction()) return;
			Utils.thread("Merging", () => {
				foreach(var src in sources)
				{
					merge_games_from(src);
				}
			});
		}

		private void merge_games_from(GameSource src)
		{
			Utils.thread("Merging-" + src.id, () => {
				foreach(var game in src.games)
				{
					merge_game(game);
				}
			});
		}

		private void merge_game(Game game)
		{
			if(!ui_settings.merge_games || in_destruction() || game is Sources.GOG.GOGGame.DLC) return;
			Utils.thread("Merging-" + game.full_id, () => {
				foreach(var src in sources)
				{
					foreach(var game2 in src.games)
					{
						merge_game_with_game(src, game, game2);
					}
				}
			});
		}

		private void merge_game_with_game(GameSource src, Game game, Game game2)
		{
			Utils.thread("Merging-" + game.full_id + "-" + game2.full_id, () => {
				if(Game.is_equal(game, game2) || game2 is Sources.GOG.GOGGame.DLC)
				{
					return;
				}

				bool name_match_exact = Utils.strip_name(game.name).casefold() == Utils.strip_name(game2.name).casefold();
				bool name_match_fuzzy_prefix = game.source != src
				                  && (Utils.strip_name(game.name, ":").casefold().has_prefix(Utils.strip_name(game2.name).casefold() + ":")
				                  || Utils.strip_name(game2.name, ":").casefold().has_prefix(Utils.strip_name(game.name).casefold() + ":"));
				if(name_match_exact || name_match_fuzzy_prefix)
				{
					Tables.Merges.add(game, game2);
					debug(@"[Merge] Merging '$(game.name)' ($(game.full_id)) with '$(game2.name)' ($(game2.full_id))");

					Idle.add(() => {
						remove_game(game2);
						games_list.foreach(r => { (r as GameListRow).update(); });
						games_grid.foreach(c => { (c as GameCard).update(); });
						return Source.REMOVE;
					});
				}
			});
		}
	}
}
