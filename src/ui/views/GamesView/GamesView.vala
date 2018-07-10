using Gtk;
using Gee;
using Granite;
using GameHub.Data;
using GameHub.Utils;

namespace GameHub.UI.Views
{
	public class GamesView: BaseView
	{
		public static GamesView instance;

		private ArrayList<GameSource> sources = new ArrayList<GameSource>();

		private Stack stack;

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

		construct
		{
			instance = this;

			var ui_settings = Settings.UI.get_instance();
			var saved_state = Settings.SavedState.get_instance();

			foreach(var src in GameSources)
			{
				if(src.enabled && src.is_authenticated()) sources.add(src);
			}

			stack = new Stack();
			stack.transition_type = StackTransitionType.CROSSFADE;

			games_grid = new FlowBox();
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

			games_list_details = new GameDetailsView();
			games_list_details.content.margin = 16;

			var games_list_scrolled = new ScrolledWindow(null, null);
			games_list_scrolled.hscrollbar_policy = PolicyType.EXTERNAL;
			games_list_scrolled.add(games_list);
			games_list_scrolled.set_size_request(220, -1);

			games_list_paned.pack1(games_list_scrolled, false, false);
			games_list_paned.pack2(games_list_details, true, true);

			stack.add(games_grid_scrolled);
			stack.add(games_list_paned);
			add(stack);

			view = new Granite.Widgets.ModeButton();
			view.halign = Align.CENTER;
			view.valign = Align.CENTER;

			add_view_button(new Image.from_icon_name("view-grid-symbolic", IconSize.MENU), _("Grid view"));
			add_view_button(new Image.from_icon_name("view-list-symbolic", IconSize.MENU), _("List view"));

			view.mode_changed.connect(() => {
				var tab = view.selected == 0 ? (Widget) games_grid_scrolled : (Widget) games_list_paned;
				stack.set_visible_child(tab);
				saved_state.games_view = view.selected == 0 ? Settings.GamesView.GRID : Settings.GamesView.LIST;
			});

			titlebar.pack_start(view);

			filter = new Granite.Widgets.ModeButton();
			filter.halign = Align.CENTER;
			filter.valign = Align.CENTER;

			add_filter_button(new Image.from_icon_name("view-filter-symbolic", IconSize.MENU), _("All games"));

			foreach(var src in sources)
			{
				var image = new Image.from_pixbuf(FSUtils.get_icon(src.icon + (ui_settings.dark_theme ? "-white" : ""), 16));

				ui_settings.notify["dark-theme"].connect(() => {
					image.pixbuf = FSUtils.get_icon(src.icon + (ui_settings.dark_theme ? "-white" : ""), 16);
				});

				add_filter_button(image, _("%s games").printf(src.name));
			}

			filter.set_active(sources.size > 1 ? 0 : 1);

			downloads = new MenuButton();
			downloads.tooltip_text = _("Downloads");
			downloads.image = new Image.from_icon_name("folder-download", IconSize.LARGE_TOOLBAR);
			downloads_popover = new Popover(downloads);
			downloads_list = new ListBox();

			var downloads_scrolled = new ScrolledWindow(null, null);
			downloads_scrolled.propagate_natural_width = true;
			downloads_scrolled.propagate_natural_height = true;
			downloads_scrolled.max_content_height = 440;
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

			settings.clicked.connect(() => new Dialogs.SettingsDialog().show_all());

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
					return item1.game.name.collate(item2.game.name);
				}
				return 0;
			});

			games_grid.set_filter_func(child => {
				var item = child as GameCard;
				var f = filter.selected;

				GameSource? src = null;
				if(f > 0) src = sources[f - 1];

				var games = src == null ? games_grid.get_children().length() : src.games_count;
				titlebar.title = "GameHub" + (src == null ? "" : "/" + src.name);
				titlebar.subtitle = ngettext("%u game", "%u games", games).printf(games);

				return (src == null || item == null || src == item.game.source) && (item == null || search.text.casefold() in item.game.name.casefold());
			});

			games_list.set_filter_func(row => {
				var item = row as GameListRow;
				var f = filter.selected;

				GameSource? src = null;
				if(f > 0) src = sources[f - 1];

				return (src == null || item == null || src == item.game.source) && (item == null || search.text.casefold() in item.game.name.casefold());
			});

			games_list.row_selected.connect(row => {
				var item = row as GameListRow;
				games_list_details.game = item != null ? item.game : null;
			});

			filter.mode_changed.connect(() => {
				games_grid.invalidate_filter();
				games_list.invalidate_filter();
			});
			search.search_changed.connect(() => {
				games_grid.invalidate_filter();
				games_list.invalidate_filter();
			});

			spinner = new Spinner();

			titlebar.pack_end(settings);
			titlebar.pack_end(downloads);
			titlebar.pack_end(search);
			titlebar.pack_end(spinner);

			show_all();
			games_grid_scrolled.show_all();
			games_grid.show_all();

			view.set_active(saved_state.games_view == Settings.GamesView.LIST ? 1 : 0);
			stack.set_visible_child(saved_state.games_view == Settings.GamesView.LIST ? (Widget) games_list_paned : (Widget) games_grid_scrolled);

			load_games.begin();
		}

		private async void load_games()
		{
			foreach(var src in sources)
			{
				loading_sources++;
				spinner.active = loading_sources > 0;
				src.load_games.begin(g => {
					games_grid.add(new GameCard(g));
					games_list.add(new GameListRow(g));
					games_grid.show_all();
					games_list.show_all();

					var pv = new GameDownloadProgressView(g);
					downloads_list.add(pv);
					g.status_change.connect(s => {
						if(s.state == DOWNLOAD_STARTED) downloads_count++;
						else if(s.state == DOWNLOAD_FINISHED) downloads_count--;
						pv.visible = s.state == Game.State.DOWNLOADING || s.state == Game.State.DOWNLOAD_STARTED;
						downloads.set_sensitive(downloads_count > 0);
					});
					g.status_change(g.status);
				}, (obj, res) => {
					loading_sources--;
					spinner.active = loading_sources > 0;
				});
			}

			games_list.select_row(games_list.get_row_at_index(0));
		}

		private void add_view_button(Image image, string tooltip)
		{
			image.tooltip_text = tooltip;
			view.append(image);
		}

		private void add_filter_button(Image image, string tooltip)
		{
			image.tooltip_text = tooltip;
			filter.append(image);
		}
	}
}
