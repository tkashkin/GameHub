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
using Granite;

using GameHub.Utils;
using GameHub.UI.Widgets;

namespace GameHub.UI.Dialogs.SettingsDialog
{
	public abstract class SettingsDialogPage: SimpleSettingsPage
	{
		public SettingsDialog dialog { construct; protected get; }

		public bool restart_requested = false;

		public SettingsDialogPage(SettingsDialog dlg)
		{
			Object(dialog: dlg);
		}

		construct
		{
			//margin_start = margin_end = 8;
			content_area.orientation = Orientation.VERTICAL;
			content_area.row_spacing = 0;
		}

		protected void request_restart()
		{
			status_type = StatusType.WARNING;
			dialog.show_restart_message();
			restart_requested = true;
		}

		protected Box add_switch(string text, bool enabled, owned SwitchAction action)
		{
			var sw = new Switch();
			sw.active = enabled;
			sw.halign = Align.END;
			sw.notify["active"].connect(() => { action(sw.active); });

			var label = new Label(text);
			label.halign = Align.START;
			label.hexpand = true;

			var hbox = new Box(Orientation.HORIZONTAL, 12);
			hbox.add(label);
			hbox.add(sw);
			return add_widget(hbox);
		}

		protected Box add_entry(string text, string val, owned EntryAction action, string? icon=null)
		{
			var entry = new Entry();
			entry.text = val;
			entry.notify["text"].connect(() => { action(entry.text); });
			entry.set_size_request(280, -1);

			entry.primary_icon_name = icon;

			var label = new Label(text);
			label.halign = Align.START;
			label.hexpand = true;

			var hbox = new Box(Orientation.HORIZONTAL, 12);
			hbox.add(label);
			hbox.add(entry);
			return add_widget(hbox);
		}

		protected Box add_file_chooser(string text, FileChooserAction mode, string val, owned EntryAction action, bool create=true, string? icon=null, bool allow_url=false, bool allow_executable=false)
		{
			var chooser = new FileChooserEntry(text, mode, icon, null, allow_url, allow_executable);
			chooser.chooser.create_folders = create;
			chooser.chooser.show_hidden = true;
			chooser.select_file(FSUtils.file(val));
			chooser.tooltip_text = chooser.file.get_path();
			chooser.file_set.connect(() => { chooser.tooltip_text = chooser.file != null ? chooser.file.get_path() : null; action(chooser.tooltip_text); });
			chooser.set_size_request(280, -1);

			var label = new Label(text);
			label.halign = Align.START;
			label.hexpand = true;

			var hbox = new Box(Orientation.HORIZONTAL, 12);
			hbox.add(label);
			hbox.add(chooser);
			return add_widget(hbox);
		}

		protected Label add_label(string text)
		{
			var label = new Label(text);
			label.halign = Align.START;
			label.hexpand = true;
			return add_widget(label);
		}

		protected Box add_labels(string text, string text2)
		{
			var label = new Label(text);
			label.max_width_chars = 52;
			label.xalign = 0;
			label.wrap = true;
			label.halign = Align.START;
			label.hexpand = true;

			var label2 = new Label(text2);
			label2.xalign = 0;
			label2.wrap = true;
			label2.set_size_request(280, -1);

			var hbox = new Box(Orientation.HORIZONTAL, 12);
			hbox.add(label);
			hbox.add(label2);
			return add_widget(hbox);
		}

		protected HeaderLabel add_header(string text)
		{
			var label = new HeaderLabel(text);
			label.xpad = 4;
			label.halign = Align.START;
			label.hexpand = true;
			return add_widget(label);
		}

		protected CheckButton add_header_with_checkbox(string text, bool enabled, owned SwitchAction action)
		{
			var cb = new CheckButton.with_label(text);
			cb.active = enabled;
			cb.halign = Align.START;
			cb.hexpand = true;
			cb.notify["active"].connect(() => { action(cb.active); });
			cb.get_style_context().add_class(Granite.STYLE_CLASS_H4_LABEL);
			return add_widget(cb);
		}

		protected LinkButton add_link(string text, string uri)
		{
			var link = new LinkButton.with_label(uri, text);
			link.halign = Align.START;
			link.hexpand = true;
			return add_widget(link);
		}

		protected Box add_labeled_link(string label_text, string text, string uri)
		{
			var label = new Label(label_text);
			label.max_width_chars = 52;
			label.xalign = 0;
			label.wrap = true;
			label.halign = Align.START;
			label.hexpand = true;

			var link = new LinkButton.with_label(uri, text);
			link.halign = Align.END;

			var hbox = new Box(Orientation.HORIZONTAL, 12);
			hbox.add(label);
			hbox.add(link);
			return add_widget(hbox);
		}

		protected Separator add_separator()
		{
			return add_widget(new Separator(Orientation.HORIZONTAL));
		}

		protected T add_widget<T>(T widget)
		{
			if(!(widget is HeaderLabel))
			{
				(widget as Widget).margin = 4;
				(widget as Widget).margin_end = 0;
			}
			content_area.add(widget as Widget);
			return widget;
		}

		public delegate void SwitchAction(bool active);
		public delegate void EntryAction(string val);
		public delegate void ButtonAction();
	}
}
