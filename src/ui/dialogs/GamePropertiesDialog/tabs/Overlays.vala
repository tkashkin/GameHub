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
using GameHub.Data.Runnables;

using GameHub.Utils;
using GameHub.Utils.FS;

using GameHub.UI.Widgets;
using GameHub.UI.Widgets.Settings;

namespace GameHub.UI.Dialogs.GamePropertiesDialog.Tabs
{
	private class Overlays: GamePropertiesDialogTab
	{
		public Traits.Game.SupportsOverlays game { get; construct; }

		private Stack stack;

		private Box disabled_box;
		private ButtonLabelSetting enable_button;

		private SettingsGroupBox content;
		private ListBox overlays_list;
		private ScrolledWindow overlays_scrolled;

		private Entry id_entry;
		private Entry name_entry;
		private Button add_btn;

		public Overlays(Traits.Game.SupportsOverlays game)
		{
			Object(
				game: game,
				title: _("Overlays"),
				orientation: Orientation.VERTICAL
			);
		}

		construct
		{
			stack = new Stack();
			stack.transition_type = StackTransitionType.CROSSFADE;

			disabled_box = new Box(Orientation.VERTICAL, 0);

			var sgrp_disabled = new SettingsGroup();
			enable_button = sgrp_disabled.add_setting(new ButtonLabelSetting(_("Overlays are disabled for this game"), _("Enable")));
			disabled_box.add(sgrp_disabled);

			var sgrp_info_description = new SettingsGroup(_("What are Overlays?"));
			var info_description_label = sgrp_info_description.add_setting(new LabelSetting(
				"%s\n\n%s\n%s\n%s\n%s".printf(
					_("Overlays are directories layered on top of each other"),
					_("Applying overlays is equivalent to copying overlays on top of each other and replacing conflicting files"),
					_("Overlays allow to install, uninstall, enable and disable DLCs or mods without replacing game files at any time"),
					_("Each overlay is stored separately and does not affect other overlays"),
					_("All changes to the game files are stored in a separate directory and are easy to revert")
				)
			));
			info_description_label.label.xalign = 0;
			disabled_box.add(sgrp_info_description);

			content = new SettingsGroupBox();
			content.container.get_style_context().remove_class(Gtk.STYLE_CLASS_VIEW);

			overlays_list = new ListBox();
			overlays_list.selection_mode = SelectionMode.NONE;

			overlays_scrolled = new ScrolledWindow(null, null);
			overlays_scrolled.get_style_context().add_class(Gtk.STYLE_CLASS_VIEW);
			overlays_scrolled.hscrollbar_policy = PolicyType.NEVER;
			overlays_scrolled.expand = true;
			overlays_scrolled.add(overlays_list);

			var add_box = new Box(Orientation.HORIZONTAL, 0);
			add_box.get_style_context().add_class(Gtk.STYLE_CLASS_LINKED);
			add_box.margin_start = add_box.margin_end = 3;
			add_box.hexpand = true;

			id_entry = new Entry();
			id_entry.hexpand = true;
			id_entry.placeholder_text = _("Overlay ID (directory name)");
			id_entry.primary_icon_name = "list-add-symbolic";

			name_entry = new Entry();
			name_entry.hexpand = true;
			name_entry.placeholder_text = _("Overlay name (optional)");

			add_btn = new Button.with_label(_("Add"));
			add_btn.sensitive = false;

			add_box.add(id_entry);
			add_box.add(name_entry);
			add_box.add(add_btn);

			var actionbar = new ActionBar();
			actionbar.add(add_box);

			content.add_widget(overlays_scrolled);
			content.add_widget(actionbar);

			stack.add(disabled_box);
			stack.add(content);

			add(stack);

			overlays_list.row_activated.connect(row => {
				var setting = row as ActivatableSetting;
				if(setting != null)
				{
					setting.setting_activated();
				}
			});

			enable_button.button.clicked.connect(() => {
				game.enable_overlays();
			});

			destroy.connect(() => {
				game.save_overlays();
				game.mount_overlays.begin();
			});

			stack.show_all();

			game.overlays_changed.connect(update);

			add_btn.clicked.connect(add_overlay);

			id_entry.activate.connect(() => name_entry.grab_focus());
			name_entry.activate.connect(add_overlay);

			id_entry.changed.connect(() => add_btn.sensitive = id_entry.text.strip().length > 0);

			update();
		}

		private void update()
		{
			game.load_overlays();

			if(!game.overlays_enabled)
			{
				disabled_box.foreach(w => {
					if(w is InfoBar)
					{
						w.destroy();
					}
				});

				if(game.install_dir != null && game.install_dir.query_exists())
				{
					var safety = FSOverlay.RootPathSafety.for(game.install_dir);

					if(safety != FSOverlay.RootPathSafety.SAFE)
					{
						var message_type = MessageType.WARNING;
						var message = _("Overlays at this path may be unsafe\nProceed at your own risk\n\nPath: <b>%s</b>");

						if(safety == FSOverlay.RootPathSafety.RESTRICTED)
						{
							message_type = MessageType.ERROR;
							message = _("Overlays at this path are not supported\n\nPath: <b>%s</b>");
						}

						var label = new Label(message.printf(game.install_dir.get_path()));
						label.use_markup = true;

						var msg = new InfoBar();
						msg.get_style_context().add_class(Gtk.STYLE_CLASS_FRAME);
						msg.get_content_area().add(label);
						msg.message_type = message_type;
						msg.show_all();
						disabled_box.add(msg);
					}

					enable_button.sensitive = safety != FSOverlay.RootPathSafety.RESTRICTED;
				}
				else
				{
					enable_button.sensitive = false;
				}

				stack.visible_child = disabled_box;
			}
			else
			{
				stack.visible_child = content;
				enable_button.sensitive = false;

				overlays_list.foreach(w => w.destroy());

				foreach(var overlay in game.overlays)
				{
					overlays_list.add(new OverlayRow(overlay));
				}

				overlays_list.show_all();
			}
		}

		private void add_overlay()
		{
			var id = id_entry.text.strip();
			var name = name_entry.text.strip();
			if(name.length == 0) name = id;
			if(id.length == 0) return;
			game.overlays.add(new Traits.Game.SupportsOverlays.Overlay(game, id, name, true));
			game.save_overlays();
			id_entry.text = name_entry.text = "";
			id_entry.grab_focus();
		}

		private class OverlayRow: BaseSetting
		{
			public Traits.Game.SupportsOverlays.Overlay overlay { get; construct; }
			private Box buttons { get { return widget as Box; } }

			public OverlayRow(Traits.Game.SupportsOverlays.Overlay overlay)
			{
				Object(title: overlay.name, description: overlay.id, widget: new Box(Orientation.HORIZONTAL, 0), overlay: overlay, activatable: overlay.id != Traits.Game.SupportsOverlays.Overlay.BASE, selectable: false);
			}

			construct
			{
				get_style_context().add_class("overlay-setting");

				var open = new Button.from_icon_name("folder-symbolic", IconSize.SMALL_TOOLBAR);
				open.tooltip_text = _("Open directory");
				open.valign = Align.CENTER;
				open.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);

				var remove = new Button.from_icon_name("edit-delete-symbolic", IconSize.SMALL_TOOLBAR);
				remove.tooltip_text = _("Remove overlay");
				remove.sensitive = overlay.removable;
				remove.valign = Align.CENTER;
				remove.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);

				var enabled_switch = new Switch();
				enabled_switch.sensitive = activatable;
				enabled_switch.active = overlay.enabled;
				enabled_switch.valign = Align.CENTER;
				enabled_switch.margin_start = 12;

				buttons.add(open);
				buttons.add(remove);
				buttons.add(enabled_switch);

				open.clicked.connect(() => {
					Utils.open_uri(overlay.directory.get_uri());
				});

				remove.clicked.connect(() => {
					overlay.remove();
				});

				enabled_switch.notify["active"].connect(() => {
					overlay.enabled = enabled_switch.active;
					overlay.game.save_overlays();
				});

				setting_activated.connect(() => {
					enabled_switch.activate();
				});

				bind_property("activatable", enabled_switch, "sensitive", BindingFlags.SYNC_CREATE);
			}
		}
	}
}
