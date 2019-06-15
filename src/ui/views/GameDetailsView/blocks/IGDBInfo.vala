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
using Granite;

using GameHub.Data;
using GameHub.Utils;
using GameHub.UI.Widgets;

namespace GameHub.UI.Views.GameDetailsView.Blocks
{
	public class IGDBInfo: GameDetailsBlock
	{
		public Description description_block { private get; construct; }

		public IGDBInfo(Game game, Description desc, bool is_dialog)
		{
			Object(game: game, orientation: Orientation.VERTICAL, description_block: desc, is_dialog: is_dialog);
		}

		construct
		{
			if(!supports_game) return;

			var revealer = new Revealer();
			revealer.transition_type = RevealerTransitionType.SLIDE_DOWN;
			revealer.transition_duration = 100;
			revealer.reveal_child = false;

			var vbox = new Box(Orientation.VERTICAL, 0);
			vbox.get_style_context().add_class("igdb-data-container");
			vbox.margin_top = vbox.margin_bottom = 4;

			revealer.add(vbox);
			add(revealer);

			Providers.Data.IGDB.instance.data.begin(game, (obj, res) => {
				var result = Providers.Data.IGDB.instance.data.end(res) as Providers.Data.IGDB.Result?;

				if(result == null) return;

				var links_hbox = new Box(Orientation.HORIZONTAL, 0);

				var igdb_link = new ActionButton(Providers.Data.IGDB.instance.icon, null, C_("igdb", "<b>%s</b> on IGDB").printf(result.name ?? game.name), true, true);
				igdb_link.hexpand = true;
				if(result.url != null)
				{
					igdb_link.tooltip_text = result.url;
					igdb_link.clicked.connect(() => {
						Utils.open_uri(result.url);
					});
				}
				else
				{
					igdb_link.sensitive = false;
				}

				links_hbox.add(igdb_link);

				if(result.websites != null)
				{
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
							Utils.open_uri(site.url);
						});
						links_hbox.add(link);
					}
				}

				vbox.add(links_hbox);

				if(result.popularity != null)
				{
					vbox.add(new Separator(Orientation.HORIZONTAL));

					var rating_hbox = new Box(Orientation.HORIZONTAL, 0);

					add_label(C_("igdb", "Popularity"), "<b>%.1f</b>".printf(result.popularity), false, true, rating_hbox);

					add_rating(C_("igdb", "Aggregated rating"), result.aggregated_rating, result.aggregated_rating_count, rating_hbox);
					add_rating(C_("igdb", "IGDB user rating"), result.igdb_rating, result.igdb_rating_count, rating_hbox);
					add_rating(C_("igdb", "Total rating"), result.total_rating, result.total_rating_count, rating_hbox);

					vbox.add(rating_hbox);
				}

				if(result.platforms != null)
				{
					vbox.add(new Separator(Orientation.HORIZONTAL));
					add_link_list(C_("igdb", "Platforms"), result.platforms, vbox);
				}

				if(result.genres != null)
				{
					vbox.add(new Separator(Orientation.HORIZONTAL));
					add_link_list(C_("igdb", "Genres"), result.genres, vbox);
				}

				if(result.keywords != null)
				{
					vbox.add(new Separator(Orientation.HORIZONTAL));
					add_link_list(C_("igdb", "Keywords"), result.keywords, vbox);
				}

				var preferred_desc = Settings.Providers.Data.IGDB.get_instance().preferred_description;

				var game_has_desc = description_block.supports_game && game.description != null;

				if(preferred_desc != Settings.Providers.Data.IGDB.PreferredDescription.GAME || !game_has_desc)
				{
					if(result.summary != null)
					{
						vbox.add(new Separator(Orientation.HORIZONTAL));
						add_label(C_("igdb", "Summary"), result.summary, true, false, vbox);

						if(preferred_desc == Settings.Providers.Data.IGDB.PreferredDescription.IGDB)
						{
							description_block.destroy();
						}
					}

					if(result.storyline != null)
					{
						vbox.add(new Separator(Orientation.HORIZONTAL));
						add_label(C_("igdb", "Storyline"), result.storyline, true, false, vbox);
					}
				}

				vbox.show_all();

				Idle.add(() => {
					vbox.vexpand = true;
					revealer.set_reveal_child(true);
					vbox.vexpand = false;
					return Source.REMOVE;
				});
			});
		}

		public override bool supports_game { get { return Providers.Data.IGDB.instance.enabled; } }

		private void add_rating(string label, double? rating, int? count, Box parent)
		{
			if(rating == null || count == null || count < 1) return;
			parent.add(new Separator(Orientation.VERTICAL));
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
				if(multiline)
					box.margin_bottom = 8;
			}
			return box;
		}

		private Box? add_link_list(string title, Providers.Data.IGDB.Result.Link[] links, Container? parent=null)
		{
			var title_label = new Granite.HeaderLabel(title);
			title_label.set_size_request(128, -1);
			title_label.valign = Align.CENTER;

			var links_scroll = new ScrolledWindow(null, null);
			links_scroll.get_style_context().add_class("igdb-data-container-scrollable-value");
			links_scroll.hexpand = true;

			var links_box = new Box(Orientation.HORIZONTAL, 0);
			links_box.get_style_context().add_class("gameinfo-singleline-value");
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

			var box = new Box(Orientation.HORIZONTAL, 16);
			box.margin_start = links_box.margin_end = 7;
			box.add(title_label);
			box.add(links_scroll);
			(parent ?? this).add(box);

			return box;
		}
	}
}
