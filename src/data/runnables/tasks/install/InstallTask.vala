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

namespace GameHub.Data.Runnables.Tasks.Install
{
	public class InstallTask: Object
	{
		public Runnable? runnable { get; construct; }

		public ArrayList<Installer>? installers { get; set; default = null; }
		public Installer? selected_installer { get; set; default = null; }

		public ArrayList<File>? install_dirs { get; construct; default = null; }
		public File? install_dir { get; set; default = null; }

		public InstallTask.Mode install_mode { get; construct; default = InstallTask.Mode.INTERACTIVE; }
		public Status status { get; set; default = new Status(); }

		public ArrayList<CompatTool>? compat_tools { get; set; default = null; }
		public CompatTool? selected_compat_tool { get; set; default = null; }

		public InstallTask(Runnable? runnable, ArrayList<Installer>? installers, ArrayList<File>? install_dirs, InstallTask.Mode install_mode=InstallTask.Mode.INTERACTIVE)
		{
			Object(runnable: runnable, installers: installers, install_dirs: install_dirs, install_mode: install_mode);
		}

		private void init()
		{
			if(installers != null && installers.size > 0)
			{
				var sys_langs = new ArrayList<string>.wrap(Intl.get_language_names());

				installers.sort((first, second) => {
					if(first.platform == Platform.CURRENT && second.platform != Platform.CURRENT) return -1;
					if(first.platform != Platform.CURRENT && second.platform == Platform.CURRENT) return 1;

					if(first.is_installable && !second.is_installable) return -1;
					if(!first.is_installable && second.is_installable) return 1;

					if(first.language != null && second.language != null)
					{
						var first_lang_index = sys_langs.index_of(first.language);
						var second_lang_index = sys_langs.index_of(second.language);

						if(first_lang_index > -1 && second_lang_index > -1)
						{
							if(first_lang_index < second_lang_index) return -1;
							if(first_lang_index > second_lang_index) return 1;
						}

						if(first_lang_index > -1 && second_lang_index == -1) return -1;
						if(first_lang_index == -1 && second_lang_index > -1) return 1;

						if(first.name == second.name)
						{
							return first.language.collate(second.language);
						}
					}

					return first.name.collate(second.name);
				});
				selected_installer = installers.first();

				if(config_step == ConfigStep.LOADING)
				{
					step_next();
				}
			}

			if(install_dirs != null && install_dirs.size > 0)
			{
				install_dir = install_dirs.first();
			}

			var compat_runnable = runnable.cast<Traits.SupportsCompatTools>();
			if(compat_runnable != null)
			{
				compat_tools = compat_runnable.get_supported_compat_tools_for_installation(this);
				if(compat_tools.size > 0)
				{
					selected_compat_tool = compat_tools.first();
				}
			}
		}

		public async void load_installers()
		{
			if((installers != null && installers.size > 0) || runnable == null) return;
			var game = runnable.cast<Game>();
			if(game != null)
			{
				installers = yield game.load_installers();
				init();
			}
		}

		public async void start()
		{
			init();
			if(install_mode == InstallTask.Mode.INTERACTIVE)
			{
				yield show_install_dialog();
			}
			else
			{
				yield load_installers();
				yield install();
			}
		}

		public async void show_install_dialog()
		{
			var dlg = new GameHub.UI.Dialogs.InstallDialog.InstallDialog(this, show_install_dialog.callback);
			dlg.show();
			yield;
		}

		public async void install()
		{
			if(selected_installer == null)
			{
				warning("[InstallTask.install] No installer selected");
				return;
			}
			if(install_dir == null)
			{
				warning("[InstallTask.install] install_dir == null");
				return;
			}
			if(runnable != null)
			{
				runnable.install_dir = install_dir;
				runnable.save();
				runnable.update_status();
			}
			info("[InstallTask.install] Starting installation of %s; installer: '%s'; install_dir: `%s`", runnable != null ? runnable.full_id : "(null)", selected_installer.id, install_dir.get_path());
			yield selected_installer.install(this);
		}

		public void finish()
		{
			info("[InstallTask.finish] Finishing installation of %s", runnable != null ? runnable.full_id : "(null)");
			if(runnable != null)
			{
				var gh_marker = install_dir.get_child(".gamehub_" + runnable.id);
				if(gh_marker != null)
				{
					try
					{
						FileUtils.set_contents(gh_marker.get_path(), "");
					}
					catch(Error e){}
				}

				runnable.update_status();

				runnable.cast<Traits.HasExecutableFile>(r_exec => {
					r_exec.cast<Traits.HasActions>(r_act => {
						if((r_exec.executable == null || !r_exec.executable.query_exists()) && r_act.actions != null && r_act.actions.size > 0)
						{
							foreach(var action in r_act.actions)
							{
								if(action.is_primary)
								{
									if(action.file != null && action.file.query_exists())
									{
										r_exec.executable = action.file;
										r_exec.work_dir = action.workdir;
										r_exec.arguments = action.args;
										break;
									}
								}
							}
						}


					});
				});

				if(selected_installer.version != null)
				{
					runnable.cast<Game>(game => game.version = selected_installer.version);
				}
			}
		}

		private ArrayList<ConfigStep> config_prev_steps = new ArrayList<ConfigStep>();
		public ConfigStepChangeDirection config_step_last_change_direction { get; set; default = ConfigStepChangeDirection.NEXT; }

		public ConfigStep config_step
		{
			get
			{
				return config_prev_steps.size > 0 ? config_prev_steps.last() : ConfigStep.LOADING;
			}
			set
			{
				if(config_step == value) return;
				config_prev_steps.add(value);
				notify_property("config-next-step");
				notify_property("config-prev-step-available");
				notify_property("config-next-step-available");
			}
		}

		public ConfigStep config_next_step
		{
			get
			{
				switch(config_step)
				{
					case ConfigStep.LOADING:
						if(installers != null && installers.size > 0)
						{
							if(installers.size == 1)
							{
								return ConfigStep.INSTALL_DIR;
							}
							return ConfigStep.INSTALLER;
						}
						return ConfigStep.LOADING;

					case ConfigStep.INSTALLER:
						return ConfigStep.INSTALL_DIR;

					case ConfigStep.INSTALL_DIR:
						return requires_compat_tool ? ConfigStep.COMPAT_TOOL : ConfigStep.FINISH;

					case ConfigStep.COMPAT_TOOL:
						return ConfigStep.FINISH;
				}
				return ConfigStep.FINISH;
			}
		}

		public bool config_prev_step_available
		{
			get
			{
				var current_step = config_step;
				return config_prev_steps.size > 1 && current_step != ConfigStep.LOADING && current_step != ConfigStep.INSTALLER;
			}
		}

		public bool config_next_step_available
		{
			get
			{
				switch(config_next_step)
				{
					case ConfigStep.INSTALL_DIR:
						return selected_installer != null;

					case ConfigStep.COMPAT_TOOL:
						return install_dir != null;

					case ConfigStep.FINISH:
						return !requires_compat_tool || selected_compat_tool != null;
				}
				return false;
			}
		}

		public void step_prev()
		{
			if(config_prev_step_available)
			{
				config_step_last_change_direction = ConfigStepChangeDirection.PREVIOUS;
				config_prev_steps.remove_at(config_prev_steps.size - 1);
				notify_property("config-step");
				notify_property("config-next-step");
				notify_property("config-prev-step-available");
				notify_property("config-next-step-available");
			}
		}

		public void step_next()
		{
			config_step_last_change_direction = ConfigStepChangeDirection.NEXT;
			config_step = config_next_step;
		}

		private bool requires_compat_tool
		{
			get
			{
				return selected_installer != null && selected_installer.platform != Platform.CURRENT;
			}
		}

		public class Status: Object
		{
			public State state { get; construct; }
			public Downloader.Download? download { get; construct; }

			public Status(State state=State.NONE, Downloader.Download? download=null)
			{
				Object(state: state, download: download);
			}

			public string description
			{
				owned get
				{
					switch(state)
					{
						case State.INSTALLING: return C_("status", "Installing");
						case State.VERIFYING_INSTALLER_INTEGRITY: return C_("status", "Verifying installer integrity");
						case State.DOWNLOADING: return download != null && download.status != null && download.status.description != null ? download.status.description : C_("status", "Download started");
					}
					return C_("status", "Preparing installation");
				}
			}
		}

		public enum State
		{
			NONE, DOWNLOADING, VERIFYING_INSTALLER_INTEGRITY, INSTALLING;
		}

		public enum Mode
		{
			INTERACTIVE, AUTO_INSTALL, AUTO_DOWNLOAD;
		}

		public enum ConfigStep
		{
			LOADING, INSTALLER, INSTALL_DIR, COMPAT_TOOL, FINISH;
		}

		public enum ConfigStepChangeDirection
		{
			PREVIOUS, NEXT;
		}
	}
}
