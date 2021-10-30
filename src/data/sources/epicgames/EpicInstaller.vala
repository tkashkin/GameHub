using Gee;

using GameHub.Data.Runnables;
using GameHub.Data.Runnables.Tasks.Install;
using GameHub.Utils;

namespace GameHub.Data.Sources.EpicGames
{
	internal class Installer: Runnables.Tasks.Install.Installer
	{
		internal          Analysis? analysis         { get; default = null; }
		internal EpicGame game                       { get; private set; }
		internal          InstallTask? install_task  { get; default = null; }

		private ArrayList<ArrayList<Analysis.Task>> file_tasks { get; }

		internal Installer(EpicGame game, Platform platform)
		{
			_game         = game;
			this.platform = platform;
			id            = game.id;
			name          = game.name;
			full_size     = game.get_installation_size(platform);
			can_import    = true;

			if(platform != Platform.WINDOWS)
			{
				var list = EpicGames.instance.get_game_assets(true, uppercase_first_character(platform.id()));
				foreach(var asset in list)
				{
					if(asset.asset_id == id)
					{
						version = asset.build_version;
						break;
					}
				}
			}
			else
			{
				version = game.latest_version;
			}
		}

		internal override async bool install(InstallTask task)
		{
			_install_task = task;

			if(game is EpicGame.DLC)
			{
				if(((EpicGame.DLC) game).game.install_dir == null) return false;

				install_task.install_dir = ((EpicGame.DLC) game).game.install_dir;
			}

			debug("starting installation");

			debug("preparing download");
			_analysis   = game.prepare_download(install_task);
			_file_tasks = analysis.tasks;

			//  game is either up to date or hasn't changed, so we have nothing to do
			if(analysis.result.dl_size < 1)
			{
				debug("[Sources.EpicGames.EpicGame.download] Download size is 0, the game is either already up to date or has not changed.");

				if(game.needs_repair && game.repair_file.query_exists())
				{
					if(game.needs_verification) game.needs_verification = false;

					//  remove repair file
					Utils.FS.rm(game.repair_file.get_path());
				}

				//  check if install tags have changed, if they did; try deleting files that are no longer required.
				//  TODO: update install tags
			}
			else
			{
				if(!yield EpicDownloader.instance.download(this))
				{
					debug("downloading failed");
					task.status = new InstallTask.Status(InstallTask.State.NONE);
					game.status = new Game.Status(Game.State.UNINSTALLED, this.game);

					return false;
				}

				if(!file_tasks.is_empty)
				{
					if(!yield write_files(file_tasks))
					{
						debug("downloading failed");
						task.status = new InstallTask.Status(InstallTask.State.NONE);
						game.status = new Game.Status(Game.State.UNINSTALLED, this.game);

						return false;
					}
				}
			}

			update_game_info();

			task.status = new InstallTask.Status(InstallTask.State.NONE);
			game.status = new Game.Status(Game.State.INSTALLED, this.game);

			return true;
		}

		//  This should do three steps: Import -> verify -> repair/update
		internal override async bool import(InstallTask task)
		{
			_install_task = task;

			task.status = new InstallTask.Status(InstallTask.State.INSTALLING);
			game.status = new Game.Status(Game.State.INSTALLING, this.game);

			if(!yield game.import(task.install_dir))
			{
				debug("import failed");
				task.status = new InstallTask.Status(InstallTask.State.NONE);
				game.status = new Game.Status(Game.State.UNINSTALLED, this.game);

				return false;
			}

			game.executable_path = game.executable.get_path();
			task.status          = new InstallTask.Status(InstallTask.State.VERIFYING_INSTALLER_INTEGRITY);
			game.status          = new Game.Status(Game.State.VERIFYING_INSTALLER_INTEGRITY, this.game);

			if(game.needs_verification) yield game.verify();

			if(game.needs_repair) yield install(task);
			else update_game_info();

			task.status = new InstallTask.Status(InstallTask.State.NONE);
			game.status = new Game.Status(Game.State.INSTALLED, this.game);

			task.finish();

			return true;
		}

		private void update_game_info()
		{
			//  update the games saved version so future manifest querys fetch the correct manifest
			game.version = version;
			//  force update the cached manifest, the latest one should already be saved on disk here
			game.manifest = EpicGames.load_manifest(game.load_manifest_from_disk());

			game.update_metadata();
			game.install_dir     = install_task.install_dir;
			game.executable_path = FS.file(install_task.install_dir.get_path(), game.manifest.meta.launch_exe).get_path();
			game.save();
			game.update_status();
		}

		private async bool write_files(ArrayList<ArrayList<Analysis.Task>> tasks)
		{
			//  download_task should be available here with all required information
			//  tasks should be in the correct order: open -> write chunk -> close
			FileOutputStream? iostream = null;
			foreach(var task_list in tasks)
			{
				foreach(var task in task_list)
				{
					if(task is Analysis.FileTask)
					{
						return_val_if_fail(task.process(ref iostream, install_task.install_dir, game), false);
						continue;
					}

					//  We should only be here with a valid iostream
					return_val_if_fail(task is Analysis.ChunkTask, false);
					assert_nonnull(iostream);

					return_val_if_fail(task.process(ref iostream, install_task.install_dir, game), false);
				}
			}

			return true;
		}

		/** Write file if we have all required chunks */
		internal async bool write_file(uint32 guid_num)
		{
			var current_file_tasks = new ArrayList<ArrayList<Analysis.Task>>();

			//  Get all tasks with the current guid and process it if we also have all other chunks
			lock (file_tasks) {
				foreach(var task_list in file_tasks)
				{
					if(task_list.first_match(() =>
					{
						foreach(var task in task_list)
						{
							if(task is Analysis.ChunkTask
							   && ((Analysis.ChunkTask) task).chunk_guid == guid_num)
							{
								return true;
							}
						}
					}) == null)
					{
						//  This task set does not include this guid
						continue;
					}

					var list_complete = true;
					foreach(var task in task_list)
					{
						//  Check if other downloaded chunks are available
						if(task is Analysis.FileTask
						   || (task is Analysis.ChunkTask
						       && ((Analysis.ChunkTask) task).chunk_file != null))
						{
							continue;
						}

						if(!Utils.FS.file(Utils.FS.Paths.EpicGames.Cache + "/chunks/" + game.id + "/" + ((Analysis.ChunkTask) task).chunk_guid.to_string()).query_exists())
						{
							list_complete = false;
							break;
						}
					}

					if(list_complete)
					{
						//  FIXME: We may have lists here already which includes cleanup of our chunk
						//  while others still depend on it being available
						current_file_tasks.add(task_list);
					}
				}

				file_tasks.remove_all(current_file_tasks);
			}

			if(current_file_tasks.is_empty)
			{
				debug("Nothing to do yet…");

				return true;
			}

			return_val_if_fail(yield write_files(current_file_tasks), false);

			return true;
		}
	}
}
