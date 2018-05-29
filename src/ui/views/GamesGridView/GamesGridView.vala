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
		
		construct
		{
			foreach(var src in GameSources)
			{
				if(src.is_authenticated()) sources.add(src);
			}
			
			games_list = new GamesGridFlowBox();
			games_list.margin = 4;
			
			games_list.activate_on_single_click = false;
			games_list.homogeneous = true;
			games_list.min_children_per_line = 3;
			games_list.selection_mode = SelectionMode.NONE;
			games_list.valign = Align.START;

			var scrolled = new ScrolledWindow(null, null);
			scrolled.expand = true;
			scrolled.hscrollbar_policy = PolicyType.NEVER;
			scrolled.add(games_list);
			add(scrolled);
			
			filter = new Granite.Widgets.ModeButton();
			filter.append_icon("view-filter-symbolic", IconSize.SMALL_TOOLBAR);
			foreach(var src in sources) filter.append_pixbuf(FSUtils.get_icon(src.icon, 16));
			filter.set_active(sources.size > 1 ? 0 : 1);
			
			search = new SearchEntry();
			
			if(sources.size > 1) titlebar.pack_start(filter);
			titlebar.pack_end(search);
			
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
                titlebar.title = "GameHub" + (src == null ? "" : "/" + src.name) + @": $(games) games";
                
                return (src == null || item == null || src == item.game.source) && (item == null || search.text.casefold() in item.game.name.casefold());
			});
			
			filter.mode_changed.connect(games_list.invalidate_filter);
			search.search_changed.connect(games_list.invalidate_filter);
			
			spinner = new Spinner();
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
					games_list.add(new GameCard(g));
					games_list.show_all();
				}, (obj, res) => {
					loading_sources--;
					spinner.active = loading_sources > 0;
				});
			}
		}
	}
}
