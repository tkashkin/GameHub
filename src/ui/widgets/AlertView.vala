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

/* Based on Granite.Widgets.AlertView */

using Gtk;

namespace GameHub.UI.Widgets
{
	public class AlertView: Grid
	{
		public signal void action_activated();

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

		public string description
		{
			get
			{
				return description_label.label;
			}
			set
			{
				description_label.label = value;
			}
		}

		public string icon_name
		{
			owned get
			{
				return image.icon_name ?? "";
			}
			set
			{
				if(value != null && value != "")
				{
					image.set_from_icon_name(value, IconSize.DIALOG);
					image.no_show_all = false;
					image.show();
				}
				else
				{
					image.no_show_all = true;
					image.hide();
				}
			}
		}

		private Label title_label;
		private Label description_label;
		private Image image;
		private Button action_button;
		private Revealer action_revealer;

		public AlertView(string title, string description, string icon_name)
		{
			Object(title: title, description: description, icon_name: icon_name);
		}

		construct
		{
			get_style_context().add_class(Gtk.STYLE_CLASS_VIEW);

			title_label = Styled.H2Label(null);
			title_label.hexpand = true;
			title_label.max_width_chars = 75;
			title_label.wrap = true;
			title_label.wrap_mode = Pango.WrapMode.WORD_CHAR;
			title_label.use_markup = true;
			title_label.xalign = 0;

			description_label = new Label(null);
			description_label.hexpand = true;
			description_label.max_width_chars = 75;
			description_label.wrap = true;
			description_label.use_markup = true;
			description_label.xalign = 0;
			description_label.valign = Align.START;

			action_button = new Button();
			action_button.margin_top = 24;

			action_revealer = new Revealer();
			action_revealer.add(action_button);
			action_revealer.halign = Align.END;
			action_revealer.transition_type = RevealerTransitionType.SLIDE_UP;

			image = new Image();
			image.margin_top = 6;
			image.valign = Align.START;

			var layout = new Grid();
			layout.column_spacing = 12;
			layout.row_spacing = 6;
			layout.halign = Align.CENTER;
			layout.valign = Align.CENTER;
			layout.vexpand = true;
			layout.margin = 24;

			layout.attach(image, 1, 1, 1, 2);
			layout.attach(title_label, 2, 1, 1, 1);
			layout.attach(description_label, 2, 2, 1, 1);
			layout.attach(action_revealer, 2, 3, 1, 1);

			add(layout);

			action_button.clicked.connect(() => {action_activated();});
		}

		public void show_action(string? label=null)
		{
			if(label != null)
				action_button.label = label;

			if(action_button.label == null)
				return;

			action_revealer.set_reveal_child(true);
			action_revealer.show_all();
		}

		public void hide_action()
		{
			action_revealer.set_reveal_child(false);
		}
	}
}
