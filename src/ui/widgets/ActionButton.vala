using Gtk;

namespace GameHub.UI.Widgets
{
	class ActionButton: Gtk.Button
	{
		Label button_title;
		Image? _icon;
		Grid button_grid;

		public string title
		{
			get { return button_title.get_text(); }
			set { button_title.set_text(value); }
		}

		public Gtk.Image? icon
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
					button_grid.attach(_icon, 0, 0, 1, 1);
				}
			}
		}

		public ActionButton(Gtk.Image? image, string text)
		{
			Object(title: text, icon: image);
		}

		construct
		{
			button_title = new Label(null);
			button_title.get_style_context().add_class(Granite.STYLE_CLASS_H3_LABEL);
			button_title.halign = Align.START;
			button_title.valign = Align.CENTER;

			get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);

			button_grid = new Grid();
			button_grid.column_spacing = 8;

			button_grid.attach(button_title, 1, 0, 1, 1);
			this.add(button_grid);
		}
	}
}