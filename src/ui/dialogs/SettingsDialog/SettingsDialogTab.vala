using Gtk;
using Granite;
using GameHub.Utils;

namespace GameHub.UI.Dialogs.SettingsDialog
{
	public abstract class SettingsDialogTab: Box
	{
		public SettingsDialog dialog { construct; protected get; }

		public SettingsDialogTab(SettingsDialog dlg)
		{
			Object(orientation: Orientation.VERTICAL, dialog: dlg);
		}

		protected void add_switch(string text, bool enabled, owned SwitchAction action)
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
			add_widget(hbox);
		}

		protected void add_entry(string text, string val, owned EntryAction action)
		{
			var entry = new Entry();
			entry.text = val;
			entry.notify["text"].connect(() => { action(entry.text); });
			entry.set_size_request(280, -1);

			var label = new Label(text);
			label.halign = Align.START;
			label.hexpand = true;

			var hbox = new Box(Orientation.HORIZONTAL, 12);
			hbox.add(label);
			hbox.add(entry);
			add_widget(hbox);
		}

		protected void add_file_chooser(string text, FileChooserAction mode, string val, owned EntryAction action, bool create=true)
		{
			var chooser = new FileChooserButton(text, mode);
			chooser.create_folders = create;
			chooser.select_filename(FSUtils.expand(val));
			chooser.file_set.connect(() => { action(chooser.get_filename()); });
			chooser.set_size_request(280, -1);

			var label = new Label(text);
			label.halign = Align.START;
			label.hexpand = true;

			var hbox = new Box(Orientation.HORIZONTAL, 12);
			hbox.add(label);
			hbox.add(chooser);
			add_widget(hbox);
		}

		protected void add_label(string text)
		{
			var label = new Label(text);
			label.halign = Align.START;
			label.hexpand = true;
			add_widget(label);
		}

		protected void add_header(string text)
		{
			var label = new HeaderLabel(text);
			label.xpad = 4;
			label.halign = Align.START;
			label.hexpand = true;
			add_widget(label);
		}

		protected void add_header_with_checkbox(string text, bool enabled, owned SwitchAction action)
		{
			var cb = new CheckButton.with_label(text);
			cb.active = enabled;
			cb.halign = Align.START;
			cb.hexpand = true;
			cb.notify["active"].connect(() => { action(cb.active); });

			cb.get_style_context().add_class(Granite.STYLE_CLASS_H4_LABEL);

			add_widget(cb);
		}

		protected void add_link(string text, string uri)
		{
			var link = new LinkButton.with_label(uri, text);
			link.halign = Align.START;
			link.hexpand = true;
			add_widget(link);
		}

		protected void add_labeled_link(string label_text, string text, string uri)
		{
			var label = new Label(label_text);
			label.max_width_chars = 44;
			label.xalign = 0;
			label.wrap = true;
			label.halign = Align.START;
			label.hexpand = true;

			var link = new LinkButton.with_label(uri, text);
			link.halign = Align.END;

			var hbox = new Box(Orientation.HORIZONTAL, 12);
			hbox.add(label);
			hbox.add(link);
			add_widget(hbox);
		}

		protected void add_cache_directory(string name, string path)
		{
			var bbox = new Box(Orientation.HORIZONTAL, 2);
			bbox.set_size_request(280, -1);

			var size_label = new Label(null);
			size_label.margin_end = 8;
			size_label.halign = Align.START;

			var open_btn = new Button();
			open_btn.label = _("Open");
			open_btn.clicked.connect(() => {
				Utils.open_uri(FSUtils.file(path).get_uri());
			});

			var clear_btn = new Button();
			clear_btn.get_style_context().add_class(STYLE_CLASS_DESTRUCTIVE_ACTION);
			clear_btn.label = _("Clear");

			var label = new Label(name);
			label.halign = Align.START;
			label.hexpand = true;

			bbox.pack_start(size_label);
			bbox.pack_start(open_btn, false);
			bbox.pack_start(clear_btn, false);

			SourceFunc calc_size = () => {
				try
				{
					uint64 dir_size;
					uint64 files;
					FSUtils.file(path).measure_disk_usage(FileMeasureFlags.NONE, null, null, out dir_size, null, out files);
					size_label.label = ngettext("%llu installer; %s", "%llu installers; %s", (ulong) files).printf(files, format_size(dir_size));
					clear_btn.sensitive = dir_size > 32;
				}
				catch(Error e){}
				return false;
			};

			calc_size();

			clear_btn.clicked.connect(() => {
				FSUtils.rm(path, "*");
				calc_size();
			});

			var hbox = new Box(Orientation.HORIZONTAL, 12);
			hbox.add(label);
			hbox.add(bbox);
			add_widget(hbox);
		}

		protected void add_separator()
		{
			add_widget(new Separator(Orientation.HORIZONTAL));
		}

		protected void add_widget(Widget widget)
		{
			if(!(widget is HeaderLabel)) widget.margin = 4;
			add(widget);
		}

		protected delegate void SwitchAction(bool active);
		protected delegate void EntryAction(string val);
		protected delegate void ButtonAction();
	}
}