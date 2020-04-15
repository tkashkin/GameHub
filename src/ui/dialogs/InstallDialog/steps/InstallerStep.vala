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

using Gee;

using GameHub.Data;
using GameHub.Data.Runnables;
using GameHub.Data.Runnables.Tasks.Install;

using GameHub.Utils;
using GameHub.UI.Widgets;

namespace GameHub.UI.Dialogs.InstallDialog.Steps
{
	public class InstallerStep: InstallDialogStep
	{
		private ListBox installers_list;

		public InstallerStep(InstallTask task)
		{
			Object(task: task, title: _("Select installer"));
		}

		construct
		{
			var scroll = new ScrolledWindow(null, null);
			scroll.get_style_context().add_class(Gtk.STYLE_CLASS_FRAME);
			scroll.hscrollbar_policy = PolicyType.NEVER;
			scroll.expand = true;
			scroll.margin = 8;

			#if GTK_3_22
			scroll.propagate_natural_height = true;
			scroll.max_content_height = 600;
			#endif

			installers_list = new ListBox();
			installers_list.selection_mode = SelectionMode.SINGLE;
			installers_list.get_style_context().add_class("separated-list-all");

			installers_list.row_selected.connect(row => {
				if(row != null)
				{
					task.selected_installer = ((InstallerRow) row).installer;
				}
			});

			installers_list.row_activated.connect(row => {
				if(row != null)
				{
					task.selected_installer = ((InstallerRow) row).installer;
					Idle.add(() => {
						task.step_next();
						return Source.REMOVE;
					});
				}
			});

			scroll.add(installers_list);
			add(scroll);

			show_all();

			update();
		}

		public override void update()
		{
			installers_list.foreach(r => r.destroy());
			foreach(var installer in task.installers)
			{
				var row = new InstallerRow(task, installer);
				installers_list.add(row);
				if(installer == task.selected_installer)
				{
					installers_list.select_row(row);
				}
			}
		}

		public class InstallerRow: ListBoxRow
		{
			public InstallTask task { get; construct; }
			public Installer installer { get; construct set; }

			private Grid grid;
			private Image icon;
			private Label name_label;
			private Label info_label;
			private Label detail_info_label;
			private Button download_button;

			public InstallerRow(InstallTask task, Installer installer)
			{
				Object(task: task, installer: installer);
			}

			construct
			{
				grid = new Grid();
				grid.column_spacing = 0;
				grid.margin_start = grid.margin_end = 8;
				grid.margin_top = grid.margin_bottom = 4;

				icon = new Image.from_icon_name(installer.platform.icon(), IconSize.LARGE_TOOLBAR);
				icon.valign = Align.CENTER;
				icon.margin_end = 12;

				name_label = new Label(null);
				name_label.get_style_context().add_class("bold");
				name_label.ellipsize = Pango.EllipsizeMode.END;
				name_label.xalign = 0;
				name_label.valign = Align.CENTER;

				info_label = new Label(null);
				info_label.get_style_context().add_class(Gtk.STYLE_CLASS_DIM_LABEL);
				info_label.use_markup = true;
				info_label.hexpand = true;
				info_label.ellipsize = Pango.EllipsizeMode.END;
				info_label.xalign = 0;
				info_label.valign = Align.CENTER;

				detail_info_label = new Label(null);
				detail_info_label.get_style_context().add_class(Gtk.STYLE_CLASS_DIM_LABEL);
				detail_info_label.use_markup = true;
				detail_info_label.hexpand = true;
				detail_info_label.ellipsize = Pango.EllipsizeMode.END;
				detail_info_label.xalign = 0;
				detail_info_label.valign = Align.CENTER;

				download_button = new Button.from_icon_name("folder-download-symbolic", IconSize.BUTTON);
				download_button.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
				download_button.valign = Align.CENTER;
				download_button.tooltip_text = _("Download");
				download_button.margin_start = 12;

				grid.attach(icon, 0, 0, 1, 2);
				grid.attach(name_label, 1, 0);
				grid.attach(info_label, 2, 0);
				grid.attach(detail_info_label, 1, 1, 2, 1);
				grid.attach(download_button, 3, 0, 1, 2);

				child = grid;

				notify["installer"].connect(() => update());
				update();
			}

			private void update()
			{
				string[] info_parts = {
					installer.platform.name(),
					format_size(installer.full_size)
				};

				string[] detail_info_parts = {};

				if(!installer.is_installable)
				{
					detail_info_parts += _("Cannot be installed");
				}

				if(installer.version != null)
				{
					detail_info_parts += _("Version: %s").printf(@"<b>$(installer.version)</b>");
				}

				if(installer.language_name != null || installer.language != null)
				{
					var lang = installer.language_name ?? installer.language;

					if(installer.language_name != null && installer.language != null)
					{
						lang = "%s (%s)".printf(installer.language_name, installer.language);
					}

					detail_info_parts += _("Language: %s").printf(@"<b>$(lang)</b>");
				}

				icon.icon_name = installer.platform.icon();
				name_label.label = installer.name;
				info_label.label = " • " + string.joinv(" • ", info_parts);
				detail_info_label.label = string.joinv(" • ", detail_info_parts);
				detail_info_label.tooltip_markup = string.joinv("\r\n", detail_info_parts);

				icon.opacity = installer.is_installable ? 1 : 0.6;
				selectable = installer.is_installable;
				activatable = selectable;
			}
		}
	}
}
