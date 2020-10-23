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
using GameHub.UI.Widgets.Settings;

namespace GameHub.UI.Dialogs.InstallDialog.Steps
{
	public class InstallerStep: InstallDialogStep
	{
		private SettingsGroup sgrp_installers;

		public InstallerStep(InstallTask task)
		{
			Object(task: task, title: _("Select installer"));
		}

		construct
		{
			var scroll = new ScrolledWindow(null, null);
			scroll.hscrollbar_policy = PolicyType.NEVER;

			#if GTK_3_22
			scroll.propagate_natural_height = true;
			scroll.max_content_height = 600;
			#endif

			sgrp_installers = new SettingsGroup();
			sgrp_installers.settings.selection_mode = SelectionMode.SINGLE;
			sgrp_installers.settings.expand = true;

			sgrp_installers.settings.row_selected.connect(row => {
				if(row != null)
				{
					task.selected_installer = ((InstallerRow) row).installer;
				}
			});

			sgrp_installers.settings.row_activated.connect(row => {
				if(row != null)
				{
					task.selected_installer = ((InstallerRow) row).installer;
					Idle.add(() => {
						task.step_next();
						return Source.REMOVE;
					});
				}
			});

			if(task.can_import_install_dir)
			{
				var scroll_vbox = new Box(Orientation.VERTICAL, 0);
				scroll_vbox.add(sgrp_installers);
				add_install_dir_import_button(scroll_vbox);
				scroll.add(scroll_vbox);
			}
			else
			{
				scroll.add(sgrp_installers);
			}

			add(scroll);
			show_all();
			update();
		}

		public override void update()
		{
			sgrp_installers.settings.foreach(r => r.destroy());
			foreach(var installer in task.installers)
			{
				var row = new InstallerRow(task, installer);
				sgrp_installers.add_setting(row);
				if(installer == task.selected_installer)
				{
					sgrp_installers.settings.select_row(row);
				}
			}
			sgrp_installers.show_all();
		}

		public class InstallerRow: BaseSetting
		{
			public InstallTask task { get; construct; }
			public Installer installer { get; construct set; }

			private Grid grid;

			private Button? download_button { get { return widget as Button; } }

			public InstallerRow(InstallTask task, Installer installer)
			{
				Object(title: installer.name, widget: new Button.from_icon_name("folder-download-symbolic", IconSize.BUTTON), task: task, installer: installer);
			}

			construct
			{
				download_button.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
				download_button.valign = Align.CENTER;
				download_button.tooltip_text = _("Download");
				download_button.sensitive = false;

				download_button.clicked.connect(() => {
					installer.cast<DownloadableInstaller>(dl => {
						dl.download.begin(task);
						task.cancel();
					});
				});

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

				download_button.sensitive = false;

				installer.cast<DownloadableInstaller>(dl => {
					dl.update_download_state();
					if(dl.download_state != null && dl.download_state.state == DownloadableInstaller.DownloadState.State.DOWNLOADED)
					{
						detail_info_parts += _("Downloaded");
					}
					else
					{
						download_button.sensitive = true;
					}
				});

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

				icon_name = installer.platform.icon();
				title = """<b>%s</b><span alpha="75%"> • %s</span>""".printf(installer.name, string.joinv(" • ", info_parts));
				description = string.joinv(" • ", detail_info_parts);

				Idle.add(() => {
					description_label.tooltip_markup = string.joinv("\r\n", detail_info_parts);
					return Source.REMOVE;
				});

				icon_image.opacity = installer.is_installable ? 1 : 0.6;
				selectable = installer.is_installable;
				activatable = selectable;
				title_label.sensitive = selectable;
			}
		}
	}
}
