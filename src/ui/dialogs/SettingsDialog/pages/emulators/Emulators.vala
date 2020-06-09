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
using GameHub.Utils;

using GameHub.UI.Widgets;

using GameHub.Data.DB;

namespace GameHub.UI.Dialogs.SettingsDialog.Pages.Emulators
{
	public class Emulators: SettingsSidebar.SettingsPage
	{
		public SettingsDialog dialog { construct; protected get; }

		private Stack stack;
		private Button add_btn;
		private Button remove_btn;

		private EmulatorPage? previous_page;

		public Emulators(SettingsDialog dlg)
		{
			Object(
				dialog: dlg,
				title: _("Emulators"),
				status: _("No custom emulators"),
				icon_name: "application-x-executable-symbolic"
			);
		}

		construct
		{
			var paths = FSUtils.Paths.Settings.instance;

			var content_hbox = new Box(Orientation.HORIZONTAL, 0);

			stack = new Stack();
			stack.expand = true;

			var sidebar_box = new Box(Orientation.VERTICAL, 0);
			sidebar_box.vexpand = true;

			var sidebar = new StackSidebar();
			sidebar.stack = stack;
			sidebar.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
			sidebar.vexpand = true;
			sidebar.set_size_request(128, -1);

			var actionbar = new ActionBar();
			actionbar.vexpand = false;

			add_btn = new Button.from_icon_name("list-add-symbolic", IconSize.MENU);
			add_btn.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);

			remove_btn = new Button.from_icon_name("list-remove-symbolic", IconSize.MENU);
			remove_btn.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);

			var actions = new Box(Orientation.HORIZONTAL, 0);
			actions.get_style_context().add_class(Gtk.STYLE_CLASS_LINKED);

			actions.add(add_btn);
			actions.add(remove_btn);

			actionbar.pack_start(actions);

			sidebar_box.add(sidebar);
			sidebar_box.add(actionbar);

			content_hbox.add(sidebar_box);
			content_hbox.add(new Separator(Orientation.VERTICAL));
			content_hbox.add(stack);

			add(content_hbox);

			stack.notify["visible-child"].connect(() => {
				var page = stack.visible_child as EmulatorPage;
				if(previous_page != null && previous_page != page)
				{
					previous_page.save();
				}
				previous_page = page;
			});

			dialog.destroy.connect(() => {
				if(previous_page != null)
				{
					previous_page.save();
				}
			});

			add_btn.clicked.connect(() => {
				add_emu_page();
			});

			remove_btn.clicked.connect(() => {
				remove_emu_page();
			});

			var emulators = Tables.Emulators.get_all();
			foreach(var emu in emulators)
			{
				add_emu_page(emu);
			}

			Idle.add(() => {
				update();
				return Source.REMOVE;
			});
		}

		private void add_emu_page(Emulator? emulator=null)
		{
			var page = new EmulatorPage(stack, emulator);
			var id = emulator != null ? "emu/" + emulator.id : stack.get_children().length().to_string();
			stack.add_titled(page, id, emulator != null ? emulator.name : "");
			page.show_all();
			if(emulator == null)
			{
				stack.set_visible_child(page);
			}
			page.emulator.removed.connect(() => {
				stack.remove(page);
				update();
			});
			update();
		}

		private void remove_emu_page()
		{
			var page = stack.visible_child as EmulatorPage;
			if(page != null)
			{
				page.remove();
				update();
			}
		}

		private void update()
		{
			var count = stack.get_children().length();
			remove_btn.sensitive = count > 0;
			if(count > 0)
			{
				status = ngettext("%u custom emulator", "%u custom emulators", count).printf(count);
			}
			else
			{
				status = _("No custom emulators");
			}
		}

		private class EmulatorPage: Box
		{
			private string _title;
			public string title
			{
				get
				{
					return _title;
				}
				set
				{
					_title = value.strip();
					if(parent == stack)
					{
						stack.child_set(this, title: _title);
					}
				}
			}
			public Stack stack { get; construct; }
			public Emulator emulator { get; construct set; }

			private Grid grid;
			private int rows = 0;

			private ModeButton mode;

			private new Entry name;
			private FileChooserEntry emudir;
			private FileChooserEntry executable;
			private Label executable_label;
			private Entry arguments;
			private Label arguments_label;

			private Entry game_executable_pattern;
			private Label game_executable_pattern_label;
			private Entry game_image_pattern;
			private Label game_image_pattern_label;
			private Entry game_icon_pattern;
			private Label game_icon_pattern_label;

			private Button run_btn;
			private Button save_btn;

			public EmulatorPage(Stack stack, Emulator? emulator=null)
			{
				Object(orientation: Orientation.VERTICAL, stack: stack, emulator: emulator ?? new Emulator.empty());
			}

			construct
			{
				grid = new Grid();
				grid.margin = 6;
				grid.expand = true;
				grid.row_spacing = 4;
				grid.column_spacing = 8;

				var grid_scroll = new ScrolledWindow(null, null);
				grid_scroll.get_style_context().add_class(Gtk.STYLE_CLASS_VIEW);
				grid_scroll.get_style_context().add_class(Gtk.STYLE_CLASS_FRAME);
				grid_scroll.margin_start = grid_scroll.margin_end = 1;
				grid_scroll.expand = true;

				grid_scroll.add(grid);
				add(grid_scroll);

				save_btn = new Button.with_label(_("Save"));
				save_btn.halign = Align.END;
				save_btn.valign = Align.END;
				save_btn.sensitive = false;

				run_btn = new Button.with_label(_("Run"));
				run_btn.halign = Align.START;
				run_btn.valign = Align.END;
				run_btn.sensitive = false;

				mode = new ModeButton();
				mode.margin_bottom = 8;
				mode.halign = Align.CENTER;
				mode.append_text(_("Executable"));
				mode.append_text(_("Installer"));
				mode.selected = 0;
				grid.attach(mode, 0, rows, 2, 1);
				rows++;

				name = add_entry(_("Name"), "insert-text-symbolic", true);

				name.text = emulator.name ?? "";

				name.changed.connect(() => {
					title = name.text.strip();
					Tables.Emulators.remove(emulator);
					emulator.name = title;
				});

				name.changed();

				add_separator();

				executable = add_filechooser(_("Executable"), _("Select executable"), FileChooserAction.OPEN, true, out executable_label);

				arguments = add_entry(_("Arguments"), "utilities-terminal-symbolic", false, out arguments_label);
				arguments.text = emulator.arguments ?? "$file $game_args";

				arguments.tooltip_markup =
					"""<span weight="600" size="smaller">%s</span>""".printf(_("Variables")) + "\n\n" +
					"""<span weight="600">$file</span> - %s""".printf(_("Game executable")) + "\n" +
					"""<span weight="600">$game_args</span> - %s""".printf(_("Game arguments"));

				arguments.changed.connect(() => {
					emulator.arguments = arguments.text.strip();
				});

				arguments.changed();

				add_separator();

				emudir = add_filechooser(_("Directory"), _("Select emulator directory"), FileChooserAction.SELECT_FOLDER, true);

				add_separator();

				var compat_force_switch = add_switch(_("Force compatibility mode"), emulator.force_compat, f => { emulator.force_compat = f; });
				compat_force_switch.no_show_all = true;

				var compat_tool = new CompatToolPicker(emulator, false, true);
				compat_tool.no_show_all = true;
				grid.attach(compat_tool, 0, rows, 2, 1);
				rows++;

				emulator.notify["use-compat"].connect(() => {
					compat_force_switch.visible = !emulator.needs_compat;
					compat_tool.visible = emulator.use_compat;
				});

				add_separator();

				var patterns_header = Styled.H4Label(_("Game file patterns"));
				patterns_header.margin_start = patterns_header.margin_end = 4;
				grid.attach(patterns_header, 0, rows, 2, 1);
				rows++;

				game_executable_pattern = add_entry(_("Executable"), "application-x-executable", false, out game_executable_pattern_label);
				game_executable_pattern.placeholder_text = "*.bin|*.rom|./code/*.rpx";

				game_image_pattern = add_entry(_("Image"), "image-x-generic", false, out game_image_pattern_label);
				game_image_pattern.placeholder_text = "./cover.png|./meta/bootTvTex.tga";

				game_icon_pattern = add_entry(_("Icon"), "image-x-generic-symbolic", false, out game_icon_pattern_label);
				game_icon_pattern.placeholder_text = "./icon.png|./meta/iconTex.tga";

				game_executable_pattern.text = emulator.game_executable_pattern ?? "";
				game_image_pattern.text = emulator.game_image_pattern ?? "";
				game_icon_pattern.text = emulator.game_icon_pattern ?? "";

				var patterns_syntax = new Label(_("<b>findutils</b>-compatible glob patterns\n\n<b>•</b> Multiple patterns can be separated with <b>|</b>\n<b>•</b> Start pattern with <b>./</b> to match relative path\n<b>•</b> $<b>basename</b> variable will be replaced with game's executable name (without extension)"));
				patterns_syntax.wrap = true;
				patterns_syntax.use_markup = true;
				patterns_syntax.xalign = 0;

				var patterns_syntax_info = new InfoBar();
				patterns_syntax_info.get_style_context().add_class(Gtk.STYLE_CLASS_FRAME);
				patterns_syntax_info.get_style_context().add_class("settings-info");
				patterns_syntax_info.message_type = MessageType.INFO;
				patterns_syntax_info.get_content_area().add(patterns_syntax);

				grid.attach(patterns_syntax_info, 0, rows, 2, 1);
				rows++;

				var btn_box = new Box(Orientation.HORIZONTAL, 0);
				btn_box.margin_start = btn_box.margin_end = 8;
				btn_box.margin_top = btn_box.margin_bottom = 4;

				btn_box.pack_start(run_btn);
				btn_box.pack_end(save_btn);

				add(btn_box);

				run_btn.clicked.connect(run);
				save_btn.clicked.connect(save);

				mode.mode_changed.connect(update);

				executable.file_set.connect(() => {
					emulator.executable = executable.file;
					if(name.text.strip().length == 0 && executable.file != null)
					{
						name.text = executable.file.get_basename();
					}
					update();
				});

				if(emulator.install_dir != null && emulator.install_dir.query_exists())
				{
					try
					{
						emudir.select_file(emulator.install_dir);
					}
					catch(Error e)
					{
						warning(e.message);
					}
				}

				if(emulator.executable != null && emulator.executable.query_exists())
				{
					try
					{
						executable.select_file(emulator.executable);
					}
					catch(Error e)
					{
						warning(e.message);
					}
				}

				update();
			}

			private void update()
			{
				if(mode.selected == 0 && executable.file != null && emudir.file == null)
				{
					emudir.select_file(executable.file.get_parent());
				}

				emulator.name = title;
				emulator.arguments = arguments.text.strip();
				emulator.game_executable_pattern = game_executable_pattern.text.strip();
				emulator.game_image_pattern = game_image_pattern.text.strip();
				emulator.game_icon_pattern = game_icon_pattern.text.strip();

				emulator.install_dir = emudir.file;

				executable_label.label = mode.selected == 0 ? _("Executable") : _("Installer");
				arguments.sensitive = arguments_label.sensitive = mode.selected == 0;

				run_btn.sensitive = emulator.name.length > 0 && executable.file != null && mode.selected == 0 && emudir.file != null;
				save_btn.sensitive = emulator.name.length > 0 && executable.file != null && ((mode.selected == 0 && emudir.file != null) || mode.selected == 1);

				emulator.notify_property("use-compat");
			}

			public void save()
			{
				update();

				if(mode.selected == 1 && executable.file != null && emudir.file != null)
				{
					sensitive = false;

					emulator.installer = new Emulator.Installer(emulator, emulator.executable);

					emulator.executable = null;
					emulator.install.begin(Runnable.Installer.InstallMode.INTERACTIVE, (obj, res) => {
						try
						{
							emulator.install.end(res);
						}
						catch(Utils.RunError error)
						{
							//FIXME [DEV-ART]: Replace this with inline error display?
							GameHub.UI.Dialogs.QuickErrorDialog.display_and_log.begin(
								this, error, Log.METHOD,
								//TODO: Is this accurate?
								_("Installing emulator “%s” failed").printf(emulator.name)
							);
						}
						sensitive = true;
						mode.selected = 0;
						executable.select_file(emulator.executable);
						emulator.save();
					});

					return;
				}

				emulator.save();
			}

			public void run()
			{
				save();
				emulator.run_game.begin(null);
			}

			public new void remove()
			{
				emulator.remove();
			}

			private Entry add_entry(string text, string icon, bool required=true, out Label label=null)
			{
				label = new Label(text);
				label.halign = Align.START;
				label.xalign = 1;
				label.margin = 4;
				label.hexpand = true;
				if(required)
				{
					label.get_style_context().add_class("category-label");
				}
				var entry = new Entry();
				entry.primary_icon_name = icon;
				entry.primary_icon_activatable = false;
				entry.set_size_request(280, -1);
				grid.attach(label, 0, rows);
				grid.attach(entry, 1, rows);
				rows++;
				return entry;
			}

			private FileChooserEntry add_filechooser(string text, string title, FileChooserAction action=FileChooserAction.OPEN, bool required=true, out Label label=null)
			{
				label = new Label(text);
				label.halign = Align.START;
				label.xalign = 1;
				label.margin = 4;
				label.hexpand = true;
				if(required)
				{
					label.get_style_context().add_class("category-label");
				}
				var entry = new FileChooserEntry(title, action, null, null, false, action == FileChooserAction.OPEN);
				entry.set_size_request(280, -1);
				grid.attach(label, 0, rows);
				grid.attach(entry, 1, rows);
				rows++;
				return entry;
			}

			private void add_separator()
			{
				var separator = new Separator(Orientation.HORIZONTAL);
				separator.margin_top = separator.margin_bottom = 2;
				grid.attach(separator, 0, rows, 2, 1);
				rows++;
			}

			private Box add_switch(string text, bool enabled, owned SettingsDialogPage.SwitchAction action)
			{
				var sw = new Switch();
				sw.active = enabled;
				sw.halign = Align.END;
				sw.notify["active"].connect(() => { action(sw.active); });

				var label = new Label(text);
				label.halign = Align.START;
				label.hexpand = true;

				var hbox = new Box(Orientation.HORIZONTAL, 12);
				hbox.margin_start = 4;

				hbox.add(label);
				hbox.add(sw);

				hbox.show_all();

				grid.attach(hbox, 0, rows, 2, 1);
				rows++;
				return hbox;
			}
		}
	}
}
