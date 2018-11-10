/*
This file is part of GameHub.
Copyright (C) 2018 Anatoliy Kashkin

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

		private Entry name_entry;
		private AutoSizeImage image_view;
		private AutoSizeImage icon_view;
		private FileChooserEntry image_entry;
		private FileChooserEntry icon_entry;

		private Box properties_box;
		private Box image_search_links;

		public GamePropertiesDialog(Game? game)
		{
			Object(transient_for: Windows.MainWindow.instance, resizable: false, title: _("%s: Properties").printf(game.name), game: game);
		}

		construct
		{
			get_style_context().add_class("rounded");
			get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);

			gravity = Gdk.Gravity.NORTH;

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
			#if GTK_3_22
			tags_scrolled.propagate_natural_width = true;
			tags_scrolled.propagate_natural_height = true;
			tags_scrolled.max_content_height = 320;
			#endif
			tags_scrolled.add(tags_list);

			tags_box.add(tags_scrolled);

			new_entry = new Entry();
			new_entry.placeholder_text = _("Add tag");
			new_entry.primary_icon_name = "gh-tag-add-symbolic";
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

			properties_box = new Box(Orientation.VERTICAL, 0);

			var name_header = new HeaderLabel(_("Name"));
			name_header.xpad = 8;
			properties_box.add(name_header);

			name_entry = new Entry();
			name_entry.placeholder_text = name_entry.primary_icon_tooltip_text = _("Name");
			name_entry.primary_icon_name = "insert-text-symbolic";
			name_entry.primary_icon_activatable = false;
			name_entry.margin = 4;
			name_entry.margin_top = 0;
			properties_box.add(name_entry);

			name_entry.text = game.name;
			name_entry.changed.connect(() => {
				game.name = name_entry.text.strip();
				game.update_status();
				game.save();
			});

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

			image_entry = add_image_entry(_("Image URL"), "image-x-generic");

			properties_box.add(image_entry);

			icon_entry = add_image_entry(_("Icon URL"), "image-x-generic-symbolic");
			icon_entry.margin_top = 0;

			properties_box.add(icon_entry);

			image_search_links = new Box(Orientation.HORIZONTAL, 8);
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

			var space = new Box(Orientation.VERTICAL, 0);
			space.vexpand = true;
			properties_box.add(space);

			if(!(game is Data.Sources.Steam.SteamGame) && game.install_dir != null && game.install_dir.query_exists())
			{
				var executable_header = new HeaderLabel(_("Executable"));
				executable_header.xpad = 8;
				properties_box.add(executable_header);

				var executable_picker = new FileChooserEntry(_("Select executable"), FileChooserAction.OPEN, "application-x-executable", _("Executable"), false, true);
				try
				{
					executable_picker.select_file(game.executable);
				}
				catch(Error e)
				{
					warning(e.message);
				}
				executable_picker.margin_start = executable_picker.margin_end = 4;
				properties_box.add(executable_picker);

				executable_picker.file_set.connect(() => {
					game.set_chosen_executable(executable_picker.file);
				});

				var args_entry = new Entry();
				args_entry.text = game.arguments ?? "";
				args_entry.placeholder_text = args_entry.primary_icon_tooltip_text = _("Arguments");
				args_entry.primary_icon_name = "utilities-terminal-symbolic";
				args_entry.primary_icon_activatable = false;
				args_entry.margin = 4;

				args_entry.changed.connect(() => {
					game.arguments = args_entry.text.strip();
					game.update_status();
					game.save();
				});

				properties_box.add(args_entry);

				var compat_header = new HeaderLabel(_("Compatibility"));
				compat_header.no_show_all = true;
				compat_header.xpad = 8;
				properties_box.add(compat_header);

				var compat_force_switch = add_switch(_("Force compatibility mode"), game.force_compat, f => { game.force_compat = f; });
				compat_force_switch.no_show_all = true;

				var compat_tool = new CompatToolPicker(game, false);
				compat_tool.no_show_all = true;
				compat_tool.margin_start = compat_tool.margin_end = 4;
				properties_box.add(compat_tool);

				game.notify["use-compat"].connect(() => {
					compat_force_switch.visible = !game.needs_compat;
					compat_tool.visible = game.use_compat;
					compat_header.visible = compat_force_switch.visible || compat_tool.visible;
					game.update_status();
				});
				game.notify_property("use-compat");
			}

			content.add(tags_box);
			content.add(new Separator(Orientation.VERTICAL));
			content.add(properties_box);

			get_content_area().add(content);
			get_content_area().set_size_request(640, -1);

			delete_event.connect(() => {
				image_entry.activate();
				icon_entry.activate();
				set_image_url(true);
				set_icon_url(true);
				game.save();
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
				if(tag in Tables.Tags.DYNAMIC_TAGS || !tag.enabled) continue;
				var row = new TagRow(tag, game);
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
			var url = image_entry.uri;
			if(url == null || url.length == 0) url = game.image;
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
			var url = icon_entry.uri;
			if(url == null || url.length == 0) url = game.icon;
			if(replace)
			{
				game.icon = url;
			}
			else
			{
				Utils.load_image.begin(icon_view, url, "icon");
			}
		}

		private FileChooserEntry add_image_entry(string text, string icon)
		{
			var entry = new FileChooserEntry(text, FileChooserAction.OPEN, icon, text, true);
			entry.margin = 4;

			var filter = new FileFilter();
			filter.add_mime_type("image/*");
			entry.chooser.set_filter(filter);

			entry.uri_set.connect(() => { set_image_url(false); set_icon_url(false); });

			return entry;
		}

		private void add_image_search_link(string text, string url)
		{
			var link = new LinkButton.with_label(url, text);
			link.halign = Align.START;
			link.margin = 0;
			image_search_links.add(link);
		}

		private Box add_switch(string text, bool enabled, owned SwitchAction action)
		{
			var sw = new Switch();
			sw.active = enabled;
			sw.halign = Align.END;
			sw.notify["active"].connect(() => { action(sw.active); });

			var label = new Label(text);
			label.halign = Align.START;
			label.hexpand = true;

			var hbox = new Box(Orientation.HORIZONTAL, 12);
			hbox.margin = 4;
			hbox.margin_start = 8;

			hbox.add(label);
			hbox.add(sw);

			hbox.show_all();

			properties_box.add(hbox);
			return hbox;
		}

		protected delegate void SwitchAction(bool active);
	}
}
