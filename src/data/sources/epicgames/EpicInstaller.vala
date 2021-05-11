using Gee;

using GameHub.Data.Runnables;
using GameHub.Data.Runnables.Tasks.Install;
using GameHub.Utils;

namespace GameHub.Data.Sources.EpicGames
{
	internal class Installer: Runnables.Tasks.Install.Installer
	{
		internal          Analysis? analysis         { get; set; default = null; }
		internal EpicGame game                       { get; private set; }
		internal          InstallTask? install_task  { get; default = null; }

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
				if(((EpicGame.DLC)game).game.install_dir == null) return false;

				_install_task.install_dir = ((EpicGame.DLC)game).game.install_dir;
			}

			debug("starting installation");
			var downloader = new EpicDownloader();

			try
			{
				var downloaded_chunks = yield downloader.download(this);

				//  download_task should be available here with all required information
				//  tasks should be in the correct order open -> write chunk -> close
				var full_path = install_task.install_dir;
				FileOutputStream? iostream = null;

				foreach(var file_task in analysis.tasks)
				{
					if(file_task is Analysis.FileTask)
					{
						//  make directories
						full_path = File.new_build_filename(install_task.install_dir.get_path(),
						                                    ((Analysis.FileTask)file_task).filename);
						FS.mkdir(full_path.get_parent().get_path());

						if(((Analysis.FileTask)file_task).empty)
						{
							full_path.create_readwrite(FileCreateFlags.REPLACE_DESTINATION);
							continue;
						}
						else if(((Analysis.FileTask)file_task).fopen)
						{
							if(iostream != null)
							{
								warning("[Sources.EpicGames.Installer.install] Opening new file %s without closing previous!",
								        full_path.get_path());
								iostream.close();
								iostream = null;
							}

							if(full_path.query_exists())
							{
								iostream = yield full_path.replace_async(null,
								                                         false,
								                                         FileCreateFlags.REPLACE_DESTINATION);
							}
							else
							{
								iostream = yield full_path.create_async(FileCreateFlags.NONE);
							}

							continue;
						}
						else if(((Analysis.FileTask)file_task).fclose)
						{
							if(iostream != null)
							{
								iostream.close();
								iostream = null;
							}
							else
							{
								warning("[Sources.EpicGames.Installer.install] Asking to close file that is not open: %s",
								        full_path.get_path());
							}

							//  write last completed file to simple resume file
							if(game.resume_file != null)
							{
								var path = full_path.get_path();

								if(path[path.length - 4:path.length] == ".tmp")
								{
									path = path[0 : path.length - 4];
								}

								var file_hash = yield Utils.compute_file_checksum(full_path, ChecksumType.SHA1);
								//  var tmp       = "";

								//  if(((Analysis.FileTask)file_task).filename[((Analysis.FileTask)file_task).filename.length - 4 : ((Analysis.FileTask)file_task).filename.length] == ".tmp")
								//  {
								//  	tmp = ((Analysis.FileTask)file_task).filename[0 : ((Analysis.FileTask)file_task).filename.length - 4];
								//  }
								//  else
								//  {
								//  	tmp = ((Analysis.FileTask)file_task).filename;
								//  }

								//  debug(tmp);
								//  assert(file_hash == bytes_to_hex(analysis.result.manifest.file_manifest_list.get_file_by_path(tmp).sha_hash));

								var output_stream = game.resume_file.append_to(FileCreateFlags.NONE);
								output_stream.write((string.join(":", file_hash, path) + "\n").data);

								output_stream.close();
							}

							continue;
						}
						else if(((Analysis.FileTask)file_task).frename)
						{
							if(iostream != null)
							{
								warning("[Sources.EpicGames.Installer.install] Trying to rename file without closing first!");
								iostream.close();
								iostream = null;
							}

							if(((Analysis.FileTask)file_task).del)
							{
								FS.rm(full_path.get_path());
							}

							File.new_build_filename(install_task.install_dir.get_path(),
							                        ((Analysis.FileTask)file_task).temporary_filename).move(full_path, FileCopyFlags.NONE);
							continue;
						}
						else if(((Analysis.FileTask)file_task).del)
						{
							if(iostream != null)
							{
								warning("[Sources.EpicGames.Installer.install] Trying to delete file without closing first!");
								iostream.close();
								iostream = null;
							}

							FS.rm(full_path.get_path());
							continue;
						}
					}

					assert(file_task is Analysis.ChunkTask);
					assert_nonnull(iostream);

					//  FIXME: this blocks the UI, do in an own thread/async
					var downloaded_chunk = FS.file(FS.Paths.EpicGames.Cache + "/chunks/" + game.id + "/" + ((Analysis.ChunkTask)file_task).chunk_guid.to_string());

					if(((Analysis.ChunkTask)file_task).chunk_file != null)
					{
						//  reuse chunk from existing file
						FileInputStream? old_stream = null;
						assert(File.new_build_filename(install_task.install_dir.get_path(),
						                               ((Analysis.ChunkTask)file_task).chunk_file).query_exists());
						old_stream = File.new_build_filename(install_task.install_dir.get_path(),
						                                     ((Analysis.ChunkTask)file_task).chunk_file).read();
						old_stream.seek(((Analysis.ChunkTask)file_task).chunk_offset, SeekType.SET);
						var bytes = yield old_stream.read_bytes_async(((Analysis.ChunkTask)file_task).chunk_size);
						yield iostream.write_bytes_async(bytes);
						old_stream.close();
						old_stream = null;
					}
					else if(downloaded_chunk.query_exists())
					{
						var chunk = new Chunk.from_byte_stream(new DataInputStream(yield downloaded_chunk.read_async()));
						//  debug(@"chunk data length $(chunk.data.length)");
						//  debug("chunk %s hash: %s",
						//        ((Analysis.ChunkTask)file_task).chunk_guid.to_string(),
						//        Checksum.compute_for_bytes(ChecksumType.SHA1, chunk.data));
						var size = yield iostream.write_bytes_async(chunk.data[((Analysis.ChunkTask)file_task).chunk_offset : ((Analysis.ChunkTask)file_task).chunk_offset + ((Analysis.ChunkTask)file_task).chunk_size]);
						//  debug(@"written $size bytes");
					}
					else
					{
						assert_not_reached();
					}
				}
			}
			catch (Error e)
			{
				debug("chunk building failed: %s", e.message);
				assert_not_reached();
			}

			//  TODO: clean cache path

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
	}
}
