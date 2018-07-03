using Gtk;
using Gee;
using Granite;
using GameHub.Data;
using GameHub.Utils;

namespace GameHub.UI.Views
{
	public class GamesGridFlowBox: Gtk.FlowBox
	{
		
	}
	
	public class GamesGridView: BaseView
	{
		private ArrayList<GameSource> sources = new ArrayList<GameSource>();
		
		private GamesGridFlowBox games_list;
		
		private Granite.Widgets.ModeButton filter;
		private SearchEntry search;
		
		private Spinner spinner;
		private int loading_sources = 0;
		
		private Button settings;
		
		private MenuButton downloads;
		private Popover downloads_popover;
		private ListBox downloads_list;
		
		construct
		{
			var ui_settings = Settings.UI.get_instance();
			
			foreach(var src in GameSources)
			{
				if(src.enabled && src.is_authenticated()) sources.add(src);
			}
			
			games_list = new GamesGridFlowBox();
			games_list.margin = 4;
			
			games_list.activate_on_single_click = false;
			games_list.homogeneous = false;
			games_list.min_children_per_line = 2;
			games_list.selection_mode = SelectionMode.NONE;
			games_list.valign = Align.START;

			var scrolled = new ScrolledWindow(null, null);
			scrolled.expand = true;
			scrolled.hscrollbar_policy = PolicyType.NEVER;
			scrolled.add(games_list);
			add(scrolled);
			
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
			downloads_popover.add(downloads_list);
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
			
			games_list.set_sort_func((child1, child2) => {
				var item1 = child1 as GameCard;
				var item2 = child2 as GameCard;
				if(item1 != null && item2 != null)
				{
					return item1.game.name.collate(item2.game.name);
				}
				return 0;
			});
			
			games_list.set_filter_func(child => {
				var item = child as GameCard;
				var f = filter.selected;
				
				GameSource? src = null;
				if(f > 0) src = sources[f - 1];
				
				var games = src == null ? games_list.get_children().length() : src.games_count;
				titlebar.title = "GameHub" + (src == null ? "" : "/" + src.name);
				titlebar.subtitle = ngettext("%u game", "%u games", games).printf(games);
				
				return (src == null || item == null || src == item.game.source) && (item == null || search.text.casefold() in item.game.name.casefold());
			});
			
			filter.mode_changed.connect(games_list.invalidate_filter);
			search.search_changed.connect(games_list.invalidate_filter);
			
			spinner = new Spinner();
			
			titlebar.pack_end(settings);
			titlebar.pack_end(downloads);
			titlebar.pack_end(search);
			titlebar.pack_end(spinner);
			
			show_all();
			scrolled.show_all();
			games_list.show_all();
			
			load_games.begin();
		}
		
		private async void load_games()
		{
			foreach(var src in sources)
			{
				loading_sources++;
				spinner.active = loading_sources > 0;
				src.load_games.begin(g => {
					var card = new GameCard(g);
					card.installation_started.connect(p => {
						downloads_list.add(p);
						downloads_list.show_all();
						downloads.set_sensitive(true);
					});
					card.installation_finished.connect(p => {
						downloads_list.remove(p);
						var has_downloads = downloads_list.get_children().length() > 0;
						downloads.set_sensitive(has_downloads);
						if(!has_downloads) downloads_popover.hide();
					});
					games_list.add(card);
					games_list.show_all();
				}, (obj, res) => {
					loading_sources--;
					spinner.active = loading_sources > 0;
				});
			}
		}
		
		private void add_filter_button(Image image, string tooltip)
		{
			image.tooltip_text = tooltip;
			filter.append(image);
		}
	}
}
