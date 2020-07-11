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
using Gdk;
using Gee;

using GameHub.UI.Widgets;
using GameHub.UI.Widgets.Settings;

using GameHub.Data;
using GameHub.Data.Tweaks;
using GameHub.Data.Runnables;

namespace GameHub.UI.Widgets
{
	public class TweaksList: Notebook
	{
		public Traits.Game.SupportsTweaks? game { get; construct; default = null; }

		public TweaksList(Traits.Game.SupportsTweaks? game = null)
		{
			Object(game: game, show_border: false, expand: true);
		}

		construct
		{
			update();
		}

		public void update(CompatTool? compat_tool=null)
		{
			this.foreach(w => w.destroy());

			var tweaks = Tweak.load_tweaks_grouped(game == null);

			if(tweaks != null && tweaks.size > 0)
			{
				foreach(var group in tweaks.entries)
				{
					var tab = new TweakGroupTab(game, compat_tool, group.key ?? _("Ungrouped"), group.value);
					append_page(tab, new Label(tab.group));
				}
				show_tabs = tweaks.size > 1;
			}
			else
			{
				append_page(new AlertView(_("No tweaks"), _("No tweaks were found\nAdd your tweaks into one of the tweak directories"), "dialog-warning-symbolic"));
				show_tabs = false;
			}
		}

		private class TweakGroupTab: ScrolledWindow
		{
			public Traits.Game.SupportsTweaks? game { get; construct; default = null; }
			public CompatTool? compat_tool { get; construct; default = null; }
			public string? group { get; construct; default = null; }
			public HashMap<string, Tweak>? tweaks { get; construct; default = null; }

			public TweakGroupTab(Traits.Game.SupportsTweaks? game = null, CompatTool? compat_tool = null, string? group = null, HashMap<string, Tweak>? tweaks = null)
			{
				Object(game: game, compat_tool: compat_tool, group: group, tweaks: tweaks, hscrollbar_policy: PolicyType.NEVER, expand: true);
			}

			construct
			{
				var tweaks_list = new ListBox();
				tweaks_list.selection_mode = SelectionMode.NONE;
				child = tweaks_list;

				if(tweaks != null)
				{
					foreach(var tweak in tweaks.values)
					{
						if(game == null || tweak.is_applicable_to(game, compat_tool))
						{
							tweaks_list.add(new TweakRow(tweak, game));
						}
					}
				}

				tweaks_list.row_activated.connect(row => {
					var setting = row as ActivatableSetting;
					if(setting != null)
					{
						setting.setting_activated();
					}
				});

				show_all();
			}
		}

		private class TweakRow: ListBoxRow, ActivatableSetting
		{
			public Tweak tweak { get; construct; }
			public Traits.Game.SupportsTweaks? game { get; construct; default = null; }

			public TweakRow(Tweak tweak, Traits.Game.SupportsTweaks? game=null)
			{
				Object(tweak: tweak, game: game, activatable: true, selectable: false);
			}

			construct
			{
				get_style_context().add_class("setting");
				get_style_context().add_class("tweak-setting");

				var grid = new Grid();
				grid.column_spacing = 12;

				var icon = new Image.from_icon_name(tweak.icon, IconSize.LARGE_TOOLBAR);
				icon.valign = Align.CENTER;

				var name = new Label(tweak.name ?? tweak.id);
				name.get_style_context().add_class("title");
				name.set_size_request(96, -1);
				name.hexpand = true;
				name.ellipsize = Pango.EllipsizeMode.END;
				name.max_width_chars = 60;
				name.xalign = 0;
				name.valign = Align.CENTER;

				var description = new Label(tweak.description ?? _("No description"));
				description.get_style_context().add_class("description");
				description.tooltip_text = tweak.description;
				description.get_style_context().add_class(Gtk.STYLE_CLASS_DIM_LABEL);
				description.hexpand = true;
				description.ellipsize = Pango.EllipsizeMode.END;
				description.max_width_chars = 60;
				description.xalign = 0;
				description.valign = Align.CENTER;

				var install = new Button.with_label(_("Install"));
				install.valign = Align.CENTER;
				install.sensitive = false;

				var enabled = new Switch();
				enabled.active = tweak.is_enabled(game);
				enabled.valign = Align.CENTER;

				var buttons_hbox = new Box(Orientation.HORIZONTAL, 0);
				buttons_hbox.valign = Align.CENTER;

				grid.attach(icon, 0, 0, 1, 2);
				grid.attach(name, 1, 0);
				grid.attach(description, 1, 1);
				grid.attach(buttons_hbox, 2, 0, 1, 2);

				if(tweak.url != null)
				{
					var url = new Button.from_icon_name("web-symbolic", IconSize.BUTTON);
					url.tooltip_markup = """<span weight="600" size="smaller">%s</span>%s%s""".printf(_("Open URL"), "\n", tweak.url);
					url.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);

					url.clicked.connect(() => {
						Utils.open_uri(tweak.url);
					});

					buttons_hbox.add(url);
				}

				if(tweak.file != null && tweak.file.query_exists())
				{
					var edit = new Button.from_icon_name("accessories-text-editor-symbolic", IconSize.BUTTON);
					edit.tooltip_markup = """<span weight="600" size="smaller">%s</span>%s%s""".printf(_("Edit file"), "\n", tweak.file.get_path());
					edit.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);

					edit.clicked.connect(() => {
						Utils.open_uri(tweak.file.get_uri());
					});

					buttons_hbox.add(edit);
				}

				MenuButton? options = null;
				if(tweak.options != null && tweak.options.size > 0)
				{
					var options_menu = new Gtk.Menu();

					foreach(var option in tweak.options)
					{
						var option_menu = new Gtk.Menu();

						if(option.presets != null && option.presets.size > 0)
						{
							RadioMenuItem? preset_item = null;

							var presets_header = new Gtk.MenuItem.with_label("""<span weight="600" size="smaller">%s</span>""".printf(_("Presets")));
							((Label) presets_header.get_child()).use_markup = true;
							presets_header.sensitive = false;
							option_menu.append(presets_header);

							foreach(var preset in option.presets)
							{
								var preset_item_label = preset.name ?? preset.id;
								if(preset.description != null)
								{
									preset_item_label = """%s%s<span size="smaller">%s</span>""".printf(preset_item_label, "\n", preset.description);
								}

								preset_item = new RadioMenuItem.with_label_from_widget(preset_item, preset_item_label);
								((Label) preset_item.get_child()).use_markup = true;
								option_menu.append(preset_item);
							}
						}

						if(option.values != null && option.values.size > 0)
						{
							if(option.presets != null && option.presets.size > 0)
							{
								option_menu.append(new SeparatorMenuItem());
							}

							var values_header = new Gtk.MenuItem.with_label("""<span weight="600" size="smaller">%s</span>""".printf(_("Options")));
							((Label) values_header.get_child()).use_markup = true;
							values_header.sensitive = false;
							option_menu.append(values_header);

							foreach(var value in option.values.entries)
							{
								var value_item = new CheckMenuItem.with_label("""%s%s<span size="smaller">%s</span>""".printf(value.key, "\n", value.value));
								((Label) value_item.get_child()).use_markup = true;
								option_menu.append(value_item);
							}
						}

						var option_item_label = option.name ?? option.id;
						if(option.description != null)
						{
							option_item_label = """%s%s<span size="smaller">%s</span>""".printf(option_item_label, "\n", option.description);
						}

						var option_item = new Gtk.MenuItem.with_label(option_item_label);
						((Label) option_item.get_child()).use_markup = true;
						option_item.submenu = option_menu;
						options_menu.append(option_item);
					}

					options_menu.show_all();

					options = new MenuButton();
					options.image = new Image.from_icon_name("gh-settings-cog-symbolic", IconSize.BUTTON);
					options.popup = options_menu;
					options.tooltip_text = _("Options");
					options.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);

					buttons_hbox.add(options);
				}

				grid.attach(enabled, 4, 0, 1, 2);

				var unavailable_reqs = tweak.get_unavailable_requirements();
				if(unavailable_reqs != null)
				{
					string[] reqs = {};

					if(unavailable_reqs.executables != null && unavailable_reqs.executables.size != 0)
					{
						reqs += """%s<span weight="600" size="smaller">%s</span>""".printf("\n", unavailable_reqs.executables.size == 1
								? _("Requires an executable")
								: _("Requires one of the executables"));
						foreach(var executable in unavailable_reqs.executables)
						{
							reqs += "• %s".printf(executable);
						}
					}

					if(unavailable_reqs.kernel_modules != null)
					{
						reqs += """%s<span weight="600" size="smaller">%s</span>""".printf("\n", unavailable_reqs.kernel_modules.size == 1
							? _("Requires a kernel module")
							: _("Requires one of the kernel modules"));

						foreach(var kmod in unavailable_reqs.kernel_modules)
						{
							reqs += "• %s".printf(kmod);
						}
					}

					if(options != null)
					{
						options.sensitive = false;
					}

					enabled.sensitive = false;
					activatable = false;
					icon.icon_name = "action-unavailable-symbolic";
					icon.tooltip_markup = enabled.tooltip_markup = string.joinv("\n", reqs).strip();
				}
				else
				{
					enabled.notify["active"].connect(() => {
						tweak.set_enabled(enabled.active, game);
					});
					setting_activated.connect(() => {
						enabled.activate();
					});
				}

				child = grid;
			}
		}
	}
}
