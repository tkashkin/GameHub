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
	public class TweakRow: BaseSetting
	{
		public Tweak tweak { get; construct; }
		public TweakSet tweakset { get; construct; }

		public Requirements? unavailable_reqs { get; private set; }
		public bool is_available { get { return unavailable_reqs == null; } }

		public string? tweak_state { get; private set; }
		private Box? buttons_hbox { get { return widget as Box; } }

		public TweakRow(Tweak tweak, TweakSet tweakset)
		{
			Object(tweak: tweak, tweakset: tweakset, widget: new Box(Orientation.HORIZONTAL, 0), activatable: true, selectable: false);
		}

		construct
		{
			get_style_context().add_class("tweak-setting");

			ellipsize_title = Pango.EllipsizeMode.END;
			ellipsize_description = Pango.EllipsizeMode.END;

			title = tweak.name ?? tweak.id;
			icon_name = tweak.icon;

			buttons_hbox.valign = Align.CENTER;

			if(tweak.url != null)
			{
				var url = new Button.from_icon_name("web-symbolic", IconSize.BUTTON);
				url.tooltip_markup = """<span weight="600" size="smaller" alpha="75%">%s</span>%s%s""".printf(_("Open URL"), "\n", tweak.url);
				url.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
				url.valign = Align.CENTER;
				url.clicked.connect(() => { Utils.open_uri(tweak.url); });
				buttons_hbox.add(url);
			}

			if(tweak.file != null && tweak.file.query_exists())
			{
				var edit = new Button.from_icon_name("accessories-text-editor-symbolic", IconSize.BUTTON);
				edit.tooltip_markup = """<span weight="600" size="smaller" alpha="75%">%s</span>%s%s""".printf(_("Edit file"), "\n", tweak.file.get_path());
				edit.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
				edit.valign = Align.CENTER;
				edit.clicked.connect(() => { Utils.open_uri(tweak.file.get_uri()); });
				buttons_hbox.add(edit);
			}

			Button? options = null;
			TweakOptionsPopover? options_popover = null;
			if(tweak.has_options)
			{
				options = new Button.from_icon_name("gh-settings-cog-symbolic", IconSize.BUTTON);
				options.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
				options.tooltip_text = _("Options");
				options.sensitive = false;
				options.valign = Align.CENTER;
				options.clicked.connect(() => {
					if(options_popover == null)
					{
						options_popover = new TweakOptionsPopover(tweak, tweakset);
						options_popover.relative_to = options;
						options_popover.position = PositionType.LEFT;
					}
					options_popover.popup();
				});
				buttons_hbox.add(options);
			}

			var enabled = new Switch();
			enabled.active = tweakset.is_enabled(tweak.id);
			enabled.valign = Align.CENTER;
			enabled.margin_start = 12;
			buttons_hbox.add(enabled);

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

				tweak_state = _("Unavailable");
				enabled.sensitive = false;
				enabled.active = false;
				activatable = false;
				title_label.sensitive = false;
				tooltip_markup = string.joinv("\n", reqs).strip();
				icon_image.opacity = 0.6;
				if(icon_name == "gh-settings-cogs-symbolic")
				{
					icon_name = "action-unavailable-symbolic";
				}
			}
			else
			{
				if(options != null)
				{
					options.sensitive = enabled.active;
				}

				tweak_state = enabled.active ? _("Enabled") : _("Disabled");

				if(!tweakset.is_global)
				{
					var local_options = tweakset.get_options_for_tweak(tweak);
					if(local_options == null || local_options.state == TweakOptions.State.GLOBAL)
					{
						enabled.opacity = 0.6;
						tweak_state = enabled.active ? _("Enabled globally") : _("Disabled globally");
						enabled.tooltip_text = tweak_state;
						if(options != null)
						{
							options.sensitive = false;
						}
					}
				}

				enabled.notify["active"].connect(() => {
					TweakOptions? local_options;

					if(!tweakset.is_global)
					{
						local_options = tweakset.get_options_for_tweak(tweak);
						if(local_options == null || local_options.state == TweakOptions.State.GLOBAL)
						{
							local_options = tweakset.get_options_or_copy_global(tweak);
							options_popover = null; // recreate options popover
						}
					}

					if(local_options == null)
					{
						local_options = tweakset.get_or_create_options(tweak);
					}

					local_options.state = enabled.active ? TweakOptions.State.ENABLED : TweakOptions.State.DISABLED;
					tweakset.set_options_for_tweak(tweak, local_options);

					tweak_state = enabled.active ? _("Enabled") : _("Disabled");
					enabled.opacity = 1;
					enabled.tooltip_text = null;
					if(options != null)
					{
						options.sensitive = enabled.active;
					}
				});
				setting_activated.connect(() => {
					enabled.activate();
				});
			}

			notify["tweak-state"].connect(() => {
				if(tweak_state != null)
				{
					description = "%s • %s".printf(tweak_state, tweak.description);
					Idle.add(() => {
						description_label.tooltip_text = tweak.description;
						return Source.REMOVE;
					});
				}
				else
				{
					description = tweak.description;
				}
			});
			notify_property("tweak-state");
		}
	}
}
