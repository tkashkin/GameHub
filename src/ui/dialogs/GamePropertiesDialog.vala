using Gtk;
using Gdk;
using Gee;
using Granite;

using GameHub.Data;
using GameHub.Data.DB;
using GameHub.Utils;
using GameHub.UI.Widgets;

namespace GameHub.UI.Dialogs
{
	public class GamePropertiesDialog: Dialog
	{
		public Game? game { get; construct; }

		private Box content;
		private ListBox tags_list;
		private ScrolledWindow tags_scrolled;
		private Entry new_entry;

		private AutoSizeImage image_view;
		private AutoSizeImage icon_view;
		private Entry image_entry;
		private Entry icon_entry;

		private Box image_search_links;

		public GamePropertiesDialog(Game? game)
		{
			Object(transient_for: Windows.MainWindow.instance, resizable: false, title: _("%s: Properties").printf(game.name), game: game);
		}

		construct
		{
			get_style_context().add_class("rounded");
			get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);

			gravity = Gdk.Gravity.CENTER;

			content = new Box(Orientation.HORIZONTAL, 8);
			content.margin_start = content.margin_end = 6;

			var tags_box = new Box(Orientation.VERTICAL, 0);

			var tags_header = new HeaderLabel(_("Tags"));
			tags_header.xpad = 8;
			tags_box.add(tags_header);

			tags_list = new ListBox();
			tags_list.get_style_context().add_class("tags-list");
			tags_list.selection_mode = SelectionMode.NONE;

			tags_list.set_sort_func((row1, row2) => {
				var item1 = row1 as TagRow;
				var item2 = row2 as TagRow;

				if(row1 != null && row2 != null)
				{
					var t1 = item1.tag.id;
					var t2 = item2.tag.id;

					var b1 = t1.has_prefix(Tables.Tags.Tag.BUILTIN_PREFIX);
					var b2 = t2.has_prefix(Tables.Tags.Tag.BUILTIN_PREFIX);
					if(b1 && !b2) return -1;
					if(!b1 && b2) return 1;

					var u1 = t1.has_prefix(Tables.Tags.Tag.USER_PREFIX);
					var u2 = t2.has_prefix(Tables.Tags.Tag.USER_PREFIX);
					if(u1 && !u2) return -1;
					if(!u1 && u2) return 1;

					return item1.tag.name.collate(item1.tag.name);
				}

				return 0;
			});

			tags_scrolled = new ScrolledWindow(null, null);
			tags_scrolled.vexpand = true;
			tags_scrolled.margin_bottom = 8;
			#if GTK_3_22
			tags_scrolled.propagate_natural_width = true;
			tags_scrolled.propagate_natural_height = true;
			tags_scrolled.max_content_height = 380;
			#endif
			tags_scrolled.add(tags_list);

			tags_box.add(tags_scrolled);

			new_entry = new Entry();
			new_entry.placeholder_text = _("Add tag");
			new_entry.primary_icon_name = "tag-add-symbolic";
			new_entry.primary_icon_activatable = false;
			new_entry.secondary_icon_name = "list-add-symbolic";
			new_entry.secondary_icon_activatable = true;
			new_entry.margin = 4;

			new_entry.icon_press.connect((icon, event) => {
				if(icon == EntryIconPosition.SECONDARY && ((EventButton) event).button == 1)
				{
					add_tag();
				}
			});
			new_entry.activate.connect(add_tag);

			tags_box.add(new_entry);

			var properties_box = new Box(Orientation.VERTICAL, 0);

			if(!(game is Data.Sources.Steam.SteamGame))
			{
				var executable_header = new HeaderLabel(_("Executable"));
				executable_header.xpad = 8;
				properties_box.add(executable_header);

				var executable_button = new Button.with_label(_("Select game executable"));
				executable_button.tooltip_text = game.executable.get_path();
				executable_button.margin_start = executable_button.margin_end = executable_button.margin_bottom = 4;
				executable_button.hexpand = false;
				executable_button.clicked.connect(() => {
					game.choose_executable();
					executable_button.tooltip_text = game.executable.get_path();
				});

				properties_box.add(executable_button);

				properties_box.add(new Separator(Orientation.HORIZONTAL));
			}

			var images_header = new HeaderLabel(_("Images"));
			images_header.xpad = 8;
			properties_box.add(images_header);

			var images_card = new Frame(null);
			images_card.get_style_context().add_class(Granite.STYLE_CLASS_CARD);
			images_card.get_style_context().add_class("gamecard");
			images_card.get_style_context().add_class("static");
			images_card.shadow_type = ShadowType.NONE;
			images_card.margin = 4;

			icon_view = new AutoSizeImage();
			icon_view.margin = 4;
			icon_view.set_constraint(48, 48, 1);
			icon_view.halign = Align.START;
			icon_view.valign = Align.END;

			image_view = new AutoSizeImage();
			image_view.hexpand = false;
			image_view.set_constraint(360, 400, 0.467f);

			var actions = new Box(Orientation.VERTICAL, 0);
			actions.get_style_context().add_class("actions");
			actions.hexpand = true;
			actions.vexpand = false;

			var images_overlay = new Overlay();
			images_overlay.add(image_view);
			images_overlay.add_overlay(actions);
			images_overlay.add_overlay(icon_view);

			images_card.add(images_overlay);
			properties_box.add(images_card);

			image_entry = new Entry();
			image_entry.placeholder_text = image_entry.primary_icon_tooltip_text = _("Image URL");
			image_entry.primary_icon_name = "image-x-generic";
			image_entry.primary_icon_activatable = false;
			image_entry.secondary_icon_name = "edit-clear-symbolic";
			image_entry.secondary_icon_activatable = true;
			image_entry.secondary_icon_tooltip_text = _("Reset to default");
			image_entry.margin = 4;

			image_entry.icon_press.connect((icon, event) => {
				if(icon == EntryIconPosition.SECONDARY && ((EventButton) event).button == 1)
				{
					game.image = null;
					game.update_game_info.begin();
					Utils.load_image.begin(image_view, game.image, "image");
				}
			});

			image_entry.activate.connect(() => { set_image_url(false); });
			image_entry.focus_out_event.connect(() => { set_image_url(); return false; });

			properties_box.add(image_entry);

			icon_entry = new Entry();
			icon_entry.placeholder_text = icon_entry.primary_icon_tooltip_text = _("Icon URL");
			icon_entry.primary_icon_name = "image-x-generic-symbolic";
			icon_entry.primary_icon_activatable = false;
			icon_entry.secondary_icon_name = "edit-clear-symbolic";
			icon_entry.secondary_icon_activatable = true;
			icon_entry.secondary_icon_tooltip_text = _("Reset to default");
			icon_entry.margin = 4;

			icon_entry.icon_press.connect((icon, event) => {
				if(icon == EntryIconPosition.SECONDARY && ((EventButton) event).button == 1)
				{
					game.icon = null;
					game.update_game_info.begin();
					Utils.load_image.begin(icon_view, game.icon, "icon");
				}
			});

			icon_entry.activate.connect(() => { set_icon_url(false); });
			icon_entry.focus_out_event.connect(() => { set_icon_url(); return false; });

			properties_box.add(icon_entry);

			image_search_links = new Box(Orientation.HORIZONTAL, 0);
			image_search_links.margin = 8;

			var image_search_links_label = new Label(_("Search images:"));
			image_search_links_label.halign = Align.START;
			image_search_links_label.xalign = 0;
			image_search_links_label.hexpand = true;
			image_search_links.add(image_search_links_label);

			add_image_search_link("SteamGridDB", @"http://www.steamgriddb.com/game/$(game.name)");
			add_image_search_link("Jinx's SGVI", @"http://steam.cryotank.net/?s=$(game.name)");
			add_image_search_link("Google", @"https://www.google.com/search?tbm=isch&tbs=isz:ex,iszw:460,iszh:215&q=$(game.name)");

			properties_box.add(image_search_links);

			Utils.load_image.begin(image_view, game.image, "image");
			Utils.load_image.begin(icon_view, game.icon, "icon");

			if(!game.is_supported(null, false) && game.is_supported(null, true))
			{
				properties_box.add(new Separator(Orientation.HORIZONTAL));

				var compat_header = new HeaderLabel(_("Compatibility"));
				compat_header.xpad = 8;
				properties_box.add(compat_header);

				var compat_tool = new CompatToolPicker(game, false);
				compat_tool.margin_start = compat_tool.margin_end = 4;
				properties_box.add(compat_tool);
			}

			content.add(tags_box);
			content.add(new Separator(Orientation.VERTICAL));
			content.add(properties_box);

			get_content_area().add(content);
			get_content_area().set_size_request(640, -1);

			delete_event.connect(() => {
				set_image_url(true);
				set_icon_url(true);
				Tables.Games.add(game);
				destroy();
			});

			Tables.Tags.instance.tags_updated.connect(update);

			update();

			show_all();
		}

		private void update()
		{
			tags_list.foreach(w => w.destroy());

			foreach(var tag in Tables.Tags.TAGS)
			{
				var row = new TagRow(game, tag);
				tags_list.add(row);
			}

			tags_list.show_all();
		}

		private void add_tag()
		{
			var name = new_entry.text.strip();
			if(name.length == 0) return;

			new_entry.text = "";

			var tag = new Tables.Tags.Tag.from_name(name);
			Tables.Tags.add(tag);
			game.add_tag(tag);
			update();
		}

		private void set_image_url(bool replace=false)
		{
			var url = image_entry.text.strip();
			if(url.length == 0) url = game.image;
			if(replace)
			{
				game.image = url;
			}
			else
			{
				Utils.load_image.begin(image_view, url, "image");
			}
		}

		private void set_icon_url(bool replace=false)
		{
			var url = icon_entry.text.strip();
			if(url.length == 0) url = game.icon;
			if(replace)
			{
				game.icon = url;
			}
			else
			{
				Utils.load_image.begin(icon_view, url, "icon");
			}
		}

		private void add_image_search_link(string text, string url)
		{
			var link = new LinkButton.with_label(url, text);
			link.halign = Align.START;
			link.margin = 0;
			image_search_links.add(link);
		}

		public class TagRow: ListBoxRow
		{
			public Game game;
			public Tables.Tags.Tag tag;

			public TagRow(Game game, Tables.Tags.Tag tag)
			{
				this.game = game;
				this.tag = tag;

				var ebox = new EventBox();
				ebox.above_child = true;

				var box = new Box(Orientation.HORIZONTAL, 8);
				box.margin_start = box.margin_end = 8;
				box.margin_top = box.margin_bottom = 6;

				var check = new CheckButton();
				check.active = game.has_tag(tag);

				var name = new Label(tag.name);
				name.halign = Align.START;
				name.xalign = 0;
				name.hexpand = true;

				var icon = new Image.from_icon_name(tag.icon, IconSize.BUTTON);

				box.add(check);
				box.add(name);
				box.add(icon);

				ebox.add_events(EventMask.ALL_EVENTS_MASK);
				ebox.button_release_event.connect(e => {
					if(e.button == 1)
					{
						game.toggle_tag(tag);
						check.active = game.has_tag(tag);
					}
					return true;
				});

				ebox.add(box);

				child = ebox;
			}
		}
	}
}
