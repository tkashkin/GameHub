/*
This file is part of GameHub.
Copyright (C) Anatoliy Kashkin

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
using Gee;

using GameHub.Data.DB;
using GameHub.Data.Runnables;
using GameHub.Utils;
using GameHub.Settings;

using GameHub.UI.Widgets;
using GameHub.UI.Views.GamesView;
using GameHub.UI.Views.GamesView.List;
using GameHub.UI.Views.GamesView.Grid;

namespace GameHub.Data.Adapters
{
	public class GamesAdapter: Object
	{
		public signal void cache_loaded();

		private Settings.UI.Behavior settings;
		public bool filter_settings_merge = true;

		public GameSource? filter_source { get; set; default = null; }
		public ArrayList<Tables.Tags.Tag> filter_tags;
		public SortMode sort_mode = SortMode.NAME;
		public GroupMode group_mode = GroupMode.STATUS;
		public PlatformFilter filter_platform = PlatformFilter.ALL;
		public string filter_search_query = "";

		private ArrayList<GameSource> sources = new ArrayList<GameSource>();
		private ArrayList<GameSource> loading_sources = new ArrayList<GameSource>();

		private ArrayList<Game> games = new ArrayList<Game>();

		private bool new_games_added = false;

		public weak GamesGrid? grid;
		public weak GamesList? list;

		private HashMap<Game, ViewHolder> view_cache = new HashMap<Game, ViewHolder>();

		public string? status { get; private set; default = null; }

		#if UNITY
		public Unity.LauncherEntry launcher_entry;
		public Dbusmenu.Menuitem launcher_menu;
		#endif

		public GamesAdapter()
		{
			foreach(var src in GameSources)
			{
				if(src.enabled && src.is_authenticated())
				{
					sources.add(src);
				}
			}

			settings = Settings.UI.Behavior.instance;
			filter_settings_merge = settings.merge_games;

			settings.notify["merge-games"].connect(() => invalidate());

			#if UNITY
			launcher_entry = Unity.LauncherEntry.get_for_desktop_id(Config.RDNN + ".desktop");
			setup_launcher_menu();
			#endif
		}

		public void attach_grid(GamesGrid? grid)
		{
			this.grid = grid;
			if(this.grid != null)
			{
				this.grid.set_filter_func(c => {
					return filter(((GameCard) c).game);
				});
				this.grid.set_sort_func((c, c2) => {
					return sort(((GameCard) c).game, ((GameCard) c2).game);
				});
				add_cached_views(false);
			}
		}

		public void attach_list(GamesList? list)
		{
			this.list = list;
			if(this.list != null)
			{
				this.list.set_filter_func(r => {
					return filter(((GameListRow) r).game);
				});
				this.list.set_sort_func((r, r2) => {
					return sort(((GameListRow) r).game, ((GameListRow) r2).game);
				});
				this.list.set_header_func(list_header);
				add_cached_views(false);
			}
		}

		public void invalidate(bool filter=true, bool sort=true, bool headers=true)
		{
			filter_settings_merge = settings.merge_games;
			if(filter)
			{
				if(grid != null) grid.invalidate_filter();
				if(list != null) list.invalidate_filter();
			}
			if(sort)
			{
				if(grid != null) grid.invalidate_sort();
				if(list != null) list.invalidate_sort();
			}
			if(headers)
			{
				if(list != null) list.invalidate_headers();
			}
		}

		public void load_games(Utils.FutureResult<GameSource> loaded_callback)
		{
			Utils.thread("GamesAdapterLoad", () => {
				foreach(var src in sources)
				{
					loading_sources.add(src);
					update_loading_status();
					src.load_games.begin(add, () => { add_cached_views(); }, (obj, res) => {
						src.load_games.end(res);
						loading_sources.remove(src);
						update_loading_status();
						loaded_callback(src);
						if(loading_sources.size == 0 && new_games_added)
						{
							if(new_games_added)
							{
								merge_games();
							}
							else
							{
								status = null;
							}
						}
					});
				}
			});
		}

		public void add(Game game, bool is_cached=false)
		{
			games.add(game);
			var holder = new ViewHolder(game, this);
			lock(view_cache)
			{
				view_cache.set(game, holder);
			}
			if(!is_cached)
			{
				new_games_added = true;
				Idle.add(() => {
					add_views(game, holder);
					return Source.REMOVE;
				}, Priority.LOW);
			}
			if(game is Sources.User.UserGame)
			{
				((Sources.User.UserGame) game).removed.connect(() => {
					remove(game);
				});
			}

			#if UNITY
			add_game_to_launcher_favorites_menu(game);
			#endif
		}

		private void add_views(Game game, ViewHolder? holder=null)
		{
			holder = holder ?? view_cache.get(game);
			if(holder != null)
			{
				holder.add_views(grid, list);

				if(grid != null && holder.grid_card != null)
				{
					holder.grid_card.show_all();
					if(grid.get_children().length() == 0)
					{
						holder.grid_card.grab_focus();
					}
				}

				if(list != null && holder.list_row != null)
				{
					holder.list_row.show_all();
					if(list.get_selected_row() == null)
					{
						list.select_row(holder.list_row);
					}
				}

				if(!filter(game))
				{
					if(holder.grid_card != null) holder.grid_card.changed();
					if(holder.list_row != null) holder.list_row.changed();
				}
			}
		}

		private void add_cached_views(bool invoke_cache_loaded_signal=true)
		{
			Idle.add(() => {
				lock(view_cache)
				{
					foreach(var holder in view_cache.values)
					{
						add_views(holder.game, holder);
					}
				}
				if(invoke_cache_loaded_signal) cache_loaded();
				return Source.REMOVE;
			}, Priority.LOW);
		}

		public void remove(Game game)
		{
			games.remove(game);

			ViewHolder? holder;
			lock(view_cache)
			{
				view_cache.unset(game, out holder);
			}

			if(holder != null)
			{
				holder.destroy();
			}
		}

		public bool filter(Game? game)
		{
			if(game == null) return false;

			bool same_src = (filter_source == null || game == null || filter_source == game.source);
			bool merged_src = false;

			ArrayList<Game>? merges = null;

			Platform[] platforms = {};

			if(filter_platform != PlatformFilter.ALL)
			{
				foreach(var p in game.platforms)
				{
					if(!(p in platforms)) platforms += p;
				}
			}

			if(filter_settings_merge)
			{
				merges = Tables.Merges.get(game);
				var primary = Tables.Merges.get_primary(game);
				if(merges != null && merges.size > 0)
				{
					foreach(var g in merges)
					{
						if(g.source == filter_source)
						{
							merged_src = true;
							if(filter_platform == PlatformFilter.ALL || filter_source != null) break;
						}

						if(filter_platform != PlatformFilter.ALL && filter_source == null)
						{
							foreach(var p in g.platforms)
							{
								if(!(p in platforms)) platforms += p;
							}
						}
					}
				}
				if(primary != null && filter_platform != PlatformFilter.ALL && filter_source == null)
				{
					foreach(var p in primary.platforms)
					{
						if(!(p in platforms)) platforms += p;
					}
				}
			}

			if(filter_platform != PlatformFilter.ALL && !(filter_platform.platform() in platforms)) return false;

			bool tags_all_enabled = filter_tags == null || filter_tags.size == 0 || filter_tags.size == Tables.Tags.TAGS.size;
			bool tags_all_except_hidden_enabled = filter_tags != null && filter_tags.size == Tables.Tags.TAGS.size - 1 && !(Tables.Tags.BUILTIN_HIDDEN in filter_tags);
			bool tags_match = false;
			bool tags_match_merged = false;

			if(!tags_all_enabled)
			{
				foreach(var tag in filter_tags)
				{
					tags_match = game.has_tag(tag);
					if(tags_match) break;
				}
				if(!tags_match && merges != null && merges.size > 0)
				{
					foreach(var g in merges)
					{
						foreach(var tag in filter_tags)
						{
							tags_match_merged = g.has_tag(tag);
							if(tags_match_merged) break;
						}
					}
				}
			}

			bool hidden = game.has_tag(Tables.Tags.BUILTIN_HIDDEN) && (filter_tags == null || filter_tags.size == 0 || !(Tables.Tags.BUILTIN_HIDDEN in filter_tags));

			return (same_src || merged_src) && (tags_all_enabled || tags_all_except_hidden_enabled || tags_match || tags_match_merged) && !hidden && Utils.strip_name(filter_search_query).casefold() in Utils.strip_name(game.name).casefold();
		}

		public int sort(Game? game1, Game? game2)
		{
			if(game1 != null && game2 != null)
			{
				var s1 = game1.status.state;
				var s2 = game2.status.state;

				var f1 = game1.has_tag(Tables.Tags.BUILTIN_FAVORITES);
				var f2 = game2.has_tag(Tables.Tags.BUILTIN_FAVORITES);

				if(f1 && !f2) return -1;
				if(f2 && !f1) return 1;

				switch(group_mode)
				{
					case GroupMode.STATUS:
						if(s1 == Game.State.DOWNLOADING && s2 != Game.State.DOWNLOADING) return -1;
						if(s1 != Game.State.DOWNLOADING && s2 == Game.State.DOWNLOADING) return 1;
						if(s1 == Game.State.INSTALLING && s2 != Game.State.INSTALLING) return -1;
						if(s1 != Game.State.INSTALLING && s2 == Game.State.INSTALLING) return 1;
						if(s1 == Game.State.INSTALLED && s2 != Game.State.INSTALLED) return -1;
						if(s1 != Game.State.INSTALLED && s2 == Game.State.INSTALLED) return 1;
						break;

					case GroupMode.SOURCE:
						if(game1.source != game2.source)
						{
							return game1.source.id.collate(game2.source.id);
						}
						break;
				}

				switch(sort_mode)
				{
					case SortMode.LAST_LAUNCH:
						if(game1.last_launch > game2.last_launch) return -1;
						if(game1.last_launch < game2.last_launch) return 1;
						break;

					case SortMode.PLAYTIME:
						if(game1.playtime > game2.playtime) return -1;
						if(game1.playtime < game2.playtime) return 1;
						break;
				}

				return game1.name_normalized.collate(game2.name_normalized);
			}
			return 0;
		}

		private void list_header(ListBoxRow row, ListBoxRow? prev)
		{
			if(group_mode == GroupMode.NONE)
			{
				row.set_header(null);
				return;
			}

			var item = row as GameListRow;
			var prev_item = prev as GameListRow;
			var s = item.game.status.state;
			var ps = prev_item != null ? prev_item.game.status.state : s;
			var f = item.game.has_tag(Tables.Tags.BUILTIN_FAVORITES);
			var pf = prev_item != null ? prev_item.game.has_tag(Tables.Tags.BUILTIN_FAVORITES) : f;

			if(group_mode == GroupMode.STATUS && prev_item != null && f == pf && (f || s == ps))
			{
				row.set_header(null);
				return;
			}

			var src = item.game.source;
			var psrc = prev_item != null ? prev_item.game.source : src;

			if(group_mode == GroupMode.SOURCE && prev_item != null && src == psrc && f == pf)
			{
				row.set_header(null);
				return;
			}

			var header = new Box(Orientation.HORIZONTAL, 6);
			StyleClass.add(header, "games-list-header");
			if(prev_item == null) StyleClass.add(header, "first");
			header.hexpand = true;

			var label = Styled.H4Label(null);
			label.hexpand = true;
			label.xalign = 0;
			label.ellipsize = Pango.EllipsizeMode.END;

			switch(group_mode)
			{
				case GroupMode.STATUS:
					if(f)
					{
						var icon = new Image.from_icon_name("gh-game-favorite-symbolic", IconSize.MENU);
						icon.valign = icon.valign = Align.CENTER;
						icon.pixel_size = 12;
						icon.margin = 2;
						header.add(icon);
					}
					label.label = f ? C_("status_header", "Favorites") : item.game.status.header;
					break;

				case GroupMode.SOURCE:
					header.add(new Image.from_icon_name(src.icon, IconSize.MENU));
					label.label = f ? C_("status_header", "%s: Favorites").printf(src.name) : src.name;
					break;
			}

			header.add(label);
			header.show_all();
			row.set_header(header);
		}

		public int games_count
		{
			get
			{
				return games.size;
			}
		}

		public int filtered_games_count
		{
			get
			{
				var count = 0;
				foreach(var game in games)
				{
					if(filter(game)) count++;
				}
				return count;
			}
		}

		public bool has_filtered_games
		{
			get
			{
				foreach(var game in games)
				{
					if(filter(game)) return true;
				}
				return false;
			}
		}

		private void merge_games()
		{
			if(!filter_settings_merge) return;
			Utils.thread("GamesAdapterMerge", () => {
				status = _("Merging games");
				foreach(var src in sources)
				{
					merge_games_from(src);
				}
				status = null;
			});
		}

		private void merge_games_from(GameSource src)
		{
			if(!filter_settings_merge) return;
			debug("[Merge] Merging %s games", src.name);
			status = _("Merging games from %s").printf(src.name);
			foreach(var game in src.games)
			{
				merge_game(game);
			}
		}

		private void merge_game(Game game)
		{
			if(!filter_settings_merge || game is Sources.GOG.GOGGame.DLC) return;
			foreach(var src in sources)
			{
				foreach(var game2 in src.games)
				{
					merge_game_with_game(src, game, game2);
				}
			}
		}

		private void merge_game_with_game(GameSource src, Game game, Game game2)
		{
			if(Game.is_equal(game, game2) || game2 is Sources.GOG.GOGGame.DLC) return;

			if(Tables.Merges.is_game_merged(game) || Tables.Merges.is_game_merged(game2) || Tables.Merges.is_game_merged_as_primary(game2)) return;

			bool name_match_exact = game.name_normalized.casefold() == game2.name_normalized.casefold();
			bool name_match_fuzzy_prefix = game.source != src
			                  && (Utils.strip_name(game.name, ":", true).casefold().has_prefix(game2.name_normalized.casefold() + ":")
			                  || Utils.strip_name(game2.name, ":", true).casefold().has_prefix(game.name_normalized.casefold() + ":"));
			if(name_match_exact || name_match_fuzzy_prefix)
			{
				debug("[Merge] Merging '%s' (%s) with '%s' (%s)", game.name, game.full_id, game2.name, game2.full_id);
				Tables.Merges.add(game, game2);
				remove(game2);
				game.update_status();
			}
		}

		private void update_loading_status()
		{
			if(loading_sources.size > 0)
			{
				string[] src_names = {};
				foreach(var s in loading_sources)
				{
					src_names += s.name;
				}
				status = _("Loading games from %s").printf(string.joinv(", ", src_names));
			}
			else
			{
				status = null;
			}
		}

		#if UNITY
		private void setup_launcher_menu()
		{
			launcher_menu = new Dbusmenu.Menuitem();
			launcher_entry.quicklist = launcher_menu;
		}

		private Dbusmenu.Menuitem launcher_menu_separator()
		{
			var separator = new Dbusmenu.Menuitem();
			separator.property_set(Dbusmenu.MENUITEM_PROP_TYPE, Dbusmenu.CLIENT_TYPES_SEPARATOR);
			return separator;
		}

		private void add_game_to_launcher_favorites_menu(Game game)
		{
			var added = false;
			Dbusmenu.Menuitem? item = null;

			SourceFunc update = () => {
				Idle.add(() => {
					var favorite = game.has_tag(Tables.Tags.BUILTIN_FAVORITES);
					if(!added && favorite)
					{
						if(item == null)
						{
							item = new Dbusmenu.Menuitem();
							item.property_set(Dbusmenu.MENUITEM_PROP_LABEL, game.name);
							item.item_activated.connect(() => { game.run_or_install.begin(); });
						}
						launcher_menu.child_append(item);
						added = true;
					}
					else if(added && !favorite)
					{
						if(item != null)
						{
							launcher_menu.child_delete(item);
						}
						added = false;
					}
					return Source.REMOVE;
				}, Priority.LOW);
				return Source.REMOVE;
			};

			game.tags_update.connect(() => update());
			update();
		}
		#endif

		private class ViewHolder
		{
			public GamesAdapter adapter;
			public Game game;
			public GameCard? grid_card = null;
			public GameListRow? list_row = null;

			public ViewHolder(Game game, GamesAdapter adapter)
			{
				this.adapter = adapter;
				this.game = game;

				this.game.notify["tags"].connect(() => {
					Idle.add(() => {
						if(grid_card != null) grid_card.changed();
						if(list_row != null) list_row.changed();
						return Source.REMOVE;
					}, Priority.LOW);
				});
			}

			public void init_views(bool init_card=true, bool init_row=true)
			{
				if(grid_card == null && init_card) grid_card = new GameCard(game, adapter);
				if(list_row == null && init_row) list_row = new GameListRow(game, adapter);
			}

			public void add_views(GamesGrid? grid, GamesList? list)
			{
				init_views(grid != null, list != null);
				if(grid != null)
				{
					var old_parent = grid_card.parent;
					if(old_parent != grid)
					{
						if(old_parent != null) old_parent.remove(grid_card);
						grid.add(grid_card);
					}
				}
				if(list != null)
				{
					var old_parent = list_row.parent;
					if(old_parent != list)
					{
						if(old_parent != null) old_parent.remove(list_row);
						list.add(list_row);
					}
				}
			}

			public void destroy()
			{
				Idle.add(() => {
					if(grid_card != null) grid_card.destroy();
					if(list_row != null) list_row.destroy();
					return Source.REMOVE;
				}, Priority.LOW);
			}
		}

		public enum SortMode
		{
			NAME = 0, LAST_LAUNCH = 1, PLAYTIME = 2;

			public string name()
			{
				switch(this)
				{
					case SortMode.NAME:        return C_("sort_mode", "By name");
					case SortMode.LAST_LAUNCH: return C_("sort_mode", "By last launch");
					case SortMode.PLAYTIME:    return C_("sort_mode", "By playtime");
				}
				assert_not_reached();
			}

			public string icon()
			{
				switch(this)
				{
					case SortMode.NAME:        return "insert-text-symbolic";
					case SortMode.LAST_LAUNCH: return "document-open-recent-symbolic";
					case SortMode.PLAYTIME:    return "preferences-system-time-symbolic";
				}
				assert_not_reached();
			}
		}

		public enum GroupMode
		{
			NONE = 0, STATUS = 1, SOURCE = 2;

			public string name()
			{
				switch(this)
				{
					case GroupMode.NONE:   return C_("group_mode", "Do not group");
					case GroupMode.STATUS: return C_("group_mode", "By status");
					case GroupMode.SOURCE: return C_("group_mode", "By source");
				}
				assert_not_reached();
			}

			public string icon()
			{
				switch(this)
				{
					case GroupMode.NONE:   return "process-stop-symbolic";
					case GroupMode.STATUS: return "view-continuous-symbolic";
					case GroupMode.SOURCE: return "sources-all-symbolic";
				}
				assert_not_reached();
			}
		}

		public enum PlatformFilter
		{
			ALL = 0, LINUX = 1, WINDOWS = 2, MACOS = 3, EMULATED = 4;

			public const PlatformFilter[] FILTERS = { PlatformFilter.ALL, PlatformFilter.LINUX, PlatformFilter.WINDOWS, PlatformFilter.MACOS, PlatformFilter.EMULATED };

			public Data.Platform platform()
			{
				switch(this)
				{
					case PlatformFilter.LINUX:    return Data.Platform.LINUX;
					case PlatformFilter.WINDOWS:  return Data.Platform.WINDOWS;
					case PlatformFilter.MACOS:    return Data.Platform.MACOS;
					case PlatformFilter.EMULATED: return Data.Platform.EMULATED;
				}
				assert_not_reached();
			}
		}
	}
}
