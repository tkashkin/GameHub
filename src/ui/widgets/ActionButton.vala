using Gtk;

namespace GameHub.UI.Widgets
{
	class ActionButton: Gtk.Button
	{
		Label button_text;
		Image? _icon;
		Grid button_grid;

		public string text
		{
			get { return button_text.label; }
			set { button_text.label = value; }
		}

		public bool show_text
		{
			get { return button_text.visible; }
			set
			{
				button_text.visible = value;

				tooltip_text = value ? null : text;
				button_grid.remove(button_text);
				if(value) button_grid.attach(button_text, 1, 0, 1, 1);
			}
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

		public ActionButton(Gtk.Image? image, string text, bool show_text=true)
		{
			Object(text: text, icon: image, show_text: show_text);
		}

		construct
		{
			button_text = new Label(null);
			button_text.get_style_context().add_class(Granite.STYLE_CLASS_H3_LABEL);
			button_text.halign = Align.START;
			button_text.valign = Align.CENTER;

			get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);

			button_grid = new Grid();
			button_grid.column_spacing = 8;

			button_grid.attach(button_text, 1, 0, 1, 1);
			this.add(button_grid);
		}
	}
}