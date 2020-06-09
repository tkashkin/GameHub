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


using GameHub.Data;
using GameHub.Data.Providers;

namespace GameHub.UI.Widgets
{
	class ImagesDownloadPopover: Popover
	{
		public Game game { get; construct; }

		private Box vbox;
		private Box search_links;

		private Stack stack;
		private Spinner spinner;
		private AlertView no_images_alert;
		private ScrolledWindow images_scroll;
		private Box images;

		private bool images_load_started = false;

		public ImagesDownloadPopover(Game game, MenuButton button, int r_width=520, int r_height=400)
		{
			Object(game: game, relative_to: button);
			button.popover = this;
			position = PositionType.LEFT;

			images_scroll.set_size_request(int.max(r_width, 520), int.max(r_height, 400));

			button.clicked.connect(load_images);

			game.notify["name"].connect(() => {
				images.foreach(i => i.destroy());
				images_load_started = false;
				stack.visible_child = spinner;
			});
		}

		construct
		{
			vbox = new Box(Orientation.VERTICAL, 0);

			stack = new Stack();
			stack.transition_type = StackTransitionType.CROSSFADE;
			stack.interpolate_size = true;
			stack.no_show_all = true;

			spinner = new Spinner();
			spinner.halign = spinner.valign = Align.CENTER;
			spinner.set_size_request(32, 32);
			spinner.margin = 16;
			spinner.start();

			no_images_alert = new AlertView(_("No images"), _("There are no images found for this game\nMake sure game name is correct"), "dialog-information");
			no_images_alert.get_style_context().remove_class(Gtk.STYLE_CLASS_VIEW);

			images_scroll = new ScrolledWindow(null, null);

			images = new Box(Orientation.VERTICAL, 0);
			images.margin = 4;

			images_scroll.add(images);

			stack.add(spinner);
			stack.add(no_images_alert);
			stack.add(images_scroll);

			spinner.show();
			stack.visible_child = spinner;

			search_links = new Box(Orientation.HORIZONTAL, 8);
			search_links.margin = 8;

			var search_links_label = new Label(_("Search images:"));
			search_links_label.halign = Align.START;
			search_links_label.xalign = 0;
			search_links_label.hexpand = true;
			search_links.add(search_links_label);

			add_search_link("SteamGridDB", "https://steamgriddb.com/game/%s");
			add_search_link("Jinx's SGVI", "https://steam.cryotank.net/?s=%s");
			add_search_link("Google", "https://google.com/search?tbm=isch&tbs=isz:ex,iszw:460,iszh:215&q=%s");

			vbox.add(stack);
			vbox.add(new Separator(Orientation.HORIZONTAL));
			vbox.add(search_links);

			child = vbox;

			vbox.show_all();
			stack.show();
		}

		private void load_images()
		{
			if(images_load_started) return;
			images_load_started = true;

			load_images_async.begin();
		}

		private async void load_images_async()
		{
			foreach(var src in ImageProviders)
			{
				if(!src.enabled) continue;

				var results = yield src.images(game);
				if(results == null || results.size < 1) continue;
				foreach(var result in results)
				{
					if(result != null && result.images != null && result.images.size > 0)
					{
						if(images.get_children().length() > 0)
						{
							var separator = new Separator(Orientation.HORIZONTAL);
							separator.margin = 4;
							separator.margin_bottom = 0;
							images.add(separator);
						}

						var header_hbox = new Box(Orientation.HORIZONTAL, 8);
						header_hbox.margin_start = header_hbox.margin_end = 4;

						var header = Styled.H4Label(result.name);
						header.hexpand = true;

						header_hbox.add(header);

						if(result.url != null)
						{
							var link = new Button.from_icon_name("web-browser-symbolic");
							link.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
							link.tooltip_text = result.url;
							link.clicked.connect(() => {
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
							header_hbox.add(link);
						}

						images.add(header_hbox);

						var flow = new FlowBox();
						flow.activate_on_single_click = true;
						flow.homogeneous = true;
						flow.min_children_per_line = 1;
						flow.selection_mode = SelectionMode.SINGLE;

						flow.child_activated.connect(i => {
							var item = (ImageItem) i;

							if(item.size.width >= item.size.height)
							{
								game.image = item.image.url;
							}
							else
							{
								game.image_vertical = item.image.url;
							}
							game.save();

							#if GTK_3_22
							popdown();
							#else
							hide();
							#endif
						});

						foreach(var img in result.images)
						{
							var item = new ImageItem(img, result.image_size, src, game);
							flow.add(item);
							if(img.url == game.image)
							{
								flow.select_child(item);
								item.grab_focus();
							}
						}

						images.add(flow);
					}
				}
			}

			if(images.get_children().length() > 0)
			{
				images_scroll.show_all();
				stack.visible_child = images_scroll;
			}
			else
			{
				no_images_alert.show_all();
				stack.visible_child = no_images_alert;
			}
		}

		private void add_search_link(string text, string url)
		{
			var link = new LinkButton.with_label(url.printf(Uri.escape_string(game.name)), text);
			link.halign = Align.START;
			link.margin = 0;
			search_links.add(link);
		}

		private class ImageItem: FlowBoxChild
		{
			public ImagesProvider.Image image { get; construct; }
			public ImagesProvider.ImageSize size { get; construct; }

			public ImagesProvider provider { get; construct; }
			public Game game { get; construct; }

			public ImageItem(ImagesProvider.Image image, ImagesProvider.ImageSize size, ImagesProvider provider, Game game)
			{
				Object(image: image, size: size, provider: provider, game: game);
			}

			construct
			{
				margin = 0;

				var card = Styled.Card("gamecard", "static");
				card.sensitive = false;
				card.margin = 4;

				card.tooltip_markup = image.description;

				var img = new AutoSizeImage();
				img.load(image.url, null, @"games/$(game.source.id)/$(game.id)/images/providers/$(provider.id)/");

				card.add(img);

				child = card;

				var ratio = (float) size.height / size.width;

				var w_1x = size.width > 500 ? size.width / 2 : size.width;

				var min = int.max((int) (w_1x / 2f), 100);
				var max = int.min(w_1x, 460);
				img.set_constraint(min, max, ratio);

				show_all();
			}
		}
	}
}
