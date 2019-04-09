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
using Gee;
using GameHub.Data.DB;
using GameHub.Utils;

using GameHub.UI.Views.GamesView;

namespace GameHub.Data.Adapters
{
	public class GamesAdapter: Object
	{
		public signal void cache_loaded();

		private Settings.UI ui_settings;
		public bool filter_settings_show_unsupported = true;
		public bool filter_settings_use_compat = true;
		public bool filter_settings_merge = true;

		public GameSource? filter_source = null;
		public ArrayList<Tables.Tags.Tag> filter_tags;
		public Settings.SortMode sort_mode = Settings.SortMode.NAME;
		public string filter_search_query = "";

		private ArrayList<GameSource> sources = new ArrayList<GameSource>();
		private ArrayList<GameSource> loading_sources = new ArrayList<GameSource>();

		private ArrayList<Game> games = new ArrayList<Game>();

		private bool new_games_added = false;

		public FlowBox grid;
		public ListBox list;

		private HashMap<Game, ViewHolder> view_cache = new HashMap<Game, ViewHolder>();

		public GamesAdapter(FlowBox grid, ListBox list)
		{
			foreach(var src in GameSources)
			{
				if(src.enabled && src.is_authenticated())
				{
					sources.add(src);
				}
			}

			this.grid = grid;
			this.list = list;

			ui_settings = Settings.UI.get_instance();
			filter_settings_show_unsupported = ui_settings.show_unsupported_games;
			filter_settings_use_compat = ui_settings.use_compat;
			filter_settings_merge = ui_settings.merge_games;

			ui_settings.notify["show-unsupported-games"].connect(() => invalidate());
			ui_settings.notify["use-proton"].connect(() => invalidate());
			ui_settings.notify["merge-games"].connect(() => invalidate());

			this.grid.set_filter_func(c => {
				return filter((c as GameCard).game);
			});
			this.grid.set_sort_func((c, c2) => {
				return sort((c as GameCard).game, (c2 as GameCard).game);
			});

			this.list.set_filter_func(r => {
				return filter((r as GameListRow).game);
			});
			this.list.set_sort_func((r, r2) => {
				return sort((r as GameListRow).game, (r2 as GameListRow).game);
			});
			this.list.set_header_func(list_header);
		}

		public void invalidate(bool filter=true, bool sort=true)
		{
			filter_settings_show_unsupported = ui_settings.show_unsupported_games;
			filter_settings_use_compat = ui_settings.use_compat;
			filter_settings_merge = ui_settings.merge_games;
			if(filter)
			{
				grid.invalidate_filter();
				list.invalidate_filter();
			}
			if(sort)
			{
				grid.invalidate_sort();
				list.invalidate_sort();
			}
		}

		public void load_games(Utils.FutureResult<GameSource> loaded_callback)
		{
			Utils.thread("GamesAdapterLoad", () => {
				foreach(var src in sources)
				{
					loading_sources.add(src);
					src.load_games.begin(add, () => add_cached_views(), (obj, res) => {
						src.load_games.end(res);
						loading_sources.remove(src);
						loaded_callback(src);
						if(loading_sources.size == 0 && new_games_added)
						{
							merge_games();
						}
					});
				}
			});
		}

		public void add(Game game, bool is_cached=false)
		{
			games.add(game);
			var holder = new ViewHolder(game);
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
		}

		private void add_views(Game game, ViewHolder? holder=null)
		{
			holder = holder ?? view_cache.get(game);
			if(holder != null && !holder.is_added)
			{
				holder.init_views();
				grid.add(holder.grid_card);
				list.add(holder.list_row);
				holder.is_added = true;

				holder.grid_card.show_all();
				holder.list_row.show_all();
				if(!filter(game))
				{
					holder.grid_card.changed();
					holder.list_row.changed();
				}
			}
		}

		private void add_cached_views()
		{
			Idle.add(() => {
				lock(view_cache)
				{
					foreach(var holder in view_cache.values)
					{
						if(!holder.is_added)
						{
							add_views(holder.game, holder);
						}
					}
				}
				cache_loaded();
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

			if(holder != null && holder.is_added)
			{
				holder.destroy();
			}
		}

		private bool filter(Game game)
		{
			if(!filter_settings_show_unsupported && !game.is_supported(null, filter_settings_use_compat)) return false;

			bool same_src = (filter_source == null || game == null || filter_source == game.source);
			bool merged_src = false;

			ArrayList<Game>? merges = null;

			if(filter_settings_merge)
			{
				merges = Tables.Merges.get(game);
				if(!same_src && merges != null && merges.size > 0)
				{
					foreach(var g in merges)
					{
						if(g.source == filter_source)
						{
							merged_src = true;
							break;
						}
					}
				}
			}

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

		private int sort(Game game1, Game game2)
		{
			if(game1 != null && game2 != null)
			{
				var s1 = game1.status.state;
				var s2 = game2.status.state;

				var f1 = game1.has_tag(Tables.Tags.BUILTIN_FAVORITES);
				var f2 = game2.has_tag(Tables.Tags.BUILTIN_FAVORITES);

				if(f1 && !f2) return -1;
				if(f2 && !f1) return 1;

				if(s1 == Game.State.DOWNLOADING && s2 != Game.State.DOWNLOADING) return -1;
				if(s1 != Game.State.DOWNLOADING && s2 == Game.State.DOWNLOADING) return 1;
				if(s1 == Game.State.INSTALLING && s2 != Game.State.INSTALLING) return -1;
				if(s1 != Game.State.INSTALLING && s2 == Game.State.INSTALLING) return 1;
				if(s1 == Game.State.INSTALLED && s2 != Game.State.INSTALLED) return -1;
				if(s1 != Game.State.INSTALLED && s2 == Game.State.INSTALLED) return 1;

				switch(sort_mode)
				{
					case Settings.SortMode.LAST_LAUNCH:
						if(game1.last_launch > game2.last_launch) return -1;
						if(game1.last_launch < game2.last_launch) return 1;
						break;

					case Settings.SortMode.PLAYTIME:
						if(game1.playtime > game2.playtime) return -1;
						if(game1.playtime < game2.playtime) return 1;
						break;
				}

				return game1.normalized_name.collate(game2.normalized_name);
			}
			return 0;
		}

		private void list_header(ListBoxRow row, ListBoxRow? prev)
		{
			var item = row as GameListRow;
			var prev_item = prev as GameListRow;
			var s = item.game.status.state;
			var ps = prev_item != null ? prev_item.game.status.state : s;
			var f = item.game.has_tag(Tables.Tags.BUILTIN_FAVORITES);
			var pf = prev_item != null ? prev_item.game.has_tag(Tables.Tags.BUILTIN_FAVORITES) : f;

			if(prev_item != null && f == pf && (f || s == ps)) row.set_header(null);
			else
			{
				var label = new Granite.HeaderLabel(f ? C_("status_header", "Favorites") : item.game.status.header);
				label.get_style_context().add_class("games-list-header");
				list.size_allocate.connect(alloc => {
					label.set_size_request(alloc.width, -1);
				});
				Allocation alloc;
				list.get_allocation(out alloc);
				label.set_size_request(alloc.width, -1);
				row.set_header(label);
			}
		}

		public bool has_filtered_views()
		{
			foreach(var card in grid.get_children())
			{
				if(filter(((GameCard) card).game))
				{
					return true;
				}
			}
			return false;
		}

		private void merge_games()
		{
			foreach(var src in sources)
			{
				merge_games_from(src);
			}
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

			bool name_match_exact = game.normalized_name.casefold() == game2.normalized_name.casefold();
			bool name_match_fuzzy_prefix = game.source != src
			                  && (Utils.strip_name(game.name, ":", true).casefold().has_prefix(game2.normalized_name.casefold() + ":")
			                  || Utils.strip_name(game2.name, ":", true).casefold().has_prefix(game.normalized_name.casefold() + ":"));
			if(name_match_exact || name_match_fuzzy_prefix)
			{
				Tables.Merges.add(game, game2);
				debug("[Merge] Merging '%s' (%s) with '%s' (%s)", game.name, game.full_id, game2.name, game2.full_id);
				remove(game2);
			}
		}

		private class ViewHolder
		{
			public Game game;
			public GameCard grid_card;
			public GameListRow list_row;
			public bool is_added;

			public ViewHolder(Game game)
			{
				this.game = game;
				is_added = false;

				this.game.tags_update.connect(() => {
					Idle.add(() => {
						grid_card.changed();
						list_row.changed();
						return Source.REMOVE;
					}, Priority.LOW);
				});
			}

			public void init_views()
			{
				grid_card = new GameCard(game);
				list_row = new GameListRow(game);
			}

			public void destroy()
			{
				Idle.add(() => {
					if(grid_card != null) grid_card.destroy();
					if(list_row != null) list_row.destroy();
					is_added = false;
					return Source.REMOVE;
				}, Priority.LOW);
			}
		}
	}
}
