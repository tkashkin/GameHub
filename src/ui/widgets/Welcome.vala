/*
This file is part of GameHub.
Copyright(C) Anatoliy Kashkin

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

/* Based on Granite.Widgets.Welcome */

using Gtk;

namespace GameHub.UI.Widgets
{
	public class Welcome: EventBox
	{
		public signal void activated(int index);
		protected new GLib.List<Button> children = new GLib.List<Button>();
		protected Grid options;

		public string title
		{
			get
			{
				return title_label.label;
			}
			set
			{
				title_label.label = value;
			}
		}

		public string subtitle
		{
			get
			{
				return subtitle_label.label;
			}
			set
			{
				subtitle_label.label = value;
			}
		}

		private Label title_label;
		private Label subtitle_label;

		public Welcome(string title_text, string subtitle_text)
		{
			Object(title: title_text, subtitle: subtitle_text);
		}

		construct
		{
			StyleClass.add(this, "welcome");

			title_label = Styled.H1Label(null);
			title_label.justify = Justification.CENTER;
			title_label.hexpand = true;

			subtitle_label = Styled.H2Label(null);
			StyleClass.add(subtitle_label, Gtk.STYLE_CLASS_DIM_LABEL);
			subtitle_label.justify = Justification.CENTER;
			subtitle_label.hexpand = true;
			subtitle_label.wrap = true;
			subtitle_label.wrap_mode = Pango.WrapMode.WORD;

			options = new Grid();
			options.orientation = Orientation.VERTICAL;
			options.row_spacing = 12;
			options.halign = Align.CENTER;
			options.margin_top = 24;

			var content = new Grid();
			content.expand = true;
			content.margin = 12;
			content.orientation = Orientation.VERTICAL;
			content.valign = Align.CENTER;
			content.add(title_label);
			content.add(subtitle_label);
			content.add(options);

			add(content);
		}

		public void set_item_visible(uint index, bool val)
		{
			if(index < children.length() && children.nth_data(index) is Widget)
			{
				children.nth_data(index).set_no_show_all(!val);
				children.nth_data(index).set_visible(val);
			}
		}

		public void remove_item(uint index)
		{
			if(index < children.length() && children.nth_data(index) is Widget)
			{
				var item = children.nth_data(index);
				item.destroy();
				children.remove(item);
			}
		}

		public void set_item_sensitivity(uint index, bool val)
		{
			if(index < children.length() && children.nth_data(index) is Widget)
				children.nth_data(index).set_sensitive(val);
		}

		public int append(string icon_name, string option_text, string description_text)
		{
			var image = new Image.from_icon_name(icon_name, IconSize.DIALOG);
			image.use_fallback = true;
			return append_with_image(image, option_text, description_text);
		}

		public int append_with_pixbuf(Gdk.Pixbuf? pixbuf, string option_text, string description_text)
		{
			var image = new Image.from_pixbuf(pixbuf);
			return append_with_image(image, option_text, description_text);
		}

		public int append_with_image(Image? image, string option_text, string description_text)
		{
			var button = new WelcomeButton(image, option_text, description_text);
			children.append(button);
			options.add(button);

			button.clicked.connect(() => {
				int index = this.children.index(button);
				activated(index);
			});

			return this.children.index(button);
		}

		public WelcomeButton? get_button_from_index(int index)
		{
			if(index >= 0 && index < children.length())
				return children.nth_data(index) as WelcomeButton;

			return null;
		}

		public class WelcomeButton: Button
		{
			Label button_title;
			Label button_description;
			Image? _icon;
			Grid button_grid;

			public string title
			{
				get { return button_title.get_text(); }
				set { button_title.set_text(value); }
			}

			public string description
			{
				get { return button_description.get_text(); }
				set { button_description.set_text(value); }
			}

			public Image? icon
			{
				get { return _icon; }
				set
				{
					if(_icon != null)
					{
						_icon.destroy();
					}
					_icon = value;
					if(_icon != null)
					{
						_icon.set_pixel_size(48);
						_icon.halign = Align.CENTER;
						_icon.valign = Align.CENTER;
						button_grid.attach(_icon, 0, 0, 1, 2);
					}
				}
			}

			public WelcomeButton(Image? image, string option_text, string description_text)
			{
				Object(title: option_text, description: description_text, icon: image);
			}

			construct
			{
				button_title = Styled.H3Label(null);
				button_title.halign = Align.START;
				button_title.valign = Align.END;

				button_description = new Label(null);
				StyleClass.add(button_description, Gtk.STYLE_CLASS_DIM_LABEL);
				button_description.halign = Align.START;
				button_description.valign = Align.START;
				button_description.set_line_wrap(true);
				button_description.set_line_wrap_mode(Pango.WrapMode.WORD);

				StyleClass.add(this, Gtk.STYLE_CLASS_FLAT);

				button_grid = new Grid();
				button_grid.column_spacing = 12;

				button_grid.attach(button_title, 1, 0, 1, 1);
				button_grid.attach(button_description, 1, 1, 1, 1);
				this.add(button_grid);
			}
		}
	}
}
