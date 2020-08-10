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

namespace GameHub.UI.Widgets.Tweaks
{
	public class TweakRow: ListBoxRow, ActivatableSetting
	{
		public Tweak tweak { get; construct; }
		public TweakSet tweakset { get; construct; }

		public Requirements? unavailable_reqs { get; private set; }
		public bool is_available { get { return unavailable_reqs == null; } }

		public TweakRow(Tweak tweak, TweakSet tweakset)
		{
			Object(tweak: tweak, tweakset: tweakset, activatable: true, selectable: false);
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
			name.hexpand = true;
			name.ellipsize = Pango.EllipsizeMode.END;
			name.xalign = 0;
			name.valign = Align.CENTER;

			var install = new Button.with_label(_("Install"));
			install.valign = Align.CENTER;
			install.sensitive = false;

			var enabled = new Switch();
			enabled.active = tweakset.is_enabled(tweak.id);
			enabled.valign = Align.CENTER;

			var buttons_hbox = new Box(Orientation.HORIZONTAL, 0);
			buttons_hbox.valign = Align.CENTER;

			grid.attach(icon, 0, 0, 1, 2);
			grid.attach(buttons_hbox, 2, 0, 1, 2);
			grid.attach(enabled, 4, 0, 1, 2);

			if(tweak.description != null)
			{
				var description = new Label(tweak.description);
				description.get_style_context().add_class(Gtk.STYLE_CLASS_DIM_LABEL);
				description.get_style_context().add_class("description");
				description.tooltip_text = tweak.description;
				description.hexpand = true;
				description.ellipsize = Pango.EllipsizeMode.END;
				description.xalign = 0;
				description.valign = Align.CENTER;
				grid.attach(name, 1, 0);
				grid.attach(description, 1, 1);
			}
			else
			{
				grid.attach(name, 1, 0, 1, 2);
			}

			if(tweak.url != null)
			{
				var url = new Button.from_icon_name("web-symbolic", IconSize.BUTTON);
				url.tooltip_markup = """<span weight="600" size="smaller" alpha="75%">%s</span>%s%s""".printf(_("Open URL"), "\n", tweak.url);
				url.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);

				url.clicked.connect(() => {
					Utils.open_uri(tweak.url);
				});

				buttons_hbox.add(url);
			}

			if(tweak.file != null && tweak.file.query_exists())
			{
				var edit = new Button.from_icon_name("accessories-text-editor-symbolic", IconSize.BUTTON);
				edit.tooltip_markup = """<span weight="600" size="smaller" alpha="75%">%s</span>%s%s""".printf(_("Edit file"), "\n", tweak.file.get_path());
				edit.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);

				edit.clicked.connect(() => {
					Utils.open_uri(tweak.file.get_uri());
				});

				buttons_hbox.add(edit);
			}

			MenuButton? options = null;
			if(tweak.options != null && tweak.options.size > 0)
			{
				var options_popover = new TweakOptionsPopover(tweak, tweakset);
				options = new MenuButton();
				options.tooltip_text = _("Options");
				options.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
				options.image = new Image.from_icon_name("gh-settings-cog-symbolic", IconSize.BUTTON);
				options.popover = options_popover;
				options_popover.position = PositionType.LEFT;
				buttons_hbox.add(options);
			}

			unavailable_reqs = tweak.get_unavailable_requirements();
			if(unavailable_reqs != null)
			{
				string[] reqs = {};

				if(unavailable_reqs.executables != null && unavailable_reqs.executables.size != 0)
				{
					reqs += """%s<span weight="600" size="smaller" alpha="75%">%s</span>""".printf("\n", unavailable_reqs.executables.size == 1
							? _("Requires an executable")
							: _("Requires one of the executables"));
					foreach(var executable in unavailable_reqs.executables)
					{
						reqs += "• %s".printf(executable);
					}
				}

				if(unavailable_reqs.kernel_modules != null)
				{
					reqs += """%s<span weight="600" size="smaller" alpha="75%">%s</span>""".printf("\n", unavailable_reqs.kernel_modules.size == 1
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
				enabled.active = false;
				activatable = false;
				name.sensitive = false;
				tooltip_markup = string.joinv("\n", reqs).strip();
				icon.opacity = 0.6;
				if(icon.icon_name == "gh-settings-cogs-symbolic")
				{
					icon.icon_name = "action-unavailable-symbolic";
				}
			}
			else
			{
				if(!tweakset.is_global && tweakset.get_or_create_options(tweak).state == TweakOptions.State.GLOBAL)
				{
					enabled.opacity = 0.6;
					enabled.tooltip_text = enabled.active ? _("Enabled globally") : _("Disabled globally");
				}

				enabled.notify["active"].connect(() => {
					var tweak_opts = tweakset.get_or_create_options(tweak);
					tweak_opts.state = enabled.active ? TweakOptions.State.ENABLED : TweakOptions.State.DISABLED;
					tweakset.set_options_for_tweak(tweak, tweak_opts);
					enabled.opacity = 1;
					enabled.tooltip_text = null;
				});
				setting_activated.connect(() => {
					enabled.activate();
				});
			}

			child = grid;
		}
	}
}
