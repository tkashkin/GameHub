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
using GameHub.Utils;
using GameHub.UI.Widgets;

namespace GameHub.UI.Views.GameDetailsView.Blocks
{
	public class IGDBInfo: GameDetailsBlock
	{
		public Description description_block { private get; construct; }
		public IGDBDescription description { get; construct; }

		private ArrayList<Providers.Data.IGDB.Result>? results;
		private int result_index = 0;

		public IGDBInfo(Game game, Description desc, bool is_dialog)
		{
			Object(game: game, orientation: Orientation.VERTICAL, description_block: desc, text_max_width: 48, description: new IGDBDescription(game, desc, is_dialog));
		}

		construct
		{
			if(!supports_game) return;

			get_style_context().add_class("igdb-data-container");

			Providers.Data.IGDB.instance.data.begin(game, (obj, res) => {
				results = Providers.Data.IGDB.instance.data.end(res);
				if(results == null || results.size == 0) return;
				set_result_index(DB.Tables.IGDBData.get_index(game));
			});
		}

		private void set_result(Providers.Data.IGDB.Result result)
		{
			this.foreach(w => w.destroy());

			var igdb_link_hbox = new Box(Orientation.HORIZONTAL, 0);
			StyleClass.add(igdb_link_hbox, Gtk.STYLE_CLASS_LINKED);

			var igdb_link = new ActionButton(Providers.Data.IGDB.instance.icon, null, "IGDB", true, true);
			igdb_link.hexpand = true;
			if(result.url != null)
			{
				igdb_link.tooltip_text = result.url;
				igdb_link.clicked.connect(() => {
					try
					{
						Utils.open_uri(result.url);
					}
					catch(Utils.RunError error)
					{
						//FIXME [DEV-ART]: Replace this with inline error display?
						GameHub.UI.Dialogs.QuickErrorDialog.display_and_log.begin(
							this, error, Log.METHOD,
							_("Opening website “%s” failed").printf(result.url)
						);
					}
				});
			}
			else
			{
				igdb_link.sensitive = false;
			}

			igdb_link_hbox.add(igdb_link);

			if(results.size > 1)
			{
				var menu = new Gtk.Menu();
				menu.halign = Align.END;

				for(int i = 0; i < results.size; i++)
				{
					var index = i;
					var item = new CheckMenuItem.with_label(results[index].name);
					item.draw_as_radio = true;
					item.active = index == result_index;
					item.activate.connect(() => {
						set_result_index(index);
					});
					menu.add(item);
				}

				menu.show_all();

				var menu_btn = new MenuButton();
				StyleClass.add(menu_btn, Gtk.STYLE_CLASS_FLAT);
				menu_btn.popup = menu;

				igdb_link_hbox.add(menu_btn);
			}

			add(igdb_link_hbox);

			if(result.popularity != null)
			{
				add(new Separator(Orientation.HORIZONTAL));
				add_label(C_("igdb", "Popularity"), "%.1f".printf(result.popularity), false, true);
			}

			if((result.aggregated_rating_count != null && result.aggregated_rating_count > 0) || (result.igdb_rating_count != null && result.igdb_rating_count > 0) || (result.total_rating_count != null && result.total_rating_count > 0))
			{
				add(new Separator(Orientation.HORIZONTAL));
				add_rating(C_("igdb", "Aggregated rating"), result.aggregated_rating, result.aggregated_rating_count);
				add_rating(C_("igdb", "IGDB user rating"), result.igdb_rating, result.igdb_rating_count);
				add_rating(C_("igdb", "Total rating"), result.total_rating, result.total_rating_count);
			}

			if(result.release_date != null)
			{
				var date = new DateTime.from_unix_utc(result.release_date);
				if(date != null)
				{
					add(new Separator(Orientation.HORIZONTAL));
					add_label(C_("igdb", "Release date"), date.format("%x"), false, true);
				}
			}

			if(result.platforms != null)
			{
				add(new Separator(Orientation.HORIZONTAL));
				add_link_list(C_("igdb", "Platforms"), result.platforms);
			}

			if(result.genres != null)
			{
				add(new Separator(Orientation.HORIZONTAL));
				add_link_list(C_("igdb", "Genres"), result.genres);
			}

			if(result.keywords != null)
			{
				add(new Separator(Orientation.HORIZONTAL));
				add_link_list(C_("igdb", "Keywords"), result.keywords);
			}

			if(result.websites != null)
			{
				add(new Separator(Orientation.HORIZONTAL));

				var links_label = Styled.H4Label(C_("igdb", "Links"));
				links_label.margin_start = links_label.margin_end = 7;
				links_label.get_style_context().add_class("igdb-data-container-scrollable-header");
				links_label.valign = Align.START;
				add(links_label);

				var links_scroll = new ScrolledWindow(null, null);
				links_scroll.get_style_context().add_class("igdb-data-container-scrollable-value");
				links_scroll.vscrollbar_policy = PolicyType.NEVER;
				links_scroll.hexpand = true;

				var links_box = new Box(Orientation.HORIZONTAL, 0);
				links_box.get_style_context().add_class("gameinfo-multiline-value");
				links_box.margin_start = links_box.margin_end = 3;

				foreach(var site in result.websites)
				{
					var category_desc = site.category.description();
					var desc = """<span size="smaller">%s</span>""".printf(site.url);
					if(category_desc != null)
					{
						desc = "%s\n%s".printf("""<span weight="600">%s</span>""".printf(category_desc), desc);
					}
					var link = new ActionButton(site.category.icon(), null, desc, false, true);
					link.clicked.connect(() => {
						try
						{
							Utils.open_uri(site.url);
						}
						catch(Utils.RunError error)
						{
							//FIXME [DEV-ART]: Replace this with inline error display?
							GameHub.UI.Dialogs.QuickErrorDialog.display_and_log.begin(
								this, error, Log.METHOD,
								_("Opening website “%s” failed").printf(site.url)
							);
						}
					});
					links_box.add(link);
				}

				links_scroll.add(links_box);
				add(links_scroll);
			}

			description.result = result;

			show_all();
			parent.queue_draw();
		}

		private void set_result_index(int index)
		{
			if(results.size > index)
			{
				result_index = index;
				DB.Tables.IGDBData.set_index(game, index);
				set_result(results[index]);
			}
		}

		public override bool supports_game { get { return Providers.Data.IGDB.instance.enabled; } }

		private void add_rating(string label, double? rating, int? count, Box? parent=null)
		{
			if(rating == null || count == null || count < 1) return;
			var box = add_label(label, "<b>%.1f</b> / 100".printf(rating), false, true, parent);
			box.tooltip_markup = ngettext("Based on <b>%d</b> rating", "Based on <b>%d</b> ratings", count).printf(count);
		}

		private Box? add_label(string title, string? text, bool multiline=true, bool markup=false, Container? parent=null)
		{
			var box = add_info_label(title, text, multiline, markup, parent);
			if(box != null)
			{
				box.margin_start -= 1;
				box.margin_end -= 1;
			}
			return box;
		}

		private Box? add_link_list(string title, Providers.Data.IGDB.Result.Link[] links, Container? parent=null)
		{
			var title_label = Styled.H4Label(title);
			title_label.margin_start = title_label.margin_end = 7;
			title_label.get_style_context().add_class("igdb-data-container-scrollable-header");
			title_label.set_size_request(128, -1);
			title_label.valign = Align.CENTER;

			var links_scroll = new ScrolledWindow(null, null);
			links_scroll.get_style_context().add_class("igdb-data-container-scrollable-value");
			links_scroll.vscrollbar_policy = PolicyType.NEVER;
			links_scroll.hexpand = true;

			var links_box = new Box(Orientation.HORIZONTAL, 0);
			links_box.margin_start = links_box.margin_end = 7;
			links_box.get_style_context().add_class("gameinfo-multiline-value");
			links_box.hexpand = false;

			foreach(var link in links)
			{
				var button = new LinkButton.with_label(link.url, link.name);
				button.hexpand = false;
				if(links_box.get_children().length() > 0)
				{
					links_box.add(new Label(", "));
				}
				links_box.add(button);
			}

			links_scroll.add(links_box);

			var box = new Box(Orientation.VERTICAL, 0);
			box.add(title_label);
			box.add(links_scroll);
			(parent ?? this).add(box);

			return box;
		}

		public class IGDBDescription: GameDetailsBlock
		{
			public Description description_block { private get; construct; }
			public Providers.Data.IGDB.Result? result { get; set; }

			public IGDBDescription(Game game, Description desc, bool is_dialog)
			{
				Object(game: game, orientation: Orientation.VERTICAL, description_block: desc, text_max_width: is_dialog ? 80 : -1);
			}

			construct
			{
				if(!supports_game) return;

				get_style_context().add_class("igdb-data-container");

				notify["result"].connect(() => {
					this.hide();
					this.foreach(w => w.destroy());

					if(result == null) return;

					var preferred_desc = Settings.Providers.Data.IGDB.instance.preferred_description;
					var game_has_desc = description_block.supports_game && game.description != null;

					if(preferred_desc != Settings.Providers.Data.IGDB.PreferredDescription.GAME || !game_has_desc)
					{
						if(result.summary != null)
						{
							add_label(C_("igdb", "Summary"), result.summary, true, false);

							if(preferred_desc == Settings.Providers.Data.IGDB.PreferredDescription.IGDB)
							{
								description_block.destroy();
							}
						}

						if(result.storyline != null)
						{
							if(result.summary != null) add(new Separator(Orientation.HORIZONTAL));
							add_label(C_("igdb", "Storyline"), result.storyline, true, false);
						}

						show_all();
						if(parent != null) parent.queue_draw();
					}
				});
			}

			public override bool supports_game { get { return Providers.Data.IGDB.instance.enabled; } }

			private Box? add_label(string title, string? text, bool multiline=true, bool markup=false, Container? parent=null)
			{
				var box = add_info_label(title, text, multiline, markup, parent);
				if(box != null)
				{
					box.margin_start -= 1;
					box.margin_end -= 1;
				}
				return box;
			}
		}
	}
}
