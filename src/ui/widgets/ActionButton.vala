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

namespace GameHub.UI.Widgets
{
	class ActionButton: Gtk.Button
	{
		public string icon { get; construct set; }
		public string? icon_overlay { get; construct set; }
		public string text { get; construct set; }
		public bool show_text { get; construct; default = true; }
		public bool compact { get; construct set; default = false; }

		public ActionButton(string icon, string? icon_overlay, string text, bool show_text=true, bool compact=false)
		{
			Object(icon: icon, icon_overlay: icon_overlay, text: text, show_text: show_text, compact: compact);
		}

		construct
		{
			get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);

			var box = new Box(Orientation.HORIZONTAL, 8);

			var overlay = new Overlay();
			overlay.valign = Align.CENTER;
			overlay.set_size_request(48, 48);

			var image = new Image.from_icon_name(icon, IconSize.DIALOG);
			image.valign = Align.CENTER;
			overlay.add(image);

			notify["icon"].connect(() => {
				image.icon_name = compact ? icon_overlay ?? icon : icon;
			});

			Image? overlay_image = null;

			if(icon_overlay != null)
			{
				overlay_image = new Image.from_icon_name(icon_overlay, IconSize.LARGE_TOOLBAR);
				overlay_image.set_size_request(24, 24);
				overlay_image.halign = Align.END;
				overlay_image.valign = Align.END;
				overlay.add_overlay(overlay_image);
				overlay.set_overlay_pass_through(overlay_image, true);
				notify["icon-overlay"].connect(() => {
					overlay_image.icon_name = icon_overlay;
					image.icon_name = compact ? icon_overlay ?? icon : icon;
				});
			}

			box.add(overlay);

			if(show_text)
			{
				var label = Styled.H3Label(text.replace("&amp;", "&").replace("&", "&amp;"));
				label.halign = Align.START;
				label.valign = Align.CENTER;
				label.xalign = 0;
				label.ellipsize = Pango.EllipsizeMode.END;
				label.use_markup = true;
				box.add(label);
				notify["text"].connect(() => {
					label.label = text.replace("&amp;", "&").replace("&", "&amp;");
				});
			}

			tooltip_markup = text.replace("&amp;", "&").replace("&", "&amp;");
			notify["text"].connect(() => {
				tooltip_markup = text.replace("&amp;", "&").replace("&", "&amp;");
			});

			notify["compact"].connect(() => {
				if(overlay_image != null)
				{
					overlay_image.no_show_all = compact;
					overlay_image.visible = !compact;
					image.icon_name = compact ? icon_overlay : icon;
				}
				image.icon_size = compact ? IconSize.LARGE_TOOLBAR : IconSize.DIALOG;
				overlay.set_size_request(compact && !show_text ? -1 : 48, compact ? 32 : 48);
			});
			notify_property("compact");

			child = box;
		}
	}
}
