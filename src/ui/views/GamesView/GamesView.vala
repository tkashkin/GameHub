using Gtk;
using GLib;
using Gee;
using Granite;
using GameHub.Data;
using GameHub.Utils;
using GameHub.Utils.Downloader;

namespace GameHub.UI.Views
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
		private GameDetailsView games_list_details;

		private Granite.Widgets.ModeButton view;

		private Granite.Widgets.ModeButton filter;
		private SearchEntry search;

		private Spinner spinner;
		private int loading_sources = 0;

		private Button settings;

		private MenuButton downloads;
		private Popover downloads_popover;
		private ListBox downloads_list;
		private int downloads_count = 0;

		private Settings.UI ui_settings;
		private Settings.SavedState saved_state;

		private bool merging_thread_running = false;
		private HashMap<Game, ArrayList<Game>> merged_games = new HashMap<Game, ArrayList<Game>>(Game.hash, Game.is_equal);

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

			games_list_details = new GameDetailsView(null, merged_games);
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

			add_view_button("view-grid", _("Grid view"));
			add_view_button("view-list", _("List view"));

			view.mode_changed.connect(() => {
				update_view();
			});

			titlebar.pack_start(view);

			filter = new Granite.Widgets.ModeButton();
			filter.halign = Align.CENTER;
			filter.valign = Align.CENTER;

			add_filter_button("sources-all", _("All games"));

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
			#endif
			downloads_scrolled.add(downloads_list);
			downloads_scrolled.show_all();

			downloads_popover.add(downloads_scrolled);
			downloads_popover.position = PositionType.BOTTOM;
			downloads_popover.set_size_request(384, -1);
			downloads.popover = downloads_popover;
			downloads.set_sensitive(false);

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

				games_list.grab_focus();

				if(prev_item != null && s == ps) row.set_header(null);
				else
				{
					var label = new HeaderLabel(item.game.status.header);
					label.get_style_context().add_class("games-list-header");
					label.set_size_request(1024, -1); // ugly hack
					row.set_header(label);
				}
			});

			games_list.row_selected.connect(row => {
				var item = row as GameListRow;
				games_list_details.game = item != null ? item.game : null;
			});

			filter.mode_changed.connect(() => {
				games_grid.invalidate_filter();
				games_list.invalidate_filter();

				update_view();

				Timeout.add(100, () => { games_list_select_first_visible_row(); return false; });
			});
			search.search_changed.connect(() => filter.mode_changed(filter));

			spinner = new Spinner();

			titlebar.pack_end(settings);
			titlebar.pack_end(downloads);
			titlebar.pack_end(search);
			titlebar.pack_end(spinner);

			show_all();
			games_grid_scrolled.show_all();
			games_grid.show_all();

			empty_alert.action_activated.connect(() => load_games.begin());

			stack.set_visible_child(empty_alert);

			view.opacity = 0;
			view.sensitive = false;
			filter.opacity = 0;
			filter.sensitive = false;
			search.opacity = 0;
			search.sensitive = false;
			downloads.opacity = 0;

			load_games.begin();
		}

		private void update_view()
		{
			show_games();

			var f = filter.selected;
			GameSource? src = null;
			if(f > 0) src = sources[f - 1];
			var games = src == null ? games_grid.get_children().length() : src.games_count;
			titlebar.title = "GameHub" + (src == null ? "" : "/" + src.name);
			titlebar.subtitle = ngettext("%u game", "%u games", games).printf(games);

			if(src != null && src.games_count == 0)
			{
				empty_alert.title = _("No %s games").printf(src.name);
				empty_alert.description = _("Get some Linux-compatible games");
				empty_alert.icon_name = src.icon + "-symbolic";
				empty_alert.show_action(_("Reload"));
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
		}

		private async void load_games()
		{
			messages.get_children().foreach(c => messages.remove(c));

			foreach(var src in sources)
			{
				loading_sources++;
				spinner.active = loading_sources > 0;
				src.load_games.begin(g => {
					update_view();

					games_grid.add(new GameCard(g, merged_games));
					games_list.add(new GameListRow(g));
					games_grid.show_all();
					games_list.show_all();

					var pv = new GameDownloadProgressView(g);
					downloads_list.add(pv);
					g.status_change.connect(s => {
						if(s.state == Game.State.INSTALLING)
						{
							downloads_count--;
						}
						else if(s.state == Game.State.DOWNLOADING)
						{
							if(s.download != null && (s.download.status.state == DownloadState.CANCELLED
							                       || s.download.status.state == DownloadState.FAILED))
								downloads_count--;
							else if(!pv.visible) downloads_count++;
						}
						pv.visible = s.state == Game.State.DOWNLOADING;
						downloads_count = int.max(0, downloads_count);
						downloads.set_sensitive(downloads_count > 0);
					});
					g.status_change(g.status);
					merge_game(g);
				}, (obj, res) => {
					loading_sources--;
					spinner.active = loading_sources > 0;

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

			games_list.select_row(games_list.get_row_at_index(0));
		}

		private void add_view_button(string icon, string tooltip)
		{
			var image = new Image.from_icon_name(icon + "-symbolic", IconSize.MENU);
			image.tooltip_text = tooltip;
			view.append(image);
		}

		private void add_filter_button(string icon, string tooltip)
		{
			var image = new Image.from_icon_name(icon + "-symbolic", IconSize.MENU);
			image.tooltip_text = tooltip;
			filter.append(image);
		}

		private bool games_filter(Game game)
		{
			var f = filter.selected;
			GameSource? src = null;
			if(f > 0) src = sources[f - 1];
			bool same_src = (src == null || game == null || src == game.source);
			bool merged_src = false;
			if(!same_src && ui_settings.merge_games)
			{
				if(merged_games.has_key(game))
				{
					foreach(var g in merged_games.get(game))
					{
						if(g.source == src)
						{
							merged_src = true;
							break;
						}
					}
				}
			}
			return (same_src || merged_src) && Utils.strip_name(search.text).casefold() in Utils.strip_name(game.name).casefold();
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

		private void merge_games()
		{
			if(!ui_settings.merge_games) return;
			Idle.add(() => {
				foreach(var src1 in GameSources)
				{
					foreach(var game in src1.games)
					{
						merge_game(game);
					}
				}
				return Source.REMOVE;
			});
		}

		private void merge_game(Game game)
		{
			if(!ui_settings.merge_games) return;
			Idle.add(() => {
				foreach(var src in GameSources)
				{
					if(game.source == src) continue;
					foreach(var game2 in src.games)
					{
						if(merged_games.has_key(game2)) continue;
						bool name_match_exact = Utils.strip_name(game.name).casefold() == Utils.strip_name(game2.name).casefold();
						bool name_match_fuzzy_prefix = Utils.strip_name(game.name, ":").casefold().has_prefix(Utils.strip_name(game2.name).casefold() + ":")
						                            || Utils.strip_name(game2.name, ":").casefold().has_prefix(Utils.strip_name(game.name).casefold() + ":");
						if(name_match_exact || name_match_fuzzy_prefix)
						{
							if(!merged_games.has_key(game))
							{
								merged_games.set(game, new ArrayList<Game>(Game.is_equal));
							}
							merged_games.get(game).add(game2);
							debug(@"[Merge] Merging '$(game.name)' ($(game.source.name):$(game.id)) with '$(game2.name)' ($(game2.source.name):$(game2.id))");
							remove_game(game2);
						}
					}
				}

				games_list.foreach(r => { (r as GameListRow).update(); });
				games_grid.foreach(c => { (c as GameCard).update(); });
				return Source.REMOVE;
			});
		}
	}
}
