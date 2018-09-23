using Gtk;

namespace GameHub.UI.Widgets
{
	class ActionButton: Gtk.Button
	{
		public string icon { get; construct set; }
		public string? icon_overlay { get; construct set; }
		public string text { get; construct set; }
		public bool show_text { get; construct; default = true; }

		public ActionButton(string icon, string? icon_overlay, string text, bool show_text=true)
		{
			Object(icon: icon, icon_overlay: icon_overlay, text: text, show_text: show_text);
		}

		construct
		{
			get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);

			var box = new Box(Orientation.HORIZONTAL, 8);

			var overlay = new Overlay();
			overlay.valign = Align.START;
			overlay.set_size_request(48, 48);

			var image = new Image.from_icon_name(icon, IconSize.DIALOG);
			image.set_size_request(48, 48);
			overlay.add(image);
			
			notify["icon"].connect(() => {
				image.icon_name = icon;
			});

			if(icon_overlay != null)
			{
				var overlay_image = new Image.from_icon_name(icon_overlay, IconSize.LARGE_TOOLBAR);
				overlay_image.set_size_request(24, 24);
				overlay_image.halign = Align.END;
				overlay_image.valign = Align.END;
				overlay.add_overlay(overlay_image);
				overlay.set_overlay_pass_through(overlay_image, true);
				notify["icon-overlay"].connect(() => {
					overlay_image.icon_name = icon_overlay;
				});
			}

			box.add(overlay);

			if(show_text)
			{
				var label = new Label(text);
				label.get_style_context().add_class(Granite.STYLE_CLASS_H3_LABEL);
				label.halign = Align.START;
				label.valign = Align.CENTER;
				box.add(label);
				notify["text"].connect(() => {
					label.label = text;
				});
			}
			else
			{
				tooltip_text = text;
				notify["text"].connect(() => {
					tooltip_text = text;
				});
			}

			child = box;
		}
	}
}
