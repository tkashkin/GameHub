/*
This file is part of GameHub.
Copyright (C) 2018 Anatoliy Kashkin

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

using GameHub.Data;
using GameHub.Utils;

using GameHub.UI.Widgets;

using GameHub.Data.DB;

namespace GameHub.UI.Dialogs.SettingsDialog.Tabs
{
	public class Emulators: SettingsDialogTab
	{
		private Stack stack;
		private Button add_btn;
		private Button remove_btn;

		private EmulatorPage? previous_page;

		public Emulators(SettingsDialog dlg)
		{
			Object(orientation: Orientation.HORIZONTAL, dialog: dlg);
		}

		construct
		{
			margin_start = margin_end = 0;

			var paths = FSUtils.Paths.Settings.get_instance();

			stack = new Stack();
			stack.margin_start = stack.margin_end = 8;
			stack.expand = true;
			stack.set_size_request(360, 240);

			var sidebar_box = new Box(Orientation.VERTICAL, 0);
			sidebar_box.vexpand = true;

			var sidebar = new StackSidebar();
			sidebar.stack = stack;
			sidebar.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
			sidebar.vexpand = true;
			sidebar.set_size_request(128, -1);

			var actionbar = new ActionBar();
			actionbar.vexpand = false;
			actionbar.get_style_context().add_class(Gtk.STYLE_CLASS_INLINE_TOOLBAR);

			add_btn = new Button.from_icon_name("list-add-symbolic", IconSize.MENU);
			add_btn.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);

			remove_btn = new Button.from_icon_name("list-remove-symbolic", IconSize.MENU);
			remove_btn.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);

			actionbar.pack_start(add_btn);
			actionbar.pack_end(remove_btn);

			sidebar_box.add(sidebar);
			sidebar_box.add(actionbar);

			add(sidebar_box);
			add(new Separator(Orientation.VERTICAL));
			add(stack);

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
				remove_btn.sensitive = stack.get_children().length() > 0;
			});
			remove_btn.sensitive = stack.get_children().length() > 0;
		}

		private void remove_emu_page()
		{
			var page = stack.visible_child as EmulatorPage;
			if(page != null)
			{
				page.remove();
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

			private Entry name_entry;
			private FileChooserButton executable_picker;
			private Entry args_entry;

			public EmulatorPage(Stack stack, Emulator? emulator=null)
			{
				Object(orientation: Orientation.VERTICAL, stack: stack, emulator: emulator ?? new Emulator.empty());
			}

			construct
			{
				var name_header = new HeaderLabel(_("Name"));
				name_header.xpad = 8;
				add(name_header);

				name_entry = new Entry();
				name_entry.text = emulator.name ?? "";
				name_entry.placeholder_text = name_entry.primary_icon_tooltip_text = _("Name");
				name_entry.primary_icon_name = "insert-text-symbolic";
				name_entry.primary_icon_activatable = false;
				name_entry.margin = 4;
				name_entry.margin_top = 0;
				add(name_entry);

				name_entry.changed.connect(() => {
					title = name_entry.text.strip();
					Tables.Emulators.remove(emulator);
					emulator.name = title;
				});

				name_entry.changed();

				var executable_header = new HeaderLabel(_("Executable"));
				executable_header.xpad = 8;
				add(executable_header);

				executable_picker = new FileChooserButton(_("Select executable"), FileChooserAction.OPEN);
				executable_picker.margin_start = executable_picker.margin_end = 4;

				executable_picker.file_set.connect(() => {
					emulator.executable = executable_picker.get_file();
					if(name_entry.text.strip().length == 0)
					{
						name_entry.text = executable_picker.get_file().get_basename();
					}
				});

				if(emulator.executable != null && emulator.executable.query_exists())
				{
					try
					{
						executable_picker.set_file(emulator.executable);
						executable_picker.file_set();
					}
					catch(Error e)
					{
						warning(e.message);
					}
				}

				add(executable_picker);

				var args_header = new HeaderLabel(_("Arguments"));
				args_header.xpad = 8;
				add(args_header);

				args_entry = new Entry();
				args_entry.text = emulator.arguments ?? "$file $game_args";
				args_entry.placeholder_text = args_entry.primary_icon_tooltip_text = _("Arguments");
				args_entry.primary_icon_name = "utilities-terminal-symbolic";
				args_entry.primary_icon_activatable = false;
				args_entry.margin = 4;
				args_entry.margin_top = 0;
				add(args_entry);

				args_entry.changed.connect(() => {
					emulator.arguments = args_entry.text.strip();
				});

				args_entry.changed();

				var compat_header = new HeaderLabel(_("Compatibility"));
				compat_header.no_show_all = true;
				compat_header.xpad = 8;
				add(compat_header);

				var compat_force_switch = add_switch(_("Force compatibility mode"), emulator.force_compat, f => { emulator.force_compat = f; });
				compat_force_switch.no_show_all = true;

				var compat_tool = new CompatToolPicker(emulator, false);
				compat_tool.no_show_all = true;
				compat_tool.margin_start = compat_tool.margin_end = 4;
				add(compat_tool);

				emulator.notify["use-compat"].connect(() => {
					compat_force_switch.visible = !emulator.needs_compat;
					compat_tool.visible = emulator.use_compat;
					compat_header.visible = compat_force_switch.visible || compat_tool.visible;
				});
				emulator.notify_property("use-compat");
			}

			public void save()
			{
				emulator.save();
			}

			public new void remove()
			{
				emulator.remove();
			}

			private Box add_switch(string text, bool enabled, owned SettingsDialogTab.SwitchAction action)
			{
				var sw = new Switch();
				sw.active = enabled;
				sw.halign = Align.END;
				sw.notify["active"].connect(() => { action(sw.active); });

				var label = new Label(text);
				label.halign = Align.START;
				label.hexpand = true;

				var hbox = new Box(Orientation.HORIZONTAL, 12);
				hbox.margin = 4;
				hbox.margin_start = 8;

				hbox.add(label);
				hbox.add(sw);

				hbox.show_all();

				add(hbox);
				return hbox;
			}
		}
	}
}
