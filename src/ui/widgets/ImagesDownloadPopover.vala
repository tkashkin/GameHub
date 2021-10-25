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

using GameHub.Data;
using GameHub.Data.Providers;
using GameHub.Data.Runnables;

namespace GameHub.UI.Widgets
{
	class ImagesDownloadPopover: Popover
	{
		public Game game { get; construct; }

		private Box search_links;

		private Stack root_stack;
		private Spinner root_spinner;
		private Box content_hbox;

		private ListBox results_list;

		private Stack stack;
		private Spinner spinner;
		private AlertView no_images_alert;
		private ScrolledWindow images_scroll;
		private FlowBox images;

		private Grid images_header;
		private Image images_header_icon;
		private Label images_header_title;
		private Label images_header_subtitle;
		private Button images_header_url;

		private bool results_load_started = false;
		private bool images_load_started = false;

		public ImagesDownloadPopover(Game game, MenuButton button, int r_width=520, int r_height=400)
		{
			Object(game: game, relative_to: button);
			button.popover = this;
			position = PositionType.LEFT;

			set_size_request(int.max(r_width, 520), int.max(r_height, 400));

			button.clicked.connect(load_results);

			game.notify["name"].connect(() => {
				results_load_started = false;
			});
		}

		construct
		{
			var vbox = new Box(Orientation.VERTICAL, 0);

			root_stack = new Stack();
			root_stack.expand = true;
			root_stack.transition_type = StackTransitionType.CROSSFADE;
			root_stack.vhomogeneous = false;
			root_stack.interpolate_size = true;
			root_stack.no_show_all = true;

			root_spinner = new Spinner();
			root_spinner.halign = root_spinner.valign = Align.CENTER;
			root_spinner.set_size_request(32, 32);
			root_spinner.margin = 16;
			root_spinner.start();

			var results_scroll = new ScrolledWindow(null, null);
			results_scroll.set_size_request(200, -1);
			results_scroll.hexpand = false;
			results_scroll.vexpand = true;

			results_list = new ListBox();
			results_list.get_style_context().add_class(Gtk.STYLE_CLASS_BACKGROUND);

			results_list.row_selected.connect(r => {
				var row = (ResultRow) r;
				if(row != null)
				{
					load_images(row.result);
				}
			});

			results_scroll.add(results_list);

			stack = new Stack();
			stack.expand = true;
			stack.transition_type = StackTransitionType.CROSSFADE;
			stack.vhomogeneous = false;
			stack.interpolate_size = true;

			spinner = new Spinner();
			spinner.halign = spinner.valign = Align.CENTER;
			spinner.set_size_request(32, 32);
			spinner.margin = 16;
			spinner.start();

			no_images_alert = new AlertView(_("No images"), _("No images were found for this game"), "dialog-information");
			no_images_alert.get_style_context().remove_class(Gtk.STYLE_CLASS_VIEW);

			images_scroll = new ScrolledWindow(null, null);
			images_scroll.expand = true;

			images_header = new Grid();
			images_header.column_spacing = 12;
			images_header.margin_start = images_header.margin_end = 8;
			images_header.margin_top = 4;
			images_header.no_show_all = true;

			images_header_icon = new Image();
			images_header_icon.icon_size = IconSize.LARGE_TOOLBAR;
			images_header_icon.valign = Align.CENTER;

			images_header_title = new Label(null);
			images_header_title.get_style_context().add_class("category-label");
			images_header_title.hexpand = true;
			images_header_title.ellipsize = Pango.EllipsizeMode.END;
			images_header_title.xalign = 0;
			images_header_title.valign = Align.CENTER;

			images_header_subtitle = new Label(null);
			images_header_subtitle.get_style_context().add_class(Gtk.STYLE_CLASS_DIM_LABEL);
			images_header_subtitle.hexpand = true;
			images_header_subtitle.ellipsize = Pango.EllipsizeMode.END;
			images_header_subtitle.xalign = 0;
			images_header_subtitle.valign = Align.CENTER;

			images_header.attach(images_header_icon, 0, 0, 1, 2);
			images_header.attach(images_header_title, 1, 0);
			images_header.attach(images_header_subtitle, 1, 1);

			images_header_url = new Button.from_icon_name("web-browser-symbolic", IconSize.SMALL_TOOLBAR);
			images_header_url.valign = Align.CENTER;
			images_header_url.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);

			images_header_url.clicked.connect(() => {
				Utils.open_uri(images_header_url.tooltip_text);
			});

			images_header.attach(images_header_url, 2, 0, 1, 2);

			images = new FlowBox();
			images.hexpand = true;
			images.vexpand = false;
			images.valign = Align.START;
			images.margin = 4;
			images.activate_on_single_click = true;
			images.homogeneous = true;
			images.min_children_per_line = 1;
			images.selection_mode = SelectionMode.SINGLE;

			images.child_activated.connect(i => {
				var item = (ImageItem) i;
				if(item != null)
				{
					if(item.size.width >= item.size.height)
					{
						game.image = item.image.url;
					}
					else
					{
						game.image_vertical = item.image.url;
					}
					game.save();
				}
				popdown();
			});

			var images_vbox = new Box(Orientation.VERTICAL, 8);
			images_vbox.add(images_header);
			images_vbox.add(images);
			images_scroll.add(images_vbox);

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

			add_search_link("SteamGridDB", "https://steamgriddb.com/search/grids?term=%s");
			add_search_link("Jinx's SGVI", "https://steam.cryotank.net/?s=%s");
			add_search_link("Google", "https://google.com/search?tbm=isch&tbs=isz:ex,iszw:460,iszh:215&q=%s");

			content_hbox = new Box(Orientation.HORIZONTAL, 0);
			content_hbox.add(results_scroll);
			content_hbox.add(new Separator(Orientation.VERTICAL));
			content_hbox.add(stack);

			root_stack.add(root_spinner);
			root_stack.add(content_hbox);
			root_spinner.show();
			root_stack.visible_child = root_spinner;

			vbox.add(root_stack);
			vbox.add(new Separator(Orientation.HORIZONTAL));
			vbox.add(search_links);

			child = vbox;

			vbox.show_all();
			root_stack.show();
		}

		private void load_results()
		{
			if(results_load_started) return;
			results_load_started = true;
			results_list.foreach(r => r.destroy());
			root_stack.visible_child = root_spinner;
			Utils.thread("ImagesDownloadPopover.load_results", () => {
				load_results_async.begin();
			});
		}

		private async void load_results_async()
		{
			var all_results = new ArrayList<ImagesProvider.Result>();

			foreach(var src in ImageProviders)
			{
				if(!src.enabled) continue;
				var results = yield src.images(game);
				if(results == null || results.size < 1) continue;
				foreach(var result in results)
				{
					if(result != null)
					{
						all_results.add(result);
					}
				}
			}

			Idle.add(() => {
				foreach(var result in all_results)
				{
					var row = new ResultRow(result, game);
					results_list.add(row);
					if(results_list.get_selected_row() == null)
					{
						results_list.select_row(row);
					}
				}
				content_hbox.show_all();
				root_stack.visible_child = content_hbox;
				return Source.REMOVE;
			}, Priority.LOW);
		}

		private void load_images(ImagesProvider.Result result)
		{
			if(images_load_started) return;
			images_load_started = true;
			images.foreach(i => i.destroy());
			stack.visible_child = spinner;
			Utils.thread("ImagesDownloadPopover.load_images", () => {
				load_images_async.begin(result);
			});
		}

		private async void load_images_async(ImagesProvider.Result result)
		{
			var imgs = yield result.load_images();

			Idle.add(() => {
				if(imgs != null)
				{
					foreach(var img in imgs)
					{
						var item = new ImageItem(img, result.image_size, result.provider, game);
						images.add(item);
						if(img.url == game.image)
						{
							images.select_child(item);
							item.grab_focus();
						}
					}
				}

				images_header_icon.icon_name = result.provider.icon;
				images_header_title.label = result.title;
				images_header_subtitle.label = result.subtitle;
				images_header_url.tooltip_text = result.url;
				images_header.no_show_all = false;
				images_header.show_all();

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
				images_load_started = false;
				return Source.REMOVE;
			}, Priority.LOW);
		}

		private void add_search_link(string text, string url)
		{
			var link = new LinkButton.with_label(url.printf(Uri.escape_string(game.name)), text);
			link.halign = Align.START;
			link.margin = 0;
			search_links.add(link);
		}

		private class ResultRow: ListBoxRow
		{
			public ImagesProvider.Result result { get; construct; }
			public Game game { get; construct; }

			public ResultRow(ImagesProvider.Result result, Game game)
			{
				Object(result: result, game: game);
			}

			construct
			{
				var title = new Label(result.name ?? result.title ?? result.provider.name);
				title.hexpand = true;
				title.ellipsize = Pango.EllipsizeMode.END;
				title.xalign = 0;
				title.margin_start = title.margin_end = 8;
				title.margin_top = title.margin_bottom = 4;
				child = title;
				tooltip_text = title.label;
			}
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

				card.tooltip_markup = image.description;

				var img = new AutoSizeImage();
				img.load(image.url, null, @"games/$(game.source.id)/$(game.id)/images/providers/$(provider.id)/");

				card.add(img);

				child = card;

				var ratio = (float) size.height / size.width;

				var w_1x = size.width > 500 ? size.width / 2 : size.width;

				var min = int.max((int) (w_1x / 2), 100);
				var max = int.min(w_1x, 460);
				img.set_constraint(min, max, ratio);

				show_all();
			}
		}
	}
}
