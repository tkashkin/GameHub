using Gtk;
using Granite;
using GameHub.Utils;

namespace GameHub.UI.Dialogs
{
	public class SettingsDialog: Dialog
	{
		private Box box;
		
		public SettingsDialog()
		{
			Object(transient_for: Windows.MainWindow.instance, deletable: false, resizable: false, title: _("Settings"));
			
			modal = true;
			
			var content = get_content_area();
			content.set_size_request(480, -1);

			box = new Box(Orientation.VERTICAL, 0);
			box.margin_start = box.margin_end = 8;
			
			var ui = Settings.UI.get_instance();
			var paths = FSUtils.Paths.Settings.get_instance();

			var steam_auth = Settings.Auth.Steam.get_instance();
			var gog_auth = Settings.Auth.GOG.get_instance();
			var humble_auth = Settings.Auth.Humble.get_instance();
			
			add_switch(_("Use dark theme"), ui.dark_theme, e => { ui.dark_theme = e; });
			add_separator();
			
			add_header_with_checkbox("Steam", steam_auth.enabled, v => { steam_auth.enabled = v; });
			add_labeled_link(_("Steam API keys have limited number of uses per day"), _("Generate key"), "https://steamcommunity.com/dev/apikey");
			add_entry(_("Steam API key"), steam_auth.api_key, v => { steam_auth.api_key = v; });
			add_file_chooser(_("Steam installation directory"), FileChooserAction.SELECT_FOLDER, paths.steam_home, v => { paths.steam_home = v; }, false);
			add_separator();
			
			add_header_with_checkbox("GOG", gog_auth.enabled, v => { gog_auth.enabled = v; });
			#if !FLATPAK
			add_file_chooser(_("GOG games directory"), FileChooserAction.SELECT_FOLDER, paths.gog_games, v => { paths.gog_games = v; });
			#endif
			add_cache_directory(_("GOG installers cache"), FSUtils.Paths.GOG.Installers);
			add_separator();
			
			add_header_with_checkbox("Humble Bundle", humble_auth.enabled, v => { humble_auth.enabled = v; });
			#if !FLATPAK
			add_file_chooser(_("Humble Bundle games directory"), FileChooserAction.SELECT_FOLDER, paths.humble_games, v => { paths.humble_games = v; });
			#endif
			add_cache_directory(_("Humble Bundle installers cache"), FSUtils.Paths.Humble.Installers);
			
			content.pack_start(box, false, false, 0);
			
			response.connect((source, response_id) => {
				switch(response_id)
				{
					case ResponseType.CLOSE:
						destroy();
						break;
				}
			});

			add_button(_("Close"), ResponseType.CLOSE).margin_end = 7;
			show_all();
		}
		
		private void add_switch(string text, bool enabled, owned SwitchAction action)
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
		
		private void add_entry(string text, string val, owned EntryAction action)
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

		private void add_file_chooser(string text, FileChooserAction mode, string val, owned EntryAction action, bool create=true)
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
		
		private void add_label(string text)
		{
			var label = new Label(text);
			label.halign = Align.START;
			label.hexpand = true;
			add_widget(label);
		}
		
		private void add_header(string text)
		{
			var label = new HeaderLabel(text);
			label.xpad = 4;
			label.halign = Align.START;
			label.hexpand = true;
			add_widget(label);
		}
		
		private void add_header_with_checkbox(string text, bool enabled, owned SwitchAction action)
		{
			var cb = new CheckButton.with_label(text);
			cb.active = enabled;
			cb.halign = Align.START;
			cb.hexpand = true;
			cb.notify["active"].connect(() => { action(cb.active); });

			cb.get_style_context().add_class(Granite.STYLE_CLASS_H4_LABEL);

			add_widget(cb);
		}

		private void add_link(string text, string uri)
		{
			var link = new LinkButton.with_label(uri, text);
			link.halign = Align.START;
			link.hexpand = true;
			add_widget(link);
		}
		
		private void add_labeled_link(string label_text, string text, string uri)
		{
			var label = new Label(label_text);
			label.halign = Align.START;
			
			var link = new LinkButton.with_label(uri, text);
			link.halign = Align.START;
			
			var hbox = new Box(Orientation.HORIZONTAL, 12);
			hbox.add(label);
			hbox.add(link);
			add_widget(hbox);
		}
		
		private void add_cache_directory(string name, string path)
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

		private void add_separator()
		{
			add_widget(new Separator(Orientation.HORIZONTAL));
		}
		
		private void add_widget(Widget widget)
		{
			if(!(widget is HeaderLabel)) widget.margin = 4;
			box.add(widget);
		}
		
		private delegate void SwitchAction(bool active);
		private delegate void EntryAction(string val);
		private delegate void ButtonAction();
	}
}
