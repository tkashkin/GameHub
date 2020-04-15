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
	public class InstallDirStep: InstallDialogStep
	{
		private DirectoriesList install_dirs_list;
		private InstallerStep.InstallerRow selected_installer_row;

		public InstallDirStep(InstallTask task)
		{
			Object(task: task, title: _("Select installation directory"));
		}

		construct
		{
			var content = new Box(Orientation.VERTICAL, 0);
			content.expand = true;

			string? subdir_suffix = null;
			if(task.runnable != null)
			{
				subdir_suffix = task.runnable.name_escaped;
			}

			install_dirs_list = new DirectoriesList.with_files(task.install_dirs, task.install_dir, subdir_suffix);
			install_dirs_list.margin = 8;

			install_dirs_list.directory_selected.connect(dir => {
				task.install_dir = FS.file(install_dirs_list.selected_directory);
			});

			install_dirs_list.directory_activated.connect(dir => {
				Idle.add(() => {
					task.install_dir = FS.file(dir);
					task.step_next();
					return Source.REMOVE;
				});
			});

			content.add(install_dirs_list);

			add(content);

			var actionbar = new ActionBar();

			selected_installer_row = new InstallerStep.InstallerRow(task, task.selected_installer);
			selected_installer_row.margin_start = selected_installer_row.margin_end = 4;
			actionbar.add(selected_installer_row);

			add(actionbar);
		}

		public override void update()
		{
			if(task.install_dir != null)
			{
				install_dirs_list.selected_directory = task.install_dir.get_path();
			}
			selected_installer_row.installer = task.selected_installer;
		}
	}
}
