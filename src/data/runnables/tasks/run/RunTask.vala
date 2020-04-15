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

using Gee;

using GameHub.Data;
using GameHub.Data.Runnables;
using GameHub.Utils;

namespace GameHub.Data.Runnables.Tasks.Run
{
	public class RunTask: Object
	{
		public Runnable runnable { get; construct; }
		public RunTask.Mode run_mode { get; construct; default = RunTask.Mode.AUTO; }

		public ArrayList<CompatTool>? compat_tools { get; set; default = null; }
		public CompatTool? selected_compat_tool { get; set; default = null; }

		private bool requires_compat = false;
		private bool is_compat_configured = false;

		public RunTask(Runnable runnable, RunTask.Mode run_mode=RunTask.Mode.AUTO)
		{
			Object(runnable: runnable, run_mode: run_mode);
		}

		construct
		{
			var compat_runnable = runnable.cast<Traits.SupportsCompatTools>();
			if(compat_runnable != null && compat_runnable.use_compat)
			{
				requires_compat = true;
				is_compat_configured = compat_runnable.compat_options_saved;
				compat_tools = compat_runnable.get_supported_compat_tools();
				if(compat_tools.size > 0)
				{
					selected_compat_tool = compat_tools.first();
				}
			}
		}

		public async void start()
		{
			if(requires_compat && (run_mode == RunTask.Mode.INTERACTIVE || !is_compat_configured))
			{
				yield compat_configure();
			}
			else
			{
				yield run();
			}
		}

		public async void compat_configure()
		{
			if(!requires_compat) return;
			/*var dlg = new GameHub.UI.Dialogs.CompatRunDialog(this, compat_configure.callback);
			dlg.show();
			yield;*/
		}

		public async void run()
		{
			if(!requires_compat)
			{
				yield runnable.run();
			}
			else if(selected_compat_tool != null)
			{
				yield selected_compat_tool.run(runnable.cast<Traits.SupportsCompatTools>());
			}
		}

		public enum Mode
		{
			INTERACTIVE, AUTO;
		}
	}
}
