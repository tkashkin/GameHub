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
using GLib;
using Gee;

using GameHub.Data;
using GameHub.Data.Adapters;
using GameHub.Data.DB;
using GameHub.Utils;
using GameHub.UI.Widgets;
using GameHub.UI.Windows;
using GameHub.Settings;

using GameHub.UI.Views.GamesView.List;
using GameHub.UI.Views.GamesView.Grid;

namespace GameHub.UI.Views.GamesView
{
	public class GamesView: BaseView
	{
		public static GamesView instance;

		private ArrayList<GameSource> sources = new ArrayList<GameSource>();

		private GamesAdapter games_adapter;

		private Box messages;

		private Stack stack;

		private AlertView empty_alert;

		private GamesGrid games_grid;

		private Paned games_list_paned;
		private GamesList games_list;
		private GameDetailsView.GameDetailsView games_list_details;

		private ModeButton view;

		private ModeButton filter;
		private SearchEntry search;

		private OverlayBar status_overlay;

		private Button settings;

		private MenuButton downloads;
		private Popover downloads_popover;
		private ListBox downloads_list;
		private int downloads_count = 0;

		private MenuButton filters;
		private FiltersPopover filters_popover;

		private MenuButton add_game_button;
		private AddGamePopover add_game_popover;

		private Settings.UI.Appearance ui_settings;
		private Settings.SavedState.GamesView saved_state;

		#if MANETTE
		private Manette.Monitor manette_monitor = new Manette.Monitor();
		private ArrayList<Manette.Device> connected_gamepads = new ArrayList<Manette.Device>();
		private bool gamepad_axes_to_keys_thread_running = false;
		private ArrayList<Widget> gamepad_mode_visible_widgets = new ArrayList<Widget>();
		private ArrayList<Widget> gamepad_mode_hidden_widgets = new ArrayList<Widget>();
		private Settings.Controller controller_settings;
		#endif

		public const string ACTION_PREFIX             = "win.";
		public const string ACTION_SOURCE_PREV        = "source.previous";
		public const string ACTION_SOURCE_NEXT        = "source.next";
		public const string ACTION_SEARCH             = "search";
		public const string ACTION_FILTERS            = "filters";
		public const string ACTION_DOWNLOADS          = "downloads";
		public const string ACTION_SELECT_RANDOM_GAME = "select-random-game";
		public const string ACTION_ADD_GAME           = "add-game";
		public const string ACTION_EXIT               = "exit";

		public const string ACCEL_SOURCE_PREV         = "F1"; // LB
		public const string ACCEL_SOURCE_NEXT         = "F2"; // RB
		public const string ACCEL_SEARCH              = "<Control>F";
		public const string ACCEL_FILTERS             = "<Alt>F";
		public const string ACCEL_DOWNLOADS           = "<Control>D";
		public const string ACCEL_SELECT_RANDOM_GAME  = "<Control>R";
		public const string ACCEL_ADD_GAME            = "<Control>N";
		public const string ACCEL_EXIT                = "<Shift>Escape"; // Guide + Escape

		private const GLib.ActionEntry[] action_entries = {
			{ ACTION_SOURCE_PREV,        window_action_handler },
			{ ACTION_SOURCE_NEXT,        window_action_handler },
			{ ACTION_SEARCH,             window_action_handler },
			{ ACTION_FILTERS,            window_action_handler },
			{ ACTION_DOWNLOADS,          window_action_handler },
			{ ACTION_SELECT_RANDOM_GAME, window_action_handler },
			{ ACTION_ADD_GAME,           window_action_handler },
			{ ACTION_EXIT,               window_action_handler }
		};

		construct
		{
			instance = this;

			ui_settings = Settings.UI.Appearance.instance;
			saved_state = Settings.SavedState.GamesView.instance;

			foreach(var src in GameSources)
			{
				if(src.enabled && src.is_authenticated()) sources.add(src);
			}

			var overlay = new Overlay();

			stack = new Stack();
			stack.transition_type = StackTransitionType.CROSSFADE;

			empty_alert = new AlertView(_("No games"), _("Get some games or enable some game sources in settings"), "dialog-warning");
			stack.add(empty_alert);

			overlay.add(stack);

			messages = new Box(Orientation.VERTICAL, 0);

			attach(messages, 0, 0);
			attach(overlay, 0, 1);

			view = new ModeButton();
			view.halign = Align.CENTER;
			view.valign = Align.CENTER;

			add_view_button("view-grid-symbolic", _("Grid view"));
			add_view_button("view-list-symbolic", _("List view"));

			view.mode_changed.connect(update_view);

			filter = new ModeButton();
			filter.halign = Align.CENTER;
			filter.valign = Align.CENTER;

			add_filter_button("sources-all-symbolic", _("All games"));

			foreach(var src in sources)
			{
				add_filter_button(src.icon, src.name_from);
			}

			filter.set_active(sources.size > 1 ? 0 : 1);

			if(saved_state.filter_source.length > 0)
			{
				for(int i = 0; i < sources.size; i++)
				{
					if(sources[i].id == saved_state.filter_source)
					{
						filter.set_active(i + 1);
						break;
					}
				}
			}

			downloads = new MenuButton();
			downloads.valign = Align.CENTER;
			Utils.set_accel_tooltip(downloads, _("Downloads"), ACCEL_DOWNLOADS);
			downloads.image = new Image.from_icon_name("folder-download" + Settings.UI.Appearance.symbolic_icon_suffix, Settings.UI.Appearance.headerbar_icon_size);

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
			downloads_popover.set_size_request(500, -1);
			downloads.popover = downloads_popover;
			downloads.sensitive = false;

			filters = new MenuButton();
			filters.valign = Align.CENTER;
			Utils.set_accel_tooltip(filters, _("Filters"), ACCEL_FILTERS);
			filters.image = new Image.from_icon_name("tag" + Settings.UI.Appearance.symbolic_icon_suffix, Settings.UI.Appearance.headerbar_icon_size);
			filters_popover = new FiltersPopover(filters);
			filters_popover.position = PositionType.BOTTOM;
			filters.popover = filters_popover;

			add_game_button = new MenuButton();
			add_game_button.valign = Align.CENTER;
			Utils.set_accel_tooltip(add_game_button, _("Add game"), ACCEL_ADD_GAME);
			add_game_button.image = new Image.from_icon_name("list-add" + Settings.UI.Appearance.symbolic_icon_suffix, Settings.UI.Appearance.headerbar_icon_size);
			add_game_popover = new AddGamePopover(add_game_button);
			add_game_popover.position = PositionType.BOTTOM;
			add_game_button.popover = add_game_popover;

			search = new SearchEntry();
			search.placeholder_text = _("Search");
			Utils.set_accel_tooltip(search, search.placeholder_text, ACCEL_SEARCH);
			search.halign = Align.CENTER;
			search.valign = Align.CENTER;

			settings = new Button();
			settings.valign = Align.CENTER;
			Utils.set_accel_tooltip(settings, _("Settings"), Application.ACCEL_SETTINGS);
			settings.image = new Image.from_icon_name("open-menu" + Settings.UI.Appearance.symbolic_icon_suffix, Settings.UI.Appearance.headerbar_icon_size);
			settings.action_name = Application.ACTION_PREFIX + Application.ACTION_SETTINGS;

			games_adapter = new GamesAdapter();
			games_adapter.cache_loaded.connect(update_view);

			filter.mode_changed.connect(update_view);
			search.search_changed.connect(() => {
				games_adapter.filter_search_query = search.text;
				games_adapter.invalidate(true, false, true);
				update_view();
			});
			search.activate.connect(search_run_first_matching_game);

			ui_settings.notify["icon-style"].connect(() => {
				(filters.image as Image).icon_name = "tag" + Settings.UI.Appearance.symbolic_icon_suffix;
				(add_game_button.image as Image).icon_name = "list-add" + Settings.UI.Appearance.symbolic_icon_suffix;
				(downloads.image as Image).icon_name = "folder-download" + Settings.UI.Appearance.symbolic_icon_suffix;
				(settings.image as Image).icon_name = "open-menu" + Settings.UI.Appearance.symbolic_icon_suffix;
				(filters.image as Image).icon_size = (add_game_button.image as Image).icon_size = (downloads.image as Image).icon_size = (settings.image as Image).icon_size = Settings.UI.Appearance.headerbar_icon_size;
			});

			filters_popover.filters_changed.connect(() => {
				games_adapter.filter_tags = filters_popover.selected_tags;
				games_adapter.invalidate(true, false, true);
			});
			filters_popover.filter_platform_changed.connect(() => {
				games_adapter.filter_platform = filters_popover.filter_platform;
				games_adapter.invalidate(true, false, true);
			});
			filters_popover.sort_mode_changed.connect(() => {
				games_adapter.sort_mode = filters_popover.sort_mode;
				games_adapter.invalidate(false, true, false);
			});
			filters_popover.group_mode_changed.connect(() => {
				games_adapter.group_mode = filters_popover.group_mode;
				games_adapter.invalidate(true, true, true);
			});

			add_game_popover.game_added.connect(g => {
				games_adapter.add(g);
				update_view();
			});
			add_game_popover.download_images.connect(() => {
				download_images_async.begin(null);
			});

			titlebar.pack_start(view);

			if(sources.size > 1)
			{
				#if MANETTE
				titlebar.pack_start(gamepad_image("bumper-left"));
				#endif

				titlebar.pack_start(filter);

				#if MANETTE
				titlebar.pack_start(gamepad_image("bumper-right"));
				#endif
			}

			#if MANETTE
			var gamepad_filters_separator = new Separator(Orientation.VERTICAL);
			gamepad_filters_separator.no_show_all = true;
			gamepad_mode_visible_widgets.add(gamepad_filters_separator);
			titlebar.pack_start(gamepad_filters_separator);
			#endif

			titlebar.pack_start(filters);

			#if MANETTE
			titlebar.pack_start(gamepad_image("y"));
			#endif

			var settings_overlay = new Overlay();
			settings_overlay.add(settings);

			#if MANETTE
			var settings_gamepad_shortcut = gamepad_image("select");
			settings_gamepad_shortcut.halign = Align.CENTER;
			settings_gamepad_shortcut.valign = Align.END;
			settings_overlay.add_overlay(settings_gamepad_shortcut);
			settings_overlay.set_overlay_pass_through(settings_gamepad_shortcut, true);
			#endif

			titlebar.pack_end(settings_overlay);

			titlebar.pack_end(downloads);
			titlebar.pack_end(search);
			titlebar.pack_end(add_game_button);

			#if MANETTE
			var gamepad_shortcuts_separator = new Separator(Orientation.VERTICAL);
			gamepad_shortcuts_separator.no_show_all = true;
			gamepad_mode_visible_widgets.add(gamepad_shortcuts_separator);
			titlebar.pack_end(gamepad_shortcuts_separator);
			titlebar.pack_end(gamepad_image("x", _("Menu")));
			titlebar.pack_end(gamepad_image("b", _("Back")));
			titlebar.pack_end(gamepad_image("a", _("Select")));
			#endif

			status_overlay = new OverlayBar(overlay);
			games_adapter.notify["status"].connect(() => {
				update_status(games_adapter.status);
			});

			show_all();

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
			add_game_button.opacity = 0;
			add_game_button.sensitive = false;

			Downloader.download_manager().dl_started.connect(dl => {
				Idle.add(() => {
					downloads_list.add(new DownloadProgressView(dl));
					downloads.sensitive = true;
					downloads_count++;

					#if UNITY
					dl.download.status_change.connect(s => {
						Idle.add(() => {
							update_downloads_progress();
							return Source.REMOVE;
						}, Priority.LOW);
					});
					#endif
					return Source.REMOVE;
				}, Priority.LOW);
			});
			Downloader.download_manager().dl_ended.connect(dl => {
				Idle.add(() => {
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
					#if UNITY
					update_downloads_progress();
					#endif
					return Source.REMOVE;
				}, Priority.LOW);
			});

			#if MANETTE
			controller_settings = Settings.Controller.instance;
			gamepad_mode_hidden_widgets.add(view);
			gamepad_mode_hidden_widgets.add(downloads);
			gamepad_mode_hidden_widgets.add(search);
			gamepad_mode_hidden_widgets.add(add_game_button);

			if(controller_settings.enabled)
			{
				var manette_iterator = manette_monitor.iterate();
				Manette.Device manette_device = null;
				while(manette_iterator.next(out manette_device))
				{
					on_gamepad_connected(manette_device);
				}
				manette_monitor.device_connected.connect(on_gamepad_connected);
				manette_monitor.device_disconnected.connect(on_gamepad_disconnected);
			}
			#endif

			games_adapter.filter_tags = filters_popover.selected_tags;
			games_adapter.filter_platform = filters_popover.filter_platform;
			games_adapter.sort_mode = filters_popover.sort_mode;
			games_adapter.group_mode = filters_popover.group_mode;

			load_games();
		}

		public override void attach_to_window(MainWindow wnd)
		{
			base.attach_to_window(wnd);

			window.add_action_entries(action_entries, this);
			Application.instance.set_accels_for_action(ACTION_PREFIX + ACTION_SOURCE_PREV,                      { ACCEL_SOURCE_PREV });
			Application.instance.set_accels_for_action(ACTION_PREFIX + ACTION_SOURCE_NEXT,                      { ACCEL_SOURCE_NEXT });
			Application.instance.set_accels_for_action(ACTION_PREFIX + ACTION_SEARCH,                           { ACCEL_SEARCH });
			Application.instance.set_accels_for_action(ACTION_PREFIX + ACTION_FILTERS,                          { ACCEL_FILTERS });
			Application.instance.set_accels_for_action(ACTION_PREFIX + ACTION_DOWNLOADS,                        { ACCEL_DOWNLOADS });
			Application.instance.set_accels_for_action(ACTION_PREFIX + ACTION_SELECT_RANDOM_GAME,               { ACCEL_SELECT_RANDOM_GAME });
			Application.instance.set_accels_for_action(ACTION_PREFIX + ACTION_ADD_GAME,                         { ACCEL_ADD_GAME });
			Application.instance.set_accels_for_action(ACTION_PREFIX + ACTION_EXIT,                             { ACCEL_EXIT });
			Application.instance.set_accels_for_action(Application.ACTION_PREFIX + Application.ACTION_SETTINGS, { "F5" }); // Select
		}

		private void window_action_handler(SimpleAction action, Variant? args)
		{
			switch(action.name)
			{
				case ACTION_SOURCE_PREV:
				case ACTION_SOURCE_NEXT:
					var tab = filter.selected + (action.name == ACTION_SOURCE_PREV ? -1 : 1);
					if(tab < 0) tab = (int) filter.n_items - 1;
					else if(tab >= filter.n_items) tab = 0;
					filter.selected = tab;
					break;

				case ACTION_SEARCH:
					search.grab_focus();
					break;

				case ACTION_FILTERS:
					filters.clicked();
					break;

				case ACTION_DOWNLOADS:
					if(downloads.sensitive)
					{
						downloads.clicked();
					}
					break;

				case ACTION_SELECT_RANDOM_GAME:
					int index = Random.int_range(0, (int32) games_grid.get_children().length());
					games_grid.select(index, view.selected == 0);
					games_list.select(index, view.selected == 1);
					break;

				case ACTION_ADD_GAME:
					add_game_button.clicked();
					break;

				case ACTION_EXIT:
					#if MANETTE
					Gamepad.reset();
					#endif
					window.destroy();
					break;
			}
		}

		private void init_grid()
		{
			if(games_grid != null) return;

			games_grid = new GamesGrid();
			stack.add(games_grid.wrapped());
			games_grid.attach(games_adapter);
		}

		private void init_list()
		{
			if(games_list != null) return;

			games_list_paned = new Paned(Orientation.HORIZONTAL);
			games_list = new GamesList();
			games_list_details = new GameDetailsView.GameDetailsView(null);
			games_list_details.content_margin = 16;
			games_list_paned.pack1(games_list.wrapped(), false, false);
			games_list_paned.pack2(games_list_details, true, true);
			stack.add(games_list_paned);
			games_list_paned.show_all();

			games_list.game_selected.connect(game => { games_list_details.game = game; });
			games_list.multiple_games_selected.connect(games => { games_list_details.selected_games = games; });
			games_list_details.selected_games_view.download_images.connect(games => {
				download_images_async.begin(games);
			});
			games_list.attach(games_adapter);
		}

		private void init_and_show_view(Settings.SavedState.GamesView.Style view)
		{
			switch(view)
			{
				case Settings.SavedState.GamesView.Style.GRID:
					init_grid();
					if(games_grid != null && games_grid.scrolled != null)
						stack.set_visible_child(games_grid.scrolled);
					break;

				case Settings.SavedState.GamesView.Style.LIST:
					init_list();
					if(games_list != null && games_list_paned != null)
						stack.set_visible_child(games_list_paned);
					break;
			}
		}

		private void update_view()
		{
			show_games();

			var f = filter.selected;
			GameSource? src = null;
			if(f > 0) src = sources[f - 1];

			if(games_adapter.filter_source != src)
			{
				games_adapter.filter_source = src;
				games_adapter.invalidate(true, false, true);
			}

			if(games_list_details != null) games_list_details.preferred_source = src;

			saved_state.filter_source = src == null ? "" : src.id;

			var games = src == null ? games_adapter.games_count : src.games_count;
			var filtered_games = games_adapter.filtered_games_count;

			var games_count = ngettext("%u game", "%u games", games).printf(games);
			if(filtered_games != games)
			{
				games_count = C_("games_view_subtitle_filtered_games", "%1$u / %2$s").printf(filtered_games, games_count);
			}
			if(src != null)
			{
				titlebar.subtitle = C_("games_view_subtitle", "%1$s: %2$s").printf(src.name, games_count);
			}
			else
			{
				titlebar.subtitle = games_count;
			}

			if(src != null && src.games_count == 0)
			{
				if(src is GameHub.Data.Sources.User.User)
				{
					empty_alert.title = _("No user-added games");
					empty_alert.description = _("Add some games using plus button");
				}
				else
				{
					empty_alert.title = _("No %s games").printf(src.name);
					empty_alert.description = _("Get some Linux-compatible games");
				}
				empty_alert.icon_name = src.icon;
				stack.set_visible_child(empty_alert);
				return;
			}
			else if(search.text.strip().length > 0)
			{
				if(!games_adapter.has_filtered_games)
				{
					empty_alert.title = _("No games matching “%s”").printf(search.text.strip());
					empty_alert.description = null;
					empty_alert.icon_name = null;
					if(src != null)
					{
						empty_alert.title = _("No %1$s games matching “%2$s”").printf(src.name, search.text.strip());
					}
					stack.set_visible_child(empty_alert);
					return;
				}
			}

			saved_state.style = (Settings.SavedState.GamesView.Style) view.selected;
			init_and_show_view(saved_state.style);
		}

		private void show_games()
		{
			if(view.opacity != 0 || stack.visible_child != empty_alert) return;

			view.set_active((int) saved_state.style);
			init_and_show_view(saved_state.style);

			view.opacity = 1;
			view.sensitive = true;
			filter.opacity = 1;
			filter.sensitive = true;
			search.opacity = 1;
			search.sensitive = true;
			downloads.opacity = 1;
			filters.opacity = 1;
			filters.sensitive = true;
			add_game_button.opacity = 1;
			add_game_button.sensitive = true;
		}

		private void load_games()
		{
			messages.get_children().foreach(c => messages.remove(c));

			games_adapter.load_games(src => {
				if(src.games_count == 0 && src is GameHub.Data.Sources.Steam.Steam)
				{
					var msg = add_message(_("No games were loaded from Steam. Set your games list privacy to public or use your own Steam API key in settings."), MessageType.WARNING);
					msg.add_button(_("Privacy"), 1);
					msg.add_button(_("Settings"), 2);

					msg.close.connect(() => {
						#if GTK_3_22
						msg.revealed = false;
						#endif
						Timeout.add(250, () => { messages.remove(msg); return Source.REMOVE; });
					});

					msg.response.connect(r => {
						switch(r)
						{
							case 1:
								try
								{
									Utils.open_uri("steam://openurl/https://steamcommunity.com/my/edit/settings");
								}
								catch(Utils.RunError error)
								{
									//FIXME [DEV-ART]: Replace this with inline error display?
									GameHub.UI.Dialogs.QuickErrorDialog.display_and_log.begin(
										this, error, Log.METHOD,
										_("Launching Stream Community settings failed")
									);
								}
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
			});
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

		private void search_run_first_matching_game()
		{
			if(search.text.strip().length == 0 || !search.has_focus) return;

			if(view.selected == 0)
			{
				#if GTK_3_22
				var card = games_grid.get_child_at_pos(0, 0) as GameCard?;
				if(card != null)
				{
					card.game.run_or_install.begin();
				}
				#endif
			}
			else
			{
				var row = games_list.get_row_at_y(32) as GameListRow?;
				if(row != null)
				{
					row.game.run_or_install.begin();
				}
			}
		}

		public InfoBar add_message(string text, MessageType type=MessageType.OTHER)
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

		private void update_status(string? status)
		{
			Idle.add(() => {
				if(status != null && status.length > 0)
				{
					status_overlay.label = status;
					status_overlay.active = true;
					status_overlay.show();
				}
				else
				{
					status_overlay.active = false;
					status_overlay.hide();
				}
				return Source.REMOVE;
			}, Priority.LOW);
		}

		private async void download_images_async(ArrayList<Game>? games=null)
		{
			update_status(_("Downloading images"));
			var _games = games ?? DB.Tables.Games.get_all();
			foreach(var game in _games)
			{
				if(game.image == null || game.image_vertical == null)
				{
					yield download_game_images(game);
				}
			}
			update_status(null);
		}

		private async void download_game_images(Game game)
		{
			update_status(_("Downloading image: %s").printf(game.name));

			string? image = game.image;
			string? image_vertical = game.image_vertical;

			if(image != null && image_vertical != null) return;

			foreach(var src in Data.Providers.ImageProviders)
			{
				if(!src.enabled) continue;

				var results = yield src.images(game);
				if(results == null || results.size < 1) continue;
				foreach(var result in results)
				{
					if(result.images != null && result.images.size > 0)
					{
						if(image == null && result.image_size.width >= result.image_size.height)
						{
							image = result.images.get(0).url;
						}
						else if(image_vertical == null && result.image_size.width < result.image_size.height)
						{
							image_vertical = result.images.get(0).url;
						}
					}

					if(image != null && image_vertical != null) break;
				}
			}

			game.image = image;
			game.image_vertical = image_vertical;
			game.save();
		}

		#if UNITY
		private void update_downloads_progress()
		{
			games_adapter.launcher_entry.progress_visible = downloads_count > 0;
			double progress = 0;
			int count = 0;
			downloads_list.foreach(row => {
				var dl_row = row as DownloadProgressView;
				if(dl_row != null)
				{
					progress += dl_row.dl_info.download.status.progress;
					count++;
				}
			});
			games_adapter.launcher_entry.progress = progress / count;
			games_adapter.launcher_entry.count_visible = count > 0;
			games_adapter.launcher_entry.count = count;
		}
		#endif

		#if MANETTE
		private void ui_update_gamepad_mode()
		{
			Idle.add(() => {
				var is_gamepad_connected = connected_gamepads.size > 0 && Gamepad.ButtonPressed;
				var widgets_to_show = is_gamepad_connected ? gamepad_mode_visible_widgets : gamepad_mode_hidden_widgets;
				var widgets_to_hide = is_gamepad_connected ? gamepad_mode_hidden_widgets : gamepad_mode_visible_widgets;
				foreach(var w in widgets_to_show) w.show();
				foreach(var w in widgets_to_hide) w.hide();
				if(is_gamepad_connected)
				{
					view.selected = 0;
					games_grid.grab_focus();
				}
				return Source.REMOVE;
			});
		}

		private void on_gamepad_connected(Manette.Device device)
		{
			var known = controller_settings.known_controllers;
			var ignored = controller_settings.ignored_controllers;

			if(!(device.get_name() in known))
			{
				known += device.get_name();
				controller_settings.known_controllers = known;
			}

			if(device.get_name() in ignored)
			{
				debug("[Gamepad] '%s' connected [ignored]", device.get_name());
				return;
			}

			debug("[Gamepad] '%s' connected", device.get_name());

			device.button_press_event.connect(on_gamepad_button_press_event);
			device.button_release_event.connect(on_gamepad_button_release_event);
			device.absolute_axis_event.connect(on_gamepad_absolute_axis_event);
			connected_gamepads.add(device);
			gamepad_axes_to_keys_thread();
			ui_update_gamepad_mode();
		}

		private void on_gamepad_disconnected(Manette.Device device)
		{
			debug("[Gamepad] '%s' disconnected", device.get_name());
			connected_gamepads.remove(device);
			ui_update_gamepad_mode();
		}

		private void on_gamepad_button_press_event(Manette.Device device, Manette.Event e)
		{
			uint16 btn;
			if(!e.get_button(out btn)) return;
			on_gamepad_button(btn, true);
		}

		private void on_gamepad_button_release_event(Manette.Event e)
		{
			uint16 btn;
			if(!e.get_button(out btn)) return;
			on_gamepad_button(btn, false);
		}

		private void on_gamepad_button(uint16 btn, bool press)
		{
			if(Gamepad.Buttons.has_key(btn))
			{
				var b = Gamepad.Buttons.get(btn);
				b.emit_key_event(press);

				if(GameHub.Application.log_verbose && !Runnable.IsLaunched && !Sources.Steam.Steam.IsAnyAppRunning)
				{
					debug("[Gamepad] Button %s: %s (%s) [%d]", (press ? "pressed" : "released"), b.name, b.long_name, btn);
				}

				ui_update_gamepad_mode();

				if(controller_settings.focus_window && !press && b == Gamepad.BTN_GUIDE && !window.has_focus && !Runnable.IsLaunched && !Sources.Steam.Steam.IsAnyAppRunning)
				{
					window.get_window().focus(Gdk.CURRENT_TIME);
				}
			}
		}

		private void on_gamepad_absolute_axis_event(Manette.Event e)
		{
			uint16 axis;
			double value;
			if(!e.get_absolute(out axis, out value)) return;

			if(Gamepad.Axes.has_key(axis))
			{
				Gamepad.Axes.get(axis).value = value;
			}
		}

		private void gamepad_axes_to_keys_thread()
		{
			if(gamepad_axes_to_keys_thread_running) return;
			Utils.thread("GamepadAxesToKeysThread", () => {
				gamepad_axes_to_keys_thread_running = true;
				while(connected_gamepads.size > 0)
				{
					foreach(var axis in Gamepad.Axes.values)
					{
						axis.emit_key_event();
					}
					Thread.usleep(Gamepad.KEY_EVENT_EMIT_INTERVAL);
					ui_update_gamepad_mode();
				}
				Gamepad.reset();
				gamepad_axes_to_keys_thread_running = false;
			});
		}

		private Widget gamepad_image(string icon, string? text=null)
		{
			Widget widget;

			var image = new Image.from_icon_name("controller-button-" + icon, IconSize.LARGE_TOOLBAR);

			if(text != null)
			{
				var label = Styled.H4Label(text);
				var box = new Box(Orientation.HORIZONTAL, 8);
				box.margin_start = box.margin_end = 4;
				box.add(image);
				box.add(label);
				box.show_all();
				widget = box;
			}
			else
			{
				widget = image;
			}

			widget.visible = false;
			widget.no_show_all = true;

			gamepad_mode_visible_widgets.add(widget);
			return widget;
		}
		#endif
	}
}
