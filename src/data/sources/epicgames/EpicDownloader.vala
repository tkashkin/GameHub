using Gee;
using Soup;

using GameHub.Data.Runnables;
//  using GameHub.Utils;
using GameHub.Utils.Downloader;
//  using GameHub.Utils.Downloader.SoupDownloader;

namespace GameHub.Data.Sources.EpicGames
{
	//  FIXME: This whole thing is a mess because I had to come up with my own stuff here
	//  We need to download a number of x chunks per game and this should be properly represented in
	//  the download manager
	private class EpicDownloader: Downloader
	{
		private ArrayQueue<string>              dl_queue;
		private HashTable<string, DownloadInfo> dl_info;
		private HashTable<string, EpicDownload> downloads;
		private Session                         session = new Session();

		internal static EpicDownloader instance;

		//  private static string[] URL_SCHEMES        = { "http", "https" };
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
			instance = this;
		}

		public override Download? get_download(string id)
		{
			lock (downloads)
			{
				return downloads.get(id);
			}
		}

		private EpicDownload? get_game_download(EpicGame game)
		{
			lock (downloads)
			{
				return (EpicDownload?) downloads.get(game.id);
			}
		}

		//  TODO: a lot of small files, we should probably handle this in parallel
		internal async bool download(Installer installer)
		{
			var files    = new ArrayList<File>();
			var game     = installer.game;
			var download = get_game_download(game);

			//  installer.task.status = new InstallTask.Status(InstallTask.State.DOWNLOADING);
			try
			{
				if(game == null || download != null) return yield await_download(download);
			}
			catch (Error e)
			{
				return false;
			}

			download    = new EpicDownload(game.id, installer.analysis);
			game.status = new Game.Status(Game.State.DOWNLOADING, game, download);

			lock (downloads) downloads.set(game.id, download);
			download_started(download);

			var info = new DownloadInfo.for_runnable(game, "Downloading…");
			info.download = download;

			lock (dl_info) dl_info.set(game.id, info);
			dl_started(info);

			if(GameHub.Application.log_downloader)
			{
				debug("[EpicDownloader] Installing '%s'...", game.id);
			}

			//  var ds_id = download_manager().file_download_started.connect(dl => {
			//  	if(dl.id != game.id) return;

			//  	installer.install_task.status = new Tasks.Install.InstallTask.Status(
			//  		Tasks.Install.InstallTask.State.DOWNLOADING,
			//  		dl);
			//  	//  installer.download_state = new DownloadState(DownloadState.State.DOWNLOADING, dl);
			//  	dl.status_change.connect(s => {
			//  		installer.install_task.notify_property("status");
			//  	});
			//  });

			try
			{
				yield await_queue(download);
				download.status = new EpicDownload.Status(Download.State.STARTING);
				debug("[DownloadableInstaller.download] Starting (%d parts)", download.parts.size);

				uint32 current_part = 1;
				var    total_parts  = download.parts.size;

				EpicPart part;
				download.session = session;

				while((part = download.parts.poll()) != null)
				{
					part.session = download.session;
					debug("[DownloadableInstaller.download] Part %u of %u: `%s`", current_part, total_parts, part.remote.get_uri());
					lock (dl_info) dl_info.set(game.id, new Utils.Downloader.DownloadInfo.for_runnable(installer.game, _("Downloading part %1$u of %2$u.").printf(current_part, total_parts)));

					download.status = new EpicDownload.Status(
						Download.State.DOWNLOADING,
						(int64) installer.analysis.result.dl_size,
						current_part / total_parts);

					Utils.FS.mkdir(part.local.get_parent().get_path());

					debug("Downloading " + part.remote.get_uri());

					if(part.remote == null || part.remote.get_uri() == null || part.remote.get_uri().length == 0)
					{
						current_part++;
						continue;
					}

					if(part.local.query_exists())
					{
						//  TODO: compare hash
						if(GameHub.Application.log_downloader)
						{
							debug("[SoupDownloader] '%s' is already downloaded", part.remote.get_uri());
						}

						files.add(part.local);
						download.downloaded_parts.offer(part);
						current_part++;
						continue;
					}

					if(download.is_cancelled)
					{
						throw new IOError.CANCELLED("Download cancelled by user");
					}

					yield download_from_http(part, false, false);

					if(part.local_tmp.query_exists())
					{
						part.local_tmp.move(part.local, FileCopyFlags.OVERWRITE);
					}

					//  var file = yield download(part.remote, part.local, new Downloader.DownloadInfo.for_runnable(task.runnable, partDesc), false);
					if(part.local != null && part.local.query_exists())
					{
						files.add(part.local);
						download.downloaded_parts.offer(part);
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
						//  			runnable_id = game.id;
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

				return false;
			}
			catch (Error error)
			{
				download.status = new FileDownload.Status(Download.State.FAILED);
				download_failed(download, error);

				if(info != null) dl_ended(info);

				return false;
			}
			finally
			{
				//  download_state = new DownloadState(DownloadState.State.DOWNLOADED);
				download.status = new FileDownload.Status(Download.State.FINISHED);
				lock (downloads) downloads.remove(game.id);
				lock (dl_info) dl_info.remove(game.id);
				//  lock (dl_queue) dl_queue.remove(game.id);
			}

			//  download_manager().disconnect(ds_id);

			download_finished(download);
			dl_ended(info);

			//  game.update_status();

			return true;
		}

		private async bool await_download(EpicDownload download) throws Error
		{
			Error download_error = null;

			SourceFunc callback = await_download.callback;
			var download_finished_id = download_finished.connect((downloader, downloaded) => {
				if(((EpicDownload) downloaded).id != download.id) return;

				callback ();
			});
			var download_cancelled_id = download_cancelled.connect((downloader, cancelled_download, error) => {
				if(((EpicDownload) cancelled_download).id != download.id) return;

				download_error = error;
				callback ();
			});
			var download_failed_id = download_failed.connect((downloader, failed_download, error) => {
				if(((EpicDownload) failed_download).id != download.id) return;

				download_error = error;
				callback ();
			});

			yield;

			disconnect(download_finished_id);
			disconnect(download_cancelled_id);
			disconnect(download_failed_id);

			if(download_error != null) throw download_error;

			return true;
		}

		private async void await_queue(EpicDownload download)
		{
			lock (dl_queue)
			{
				if(download.id in dl_queue) return;

				dl_queue.add(download.id);
			}

			var download_finished_id = download_finished.connect(
				(downloader, downloaded) => {
				lock (dl_queue) dl_queue.remove(((EpicDownload) downloaded).id);
			});
			var download_cancelled_id = download_cancelled.connect(
				(downloader, cancelled_download, error) => {
				lock (dl_queue) dl_queue.remove(((EpicDownload) cancelled_download).id);
			});
			var download_failed_id = download_failed.connect(
				(downloader, failed_download, error) => {
				lock (dl_queue) dl_queue.remove(((EpicDownload) failed_download).id);
			});

			while(dl_queue.peek() != null && dl_queue.peek() != download.id && !download.is_cancelled)
			{
				download.status = new FileDownload.Status(Download.State.QUEUED);
				yield Utils.sleep_async(2000);
			}

			disconnect(download_finished_id);
			disconnect(download_cancelled_id);
			disconnect(download_failed_id);
		}

		private async void download_from_http(EpicPart part,
		                                      bool     preserve_filename = true,
		                                      bool     queue             = true) throws Error
		{
			var msg = new Message("GET", part.remote.get_uri());
			msg.response_body.set_accumulate(false);

			//  download.session = session;
			//  download.message = msg;
			part.message = msg;

			//  if(queue)
			//  {
			//  	yield await_queue(download);
			//  	download.status = new EpicDownload.Status(Download.State.STARTING);
			//  }

			//  if(download.is_cancelled)
			//  {
			//  	throw new IOError.CANCELLED("Download cancelled by user");
			//  }

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

			#if SOUP_2_60
			int64 resume_from = 0;
			var   resume_dl   = false;

			if(part.local_tmp.get_basename().has_suffix("~") && part.local_tmp.query_exists())
			{
				var info = yield part.local_tmp.query_info_async(FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE);
				resume_from = info.get_size();

				if(resume_from > 0)
				{
					resume_dl = true;
					msg.request_headers.set_range(resume_from, -1);

					if(GameHub.Application.log_downloader)
					{
						debug(@"[SoupDownloader] Download part found, size: $(resume_from)");
					}
				}
			}
			#endif

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
							filename = part.remote.get_basename();
						}

						if(filename != null && !(filename in FILENAME_BLACKLIST))
						{
							part.local = part.local.get_parent().get_child(filename);
						}
					}

					if(part.local.query_exists())
					{
						if(GameHub.Application.log_downloader)
						{
							debug(@"[SoupDownloader] '%s' exists",
							      part.local.get_path());
						}

						var info = part.local.query_info(FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE);

						if(info.get_size() == dl_bytes_total)
						{
							session.cancel_message(msg, Status.OK);

							return;
						}
					}

					if(GameHub.Application.log_downloader)
					{
						debug(@"[SoupDownloader] Downloading to '%s'", part.local.get_path());
					}

					#if SOUP_2_60
					int64 rstart = -1, rend = -1;

					if(resume_dl && msg.response_headers.get_content_range(out rstart, out rend, out dl_bytes_total))
					{
						if(GameHub.Application.log_downloader)
						{
							debug(@"[SoupDownloader] Content-Range is supported($(rstart)-$(rend)), resuming from $(resume_from)");
							debug(@"[SoupDownloader] Content-Length: $(dl_bytes_total)");
						}

						dl_bytes     = resume_from;
						local_stream = part.local_tmp.append_to(FileCreateFlags.NONE);
					}
					else
					#endif
					{
						local_stream = part.local_tmp.replace(null, false, FileCreateFlags.REPLACE_DESTINATION);
					}
				}
				catch (Error e)
				{
					warning(e.message);
				}
			});

			//  int64 last_update               = 0;
			int64 dl_bytes_from_last_update = 0;

			msg.got_chunk.connect((msg, chunk) => {
				if(session.would_redirect(msg) || local_stream == null) return;

				dl_bytes                  += chunk.length;
				dl_bytes_from_last_update += chunk.length;
				try
				{
					local_stream.write(chunk.data);
					chunk.free();

					//  int64 now  = get_real_time();
					//  int64 diff = now - last_update;

					//  if(diff > 1000000)
					//  {
					//  	int64 dl_speed  = (int64) (((double) dl_bytes_from_last_update) / ((double) diff) * ((double) 1000000));
					//  	download.status = new FileDownload.Status(Download.State.DOWNLOADING,
					//  	                                          dl_bytes,
					//  	                                          dl_bytes_total,
					//  	                                          dl_speed);
					//  	last_update               = now;
					//  	dl_bytes_from_last_update = 0;
					//  }
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
	}

	private class EpicPart
	{
		public weak                             Session? session;
		public weak                             Message? message;
		public File                             remote;
		public File                             local;
		public File                             local_tmp;
		public Manifest.ChunkDataList.ChunkInfo chunk_info;

		public EpicPart(string id, Analysis analysis)
		{
			//  base(id, analysis);
		}

		public EpicPart.from_chunk_guid(string id, Analysis analysis, uint32 chunk_guid)
		{
			//  base(id, analysis);
			chunk_info = analysis.chunk_data_list.get_chunk_by_number(chunk_guid);
			remote     = File.new_for_uri(analysis.base_url + "/" + chunk_info.path);
			local      = Utils.FS.file(Utils.FS.Paths.EpicGames.Cache + "/chunks/" + id + "/" + chunk_info.guid_num.to_string());
			local_tmp  = File.new_for_path(local.get_path() + "~");
			Utils.FS.mkdir(local.get_parent().get_path());
		}
	}

	private class EpicDownload: Download, PausableDownload
	{
		public weak                 Session? session;
		public weak                 Message? message;
		public bool                 is_cancelled = false;
		public ArrayQueue<EpicPart> parts { get; default = new ArrayQueue<EpicPart>(); }
		public ArrayQueue<EpicPart> downloaded_parts { get; default = new ArrayQueue<EpicPart>(); }

		public EpicDownload(string id, Analysis analysis)
		{
			base(id);

			foreach(var chunk_guid in analysis.chunks_to_dl)
			{
				parts.offer(new EpicPart.from_chunk_guid(id, analysis, chunk_guid));
				//  debug("local path: %s", local.get_path());
			}
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
