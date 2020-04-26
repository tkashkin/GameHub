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
using GameHub.Data.Runnables;

using GameHub.UI.Widgets;
using GameHub.Utils;

namespace GameHub.UI.Dialogs.GamePropertiesDialog.Tabs
{
	private class General: GamePropertiesDialogTab
	{
		public General(Game game)
		{
			Object(
				game: game,
				title: _("General"),
				orientation: Orientation.HORIZONTAL
			);
		}

		private AutoSizeImage image_view;
		private AutoSizeImage image_vertical_view;
		private FileChooserEntry image_entry;
		private FileChooserEntry image_vertical_entry;
		private FileChooserEntry icon_entry;

		construct
		{
			var properties_box = new Box(Orientation.VERTICAL, 0);
			properties_box.get_style_context().add_class("content");
			properties_box.expand = true;

			var name_header = Styled.H4Label(_("Name"));
			properties_box.add(name_header);

			var name_entry = new Entry();
			name_entry.placeholder_text = name_entry.primary_icon_tooltip_text = _("Name");
			name_entry.primary_icon_name = "insert-text-symbolic";
			name_entry.primary_icon_activatable = false;
			properties_box.add(name_entry);

			name_entry.text = game.name;
			name_entry.changed.connect(() => {
				game.name = name_entry.text.strip();
				game.update_status();
				game.save();
				DB.Tables.IGDBData.remove(game);
			});

			var images_header = Styled.H4Label(_("Images"));
			images_header.margin_top = 18;
			properties_box.add(images_header);

			var images_hbox = new Box(Orientation.HORIZONTAL, 8);
			images_hbox.margin_bottom = 6;
			images_hbox.hexpand = true;
			images_hbox.vexpand = false;

			var image_card = Styled.Card("gamecard", "static");
			image_card.expand = false;
			image_card.halign = Align.START;
			image_card.valign = Align.CENTER;

			image_view = new AutoSizeImage();
			image_view.expand = false;

			var actions = new Box(Orientation.VERTICAL, 0);
			actions.get_style_context().add_class("actions");
			actions.hexpand = true;
			actions.vexpand = false;

			var image_overlay = new Overlay();
			image_overlay.add(image_view);
			image_overlay.add_overlay(actions);

			image_card.add(image_overlay);

			var image_vertical_card = Styled.Card("gamecard", "static");
			image_vertical_card.expand = false;
			image_vertical_card.halign = Align.START;
			image_vertical_card.valign = Align.CENTER;

			image_vertical_view = new AutoSizeImage();
			image_vertical_view.expand = false;

			var images_download_btn = new MenuButton();
			images_download_btn.get_style_context().add_class("images-download-button");
			images_download_btn.margin = 8;
			images_download_btn.halign = Align.END;
			images_download_btn.valign = Align.START;
			images_download_btn.image = new Image.from_icon_name("folder-download-symbolic", IconSize.BUTTON);
			images_download_btn.tooltip_text = _("Download images");

			var actions_vertical = new Box(Orientation.VERTICAL, 0);
			actions_vertical.get_style_context().add_class("actions");
			actions_vertical.expand = true;

			var image_vertical_overlay = new Overlay();
			image_vertical_overlay.add(image_vertical_view);
			image_vertical_overlay.add_overlay(actions_vertical);
			image_vertical_overlay.add_overlay(images_download_btn);

			image_vertical_card.add(image_vertical_overlay);

			images_hbox.add(image_card);
			images_hbox.add(image_vertical_card);

			properties_box.add(images_hbox);

			image_entry = add_image_entry(_("Select image"), _("Image URL"), "image-x-generic");
			image_vertical_entry = add_image_entry(_("Select vertical image"), _("Vertical image URL"), "image-x-generic");
			icon_entry = add_image_entry(_("Select icon"), _("Icon URL"), "image-x-generic-symbolic");

			var images_download_popover = new ImagesDownloadPopover(game, images_download_btn, 700, 580);

			properties_box.add(image_entry);
			properties_box.add(image_vertical_entry);
			properties_box.add(icon_entry);

			var space = new Box(Orientation.VERTICAL, 0);
			space.expand = true;
			properties_box.add(space);

			var run_cmd_btn = new Button();
			run_cmd_btn.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
			run_cmd_btn.get_style_context().add_class("run-cmd-button");
			run_cmd_btn.hexpand = true;
			run_cmd_btn.tooltip_text = _("Copy launch command to the clipboard");

			var run_cmd_btn_box = new Box(Orientation.HORIZONTAL, 8);

			var run_cmd_btn_icon = new Image.from_icon_name("utilities-terminal-symbolic", IconSize.BUTTON);
			run_cmd_btn_icon.valign = Align.CENTER;

			var run_cmd_btn_label = new Label(@"gamehub --run $(game.full_id)");
			run_cmd_btn_label.wrap = true;
			run_cmd_btn_label.xalign = 0;
			run_cmd_btn_label.valign = Align.CENTER;

			run_cmd_btn_box.add(run_cmd_btn_icon);
			run_cmd_btn_box.add(run_cmd_btn_label);

			run_cmd_btn.add(run_cmd_btn_box);

			properties_box.add(run_cmd_btn);

			var tags = new GameTagsList(game);
			tags.get_style_context().add_class(Gtk.STYLE_CLASS_VIEW);
			tags.get_style_context().add_class("content-padding-top");
			tags.hexpand = false;
			tags.set_size_request(200, -1);

			add(tags);
			add(new Separator(Orientation.VERTICAL));
			add(properties_box);

			image_view.set_constraint(385, 385, ((float) 215 / 460), Orientation.HORIZONTAL);
			image_vertical_view.set_constraint(image_view.height_request, image_view.height_request, ((float) 900 / 600), Orientation.VERTICAL);

			game.notify["image"].connect(load_images);
			game.notify["image-vertical"].connect(load_images);
			load_images();
		}

		private void load_images()
		{
			//image_entry.reset();
			//image_vertical_entry.reset();
			image_view.load(game.image, null, @"games/$(game.source.id)/$(game.id)/images/");
			image_vertical_view.load(null, game.image_vertical, @"games/$(game.source.id)/$(game.id)/images/");
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
				image_view.load(url, null, @"games/$(game.source.id)/$(game.id)/images/");
			}
		}

		private void set_image_vertical_url(bool replace=false)
		{
			var url = image_vertical_entry.uri;
			if(url == null || url.length == 0) url = game.image_vertical;
			if(replace)
			{
				game.image_vertical = url;
			}
			else
			{
				image_vertical_view.load(null, url, @"games/$(game.source.id)/$(game.id)/images/");
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
				//icon_view.load(url, null, @"games/$(game.source.id)/$(game.id)/icons/");
			}
		}

		private FileChooserEntry add_image_entry(string title, string text, string icon)
		{
			var entry = new FileChooserEntry(title, FileChooserAction.OPEN, icon, text, true);
			entry.hexpand = true;
			entry.margin_top = 6;
			var filter = new FileFilter();
			filter.add_mime_type("image/*");
			entry.chooser.set_filter(filter);
			entry.uri_set.connect(() => { set_image_url(false); set_image_vertical_url(false); set_icon_url(false); });
			return entry;
		}
	}
}
