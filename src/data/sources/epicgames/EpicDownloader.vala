using Gee;
using Soup;

using GameHub.Data.Runnables;
using GameHub.Utils;
using GameHub.Utils.Downloader;
using GameHub.Utils.Downloader.SoupDownloader;

namespace GameHub.Data.Sources.EpicGames
{
	//  FIXME: This whole thing is a mess because I had to come up with my own stuff here
	//  We need to download a number of x chunks per game and this should be properly represented in
	//  the download manager
	private class EpicDownloader: GameHub.Utils.Downloader.SoupDownloader.SoupDownloader
	{
		private ArrayQueue<string>              dl_queue;
		private HashTable<string, DownloadInfo> dl_info;
		private HashTable<string, EpicDownload> downloads;
		private Session                         session = new Session();

		private static string[] URL_SCHEMES        = { "http", "https" };
		private static string[] FILENAME_BLACKLIST = { "download" };

		internal EpicDownloader()
		{
			downloads                  = new HashTable<string, EpicDownload>(str_hash, str_equal);
			dl_info                    = new HashTable<string, DownloadInfo>(str_hash, str_equal);
			dl_queue                   = new ArrayQueue<string>();
			session.max_conns          = 32;
			session.max_conns_per_host = 16;
			session.user_agent         = "EpicGamesLauncher/11.0.1-14907503+++Portal+Release-Live Windows/10.0.19041.1.256.64bit";
			download_manager().add_downloader(this);
		}

		private EpicDownload? get_game_download(EpicGame? game)
		{
			if(game == null) return null;

			lock (downloads)
			{
				return (EpicDownload?) downloads.get(game.full_id);
			}
		}

		private async ArrayList<SoupDownload> fetch_parts(Installer installer)
		{
			var parts = new ArrayList<SoupDownload>();
			debug("preparing download");
			installer.analysis = installer.game.prepare_download(installer.task);

			//  game is either up to date or hasn't changed, so we have nothing to do
			if(installer.analysis.result.dl_size < 1)
			{
				debug("[Sources.EpicGames.EpicGame.download] Download size is 0, the game is either already up to date or has not changed.");

				if(installer.game.needs_repair && installer.game.repair_file.query_exists())
				{
					installer.game.needs_verification = false;
					//  remove repair file
					FS.rm(installer.game.repair_file.get_path());

					//  check if install tags have changed, if they did; try deleting files that are no longer required.
					//  TODO: update install tags
				}
			}

			//  debug("[Sources.EpicGames.EpicGame.download] Install size: %.02d MiB", installer.analysis.result.install_size / 1024 / 1024);
			//  debug("[Sources.EpicGames.EpicGame.download] Download size: %.02d MiB", installer.analysis.result.dl_size / 1024 / 1024);
			//  debug(@"[Sources.EpicGames.EpicGame.download] Reusable size: %.02d MiB (chunks) / $(installer.analysis.result.unchanged) (skipped)", installer.analysis.result.reuse_size / 1024 / 1024);

			foreach(var chunk_guid in installer.analysis.chunks_to_dl)
			{
				var chunk  = installer.analysis.chunk_data_list.get_chunk_by_number(chunk_guid);
				var remote = File.new_for_uri(installer.analysis.base_url + "/" + chunk.path);
				var local  = FS.file(FS.Paths.EpicGames.Cache + "/chunks/" + installer.game.id + "/" + chunk.guid_num.to_string());
				//  debug("local path: %s", local.get_path());
				FS.mkdir(local.get_parent().get_path());
				parts.add(new SoupDownload(remote, local, File.new_for_path(local.get_path() + "~")));
			}

			return parts;
		}

		//  TODO: a lot of small files, we should probably handle this in parallel
		internal new async ArrayList<File> download(Installer installer) throws Error
		{
			var files    = new ArrayList<File>();
			var game     = installer.game;
			var download = get_game_download(game);
			var parts    = yield fetch_parts(installer);

			//  installer.task.status = new InstallTask.Status(InstallTask.State.DOWNLOADING);
			if(game == null || download != null) return yield await_download(download);

			download = new EpicDownload(game.full_id, parts);

			lock (downloads) downloads.set(game.full_id, download);
			download_started(download);

			var info = new DownloadInfo.for_runnable(game, "Downloading…");
			info.download = download;

			lock (dl_info) dl_info.set(game.full_id, info);
			dl_started(info);

			if(GameHub.Application.log_downloader)
			{
				debug("[EpicDownloader] Installing '%s'...", game.full_id);
			}

			game.status = new Game.Status(Game.State.DOWNLOADING, game, download);

			debug("[DownloadableInstaller.download] Starting (%d parts)", parts.size);

			var ds_id = download_manager().file_download_started.connect(dl => {
				if(dl.id != game.full_id) return;

				installer.task.status = new Tasks.Install.InstallTask.Status(
					Tasks.Install.InstallTask.State.DOWNLOADING,
					dl);
				//  installer.download_state = new DownloadState(DownloadState.State.DOWNLOADING, dl);
				dl.status_change.connect(s => {
					installer.task.notify_property("status");
				});
			});

			try
			{
				uint32 current_part = 1;
				foreach(var part in ((EpicDownload) download).parts)
				{
					debug("[DownloadableInstaller.download] Part %u: `%s`", current_part, part.remote.get_uri());

					FS.mkdir(part.local.get_parent().get_path());

					var download_description = download.id;

					if(parts.size > 1)
					{
						download_description = _("Part %1$u of %2$u: %3$s").printf(current_part, parts.size, part.id);
						download.status      = new EpicDownload.Status(
							Download.State.DOWNLOADING,
							installer.full_size,
							//  FIXME: total size is wrong for partial updates
							(current_part * 1048576) / installer.full_size, // Chunks are mostly 1 MiB
							-1,
							-1);
					}

					debug("Downloading " + part.remote.get_uri());

					if(part.remote == null || part.remote.get_uri() == null || part.remote.get_uri().length == 0)
					{
						current_part++;
						continue;
					}

					var uri = part.remote.get_uri();

					if(part.local.query_exists())
					{
						//  TODO: compare hash
						if(GameHub.Application.log_downloader)
						{
							debug("[SoupDownloader] '%s' is already downloaded", uri);
						}

						files.add(part.local);
						current_part++;
						continue;
					}

					//  var tmp = File.new_for_path(part.local.get_path() + "~");

					if(part.remote.get_uri_scheme() in URL_SCHEMES)
						yield download_from_http(part, false, false);
					else
						yield download_from_filesystem(part);

					if(part.local_tmp.query_exists())
					{
						part.local_tmp.move(part.local, FileCopyFlags.OVERWRITE);
					}

					//  var file = yield download(part.remote, part.local, new Downloader.DownloadInfo.for_runnable(task.runnable, partDesc), false);
					if(part.local != null && part.local.query_exists())
					{
						files.add(part.local);
						//  TODO: uncompress, compare hash
						//  https://github.com/derrod/legendary/blob/a2280edea8f7f8da9a080fd3fb2bafcabf9ee33d/legendary/downloader/workers.py#L99
						//  var chunk = new Chunk.from_file(new DataInputStream(file.read()));

						//  string? file_checksum = null;
						//  if(part.checksum != null)
						//  {
						//  	task.status = new InstallTask.Status(InstallTask.State.VERIFYING_INSTALLER_INTEGRITY);
						//  	//  FileUtils.set_contents(file.get_path() + "." + part.checksum_type_string, part.checksum);
						//  	//  file_checksum = yield Utils.compute_file_checksum(file, part.checksum_type);
						//  	file_checksum = bytes_to_hex(chunk.sha_hash);
						//  }

						//  if(part.checksum == null || file_checksum == null || part.checksum == file_checksum)
						//  {
						//  	debug("[DownloadableInstaller.download] Downloaded `%s`; checksum: '%s' (matched)", file.get_path(), file_checksum != null ? file_checksum : "(null)");
						//  	files.add(file);
						//  }
						//  else
						//  {
						//  	Utils.notify(
						//  		_("%s: corrupted installer").printf(task.runnable.name),
						//  		_("Checksum mismatch in %s").printf(file.get_basename()),
						//  		NotificationPriority.HIGH,
						//  		n => {
						//  		var runnable_id = task.runnable.id;
						//  		n.set_icon(new ThemedIcon("dialog-warning"));
						//  		task.runnable.cast<Game>(
						//  			game => {
						//  			runnable_id = game.full_id;
						//  			var icon = ImageCache.local_file(game.icon, @"games/$(game.source.id)/$(game.id)/icons/");
						//  			if(icon != null && icon.query_exists())
						//  			{
						//  				n.set_icon(new FileIcon(icon));
						//  			}
						//  		});
						//  		var args = new Variant("(ss)", runnable_id, file.get_path());
						//  		n.set_default_action_and_target_value(Application.ACTION_PREFIX + Application.ACTION_CORRUPTED_INSTALLER_PICK_ACTION, args);
						//  		n.add_button_with_target_value(_("Show file"), Application.ACTION_PREFIX + Application.ACTION_CORRUPTED_INSTALLER_SHOW, args);
						//  		n.add_button_with_target_value(_("Remove"), Application.ACTION_PREFIX + Application.ACTION_CORRUPTED_INSTALLER_REMOVE, args);
						//  		n.add_button_with_target_value(_("Backup"), Application.ACTION_PREFIX + Application.ACTION_CORRUPTED_INSTALLER_BACKUP, args);
						//  		return n;
						//  	}
						//  	);

						//  	warning("Checksum mismatch in `%s`; expected: `%s`, actual: `%s`", file.get_basename(), part.checksum, file_checksum);
						//  }
					}

					current_part++;
				}

				//  if(installers_dir != null)
				//  {
				//  	FileUtils.set_contents(installers_dir.get_child(@".installer_$(id)").get_path(), "");
				//  }
			}
			catch (IOError.CANCELLED error)
			{
				download.status = new FileDownload.Status(Download.State.CANCELLED);
				download_cancelled(download, error);

				if(info != null) dl_ended(info);

				throw error;
			}
			catch (Error error)
			{
				download.status = new FileDownload.Status(Download.State.FAILED);
				download_failed(download, error);

				if(info != null) dl_ended(info);

				throw error;
			}
			finally
			{
				//  download_state = new DownloadState(DownloadState.State.DOWNLOADED);
				download.status = new FileDownload.Status(Download.State.FINISHED);
				lock (downloads) downloads.remove(game.full_id);
				lock (dl_info) dl_info.remove(game.full_id);
				//  lock (dl_queue) dl_queue.remove(game.full_id);
			}

			download_manager().disconnect(ds_id);

			download_finished(download);
			dl_ended(info);

			//  game.update_status();

			return files;
		}

		//  public async File? download_part(File remote, File local, DownloadInfo? info = null, bool preserve_filename = true, bool queue = true) throws Error
		//  {
		//  	if(remote == null || remote.get_uri() == null || remote.get_uri().length == 0) return null;

		//  	var uri = remote.get_uri();
		//  	var download = get_file_download(remote);

		//  	if(download != null) return yield await_download(download);

		//  	if(local.query_exists())
		//  	{
		//  		if(GameHub.Application.log_downloader)
		//  		{
		//  			debug("[SoupDownloader] '%s' is already downloaded", uri);
		//  		}
		//  		return local;
		//  	}

		//  	var tmp = File.new_for_path(local.get_path() + "~");

		//  	download = new SoupDownload(remote, local, tmp);
		//  	download.session = session;

		//  	lock (downloads)
		//  	{
		//  		downloads.set(uri, download);
		//  	}

		//  	download_started(download);

		//  	if(info != null)
		//  	{
		//  		info.download = download;

		//  		lock (dl_info)
		//  		{
		//  			dl_info.set(uri, info);
		//  		}

		//  		dl_started(info);
		//  	}

		//  	if(GameHub.Application.log_downloader)
		//  	{
		//  		debug("[SoupDownloader] Downloading '%s'...", uri);
		//  	}

		//  	download.status = new FileDownload.Status(Download.State.STARTING);

		//  	try{
		//  		if(remote.get_uri_scheme() in URL_SCHEMES)
		//  			yield download_from_http(download, preserve_filename, queue);
		//  		else
		//  			yield download_from_filesystem(download);
		//  	}
		//  	catch (IOError.CANCELLED error)
		//  	{
		//  		download.status = new FileDownload.Status(Download.State.CANCELLED);
		//  		download_cancelled(download, error);
		//  		if(info != null) dl_ended(info);
		//  		throw error;
		//  	}
		//  	catch (Error error)
		//  	{
		//  		download.status = new FileDownload.Status(Download.State.FAILED);
		//  		download_failed(download, error);
		//  		if(info != null) dl_ended(info);
		//  		throw error;
		//  	}
		//  	finally
		//  	{
		//  		lock (downloads) downloads.remove(uri);
		//  		lock (dl_info) dl_info.remove(uri);
		//  		lock (dl_queue) dl_queue.remove(uri);
		//  	}

		//  	if(download.local_tmp.query_exists())
		//  	{
		//  		download.local_tmp.move(download.local, FileCopyFlags.OVERWRITE);
		//  	}

		//  	if(GameHub.Application.log_downloader)
		//  	{
		//  		debug("[SoupDownloader] Downloaded '%s'", uri);
		//  	}

		//  	download_finished(download);
		//  	if(info != null) dl_ended(info);

		//  	return download.local;
		//  }

		private async ArrayList<File>? await_download(EpicDownload download) throws Error
		{
			ArrayList<File> files          = null;
			Error           download_error = null;

			SourceFunc callback = await_download.callback;
			var download_finished_id = download_finished.connect((downloader, downloaded) => {
				if(((SoupDownload) downloaded).id != download.id) return;

				files = new ArrayList<File>();
				((EpicDownload) downloaded).parts.foreach(part => {
					files.add(part.local_tmp); // FIXME: local_tmp?

					return true;
				});

				callback ();
			});
			var download_cancelled_id = download_cancelled.connect((downloader, cancelled_download, error) => {
				if(((SoupDownload) cancelled_download).id != download.id) return;

				download_error = error;
				callback ();
			});
			var download_failed_id = download_failed.connect((downloader, failed_download, error) => {
				if(((SoupDownload) failed_download).id != download.id) return;

				download_error = error;
				callback ();
			});

			yield;

			disconnect(download_finished_id);
			disconnect(download_cancelled_id);
			disconnect(download_failed_id);

			if(download_error != null) throw download_error;

			return files;
		}

		//  private async void await_queue(EpicDownload download)
		//  {
		//  	lock (dl_queue)
		//  	{
		//  		if(download.remote.get_uri() in dl_queue) return;
		//  		dl_queue.add(download.remote.get_uri());
		//  	}

		//  	var download_finished_id = download_finished.connect(
		//  		(downloader, downloaded) => {
		//  		lock (dl_queue) dl_queue.remove(((SoupDownload) downloaded).remote.get_uri());
		//  	});
		//  	var download_cancelled_id = download_cancelled.connect(
		//  		(downloader, cancelled_download, error) => {
		//  		lock (dl_queue) dl_queue.remove(((SoupDownload) cancelled_download).remote.get_uri());
		//  	});
		//  	var download_failed_id = download_failed.connect(
		//  		(downloader, failed_download, error) => {
		//  		lock (dl_queue) dl_queue.remove(((SoupDownload) failed_download).remote.get_uri());
		//  	});

		//  	while(dl_queue.peek() != null && dl_queue.peek() != download.remote.get_uri() && !download.is_cancelled) {
		//  		download.status = new FileDownload.Status(Download.State.QUEUED);
		//  		yield Utils.sleep_async(2000);
		//  	}

		//  	disconnect(download_finished_id);
		//  	disconnect(download_cancelled_id);
		//  	disconnect(download_failed_id);
		//  }

		private async void download_from_http(SoupDownload download,
		                                      bool         preserve_filename = true,
		                                      bool         queue             = true) throws Error
		{
			var msg = new Message("GET", download.remote.get_uri());
			msg.response_body.set_accumulate(false);

			download.session = session;
			download.message = msg;

			//  if(queue)
			//  {
			//  	yield await_queue(download);
			//  	//  download.status = new FileDownload.Status(Download.State.STARTING);
			//  }

			if(download.is_cancelled)
			{
				throw new IOError.CANCELLED("Download cancelled by user");
			}

			#if !PKG_FLATPAK
			var address         = msg.get_address();
			var connectable     = new NetworkAddress(address.name, (uint16) address.port);
			var network_monitor = NetworkMonitor.get_default();

			if(!(yield network_monitor.can_reach_async(connectable)))
				throw new IOError.HOST_UNREACHABLE("Failed to reach host");
			#endif

			GLib.Error? err = null;

			FileOutputStream? local_stream = null;

			int64 dl_bytes       = 0;
			int64 dl_bytes_total = 0;

			//  #if SOUP_2_60
			//  int64 resume_from = 0;
			//  var resume_dl = false;

			//  if(download.local_tmp.get_basename().has_suffix("~") && download.local_tmp.query_exists())
			//  {
			//  	var info = yield download.local_tmp.query_info_async(FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE);
			//  	resume_from = info.get_size();
			//  	if(resume_from > 0)
			//  	{
			//  		resume_dl = true;
			//  		msg.request_headers.set_range(resume_from, -1);
			//  		if(GameHub.Application.log_downloader)
			//  		{
			//  			debug(@"[SoupDownloader] Download part found, size: $(resume_from)");
			//  		}
			//  	}
			//  }
			//  #endif

			msg.got_headers.connect(() => {
				dl_bytes_total = msg.response_headers.get_content_length();

				if(GameHub.Application.log_downloader)
				{
					debug(@"[SoupDownloader] Content-Length: $(dl_bytes_total)");
				}

				try
				{
					if(preserve_filename)
					{
						string filename                   = null;
						string disposition                = null;
						HashTable<string, string> dparams = null;

						if(msg.response_headers.get_content_disposition(out disposition, out dparams))
						{
							if(disposition == "attachment" && dparams != null)
							{
								filename = dparams.get("filename");

								if(filename != null && GameHub.Application.log_downloader)
								{
									debug(@"[SoupDownloader] Content-Disposition: filename=%s", filename);
								}
							}
						}

						if(filename == null)
						{
							filename = download.remote.get_basename();
						}

						if(filename != null && !(filename in FILENAME_BLACKLIST))
						{
							download.local = download.local.get_parent().get_child(filename);
						}
					}

					if(download.local.query_exists())
					{
						if(GameHub.Application.log_downloader)
						{
							debug(@"[SoupDownloader] '%s' exists",
							      download.local.get_path());
						}

						var info = download.local.query_info(FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE);

						if(info.get_size() == dl_bytes_total)
						{
							session.cancel_message(msg, Status.OK);

							return;
						}
					}

					if(GameHub.Application.log_downloader)
					{
						debug(@"[SoupDownloader] Downloading to '%s'", download.local.get_path());
					}

					//  #if SOUP_2_60
					//  int64 rstart = -1, rend = -1;
					//  if(resume_dl && msg.response_headers.get_content_range(out rstart, out rend, out dl_bytes_total))
					//  {
					//  	if(GameHub.Application.log_downloader)
					//  	{
					//  		debug(@"[SoupDownloader] Content-Range is supported($(rstart)-$(rend)), resuming from $(resume_from)");
					//  		debug(@"[SoupDownloader] Content-Length: $(dl_bytes_total)");
					//  	}
					//  	dl_bytes = resume_from;
					//  	local_stream = download.local_tmp.append_to(FileCreateFlags.NONE);
					//  }
					//  else
					//  #endif
					{
						local_stream = download.local_tmp.replace(null, false, FileCreateFlags.REPLACE_DESTINATION);
					}
				}
				catch (Error e)
				{
					warning(e.message);
				}
			});

			int64 last_update               = 0;
			int64 dl_bytes_from_last_update = 0;

			msg.got_chunk.connect((msg, chunk) => {
				if(session.would_redirect(msg) || local_stream == null) return;

				dl_bytes                  += chunk.length;
				dl_bytes_from_last_update += chunk.length;
				try
				{
					local_stream.write(chunk.data);
					chunk.free();

					int64 now  = get_real_time();
					int64 diff = now - last_update;

					if(diff > 1000000)
					{
						int64 dl_speed  = (int64) (((double) dl_bytes_from_last_update) / ((double) diff) * ((double) 1000000));
						download.status = new FileDownload.Status(Download.State.DOWNLOADING,
						                                          dl_bytes,
						                                          dl_bytes_total,
						                                          dl_speed);
						last_update               = now;
						dl_bytes_from_last_update = 0;
					}
				}
				catch (Error e)
				{
					err = e;
					session.cancel_message(msg, Status.CANCELLED);
				}
			});

			session.queue_message(msg,
			                      (session, msg) => {
				download_from_http.callback ();
			});

			yield;

			if(local_stream == null) return;

			yield local_stream.close_async(Priority.DEFAULT);

			msg.request_body.free();
			msg.response_body.free();

			if(msg.status_code != Status.OK && msg.status_code != Status.PARTIAL_CONTENT)
			{
				if(msg.status_code == Status.CANCELLED)
				{
					throw new IOError.CANCELLED("Download cancelled by user");
				}

				if(err == null)
					err = new GLib.Error(http_error_quark(), (int) msg.status_code, msg.reason_phrase);

				throw err;
			}
		}

		private async void download_from_filesystem(SoupDownload download) throws GLib.Error
		{
			if(download.remote == null || !download.remote.query_exists()) return;

			try
			{
				if(GameHub.Application.log_downloader)
				{
					debug("[SoupDownloader] Copying '%s' to '%s'",
					      download.remote.get_path(),
					      download.local_tmp.get_path());
				}

				yield download.remote.copy_async(download.local_tmp,
				                                 FileCopyFlags.OVERWRITE,
				                                 Priority.DEFAULT,
				                                 null,
				                                 (current, total) => { download.status = new FileDownload.Status(Download.State.DOWNLOADING, current, total); });
			}
			catch (IOError.EXISTS error) {}
		}
	}

	public class EpicDownload: Download, PausableDownload
	{
		public weak                    Session? session;
		public weak                    Message? message;
		public bool                    is_cancelled = false;
		public ArrayList<SoupDownload> parts { get; }

		public EpicDownload(string id, ArrayList<SoupDownload> parts)
		{
			base(id);
			_parts = parts;
		}

		public void pause()
		{
			if(session != null && message != null && _status.state == Download.State.DOWNLOADING)
			{
				session.pause_message(message);
				_status.state = Download.State.PAUSED;
				status_change(_status);
			}
		}

		public void resume()
		{
			if(session != null && message != null && _status.state == Download.State.PAUSED)
			{
				session.unpause_message(message);
			}
		}

		public override void cancel()
		{
			is_cancelled = true;

			if(session != null && message != null)
			{
				session.cancel_message(message, Soup.Status.CANCELLED);
			}
		}

		public class Status: Download.Status
		{
			public int64  bytes_total = -1;
			public double dl_progress = -1;
			public int64  dl_speed    = -1;
			public int64  eta         = -1;

			public Status(Download.State                           state    = Download.State.STARTING,
			              int64                                    total    = -1,
			              double                                   progress = -1,
			              int64                                    speed    = -1,
			              int64                                    eta      = -1)
			{
				base(state);
				this.bytes_total = total;
				this.dl_progress = progress;
				this.dl_speed    = speed;
				this.eta         = eta;
			}

			public override double progress
			{
				get { return (double) dl_progress; }
			}

			public override string? progress_string
			{
				owned get
				{
					string[] result = {};

					if(eta >= 0)
						result += C_("epic_dl_status", "%s left;").printf(GameHub.Utils.seconds_to_string(eta));

					if(dl_progress >= 0)
						result += C_("epic_dl_status", "%d%%").printf((int) (dl_progress * 100));

					if(bytes_total >= 0)
						result += C_("epic_dl_status", "(%1$s / %2$s)").printf(format_size((int) (dl_progress * bytes_total)),
						                                                       format_size(bytes_total));

					if(dl_speed >= 0)
						result += C_("epic_dl_status", "[%s/s]").printf(format_size(dl_speed));

					return string.joinv(" ", result);
				}
			}
		}
	}
}
