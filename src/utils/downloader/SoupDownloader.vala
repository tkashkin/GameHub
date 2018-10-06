/*
This file is part of GameHub.
Copyright (C) 2018 Anatoliy Kashkin

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

using GLib;
using Soup;

using GameHub.Utils.Downloader;

namespace GameHub.Utils.Downloader.Soup
{
	public class SoupDownloader: Downloader
	{
		private Session session;

		private HashTable<string, SoupDownload> downloads;
		private HashTable<string, DownloadInfo> dl_info;

		private static string[] supported_schemes = { "http", "https" };

		public SoupDownloader()
		{
			downloads = new HashTable<string, SoupDownload>(str_hash, str_equal);
			dl_info = new HashTable<string, DownloadInfo>(str_hash, str_equal);
			session = new Session();
			session.max_conns = 32;
			session.max_conns_per_host = 16;
		}

		public override Download? get_download(File remote)
		{
			return downloads.get(remote.get_uri());
		}

		public override async File download(File remote, File local, DownloadInfo? info=null, bool preserve_filename=true) throws Error
		{
			var uri = remote.get_uri();
			SoupDownload download = downloads.get(uri);

			if(download != null) return yield await_download(download);

			if(local.query_exists())
			{
				debug("[SoupDownloader] '%s' is already downloaded", uri);
				return local;
			}

			var tmp = File.new_for_path(local.get_path() + "~");

			download = new SoupDownload(remote, local, tmp);
			download.session = session;
			downloads.set(uri, download);

			download_started(download);

			if(info != null)
			{
				info.download = download;
				dl_info.set(uri, info);
				dl_started(info);
			}

			debug("[SoupDownloader] Downloading '%s'...", uri);

			try
			{
				if(remote.get_uri_scheme() in supported_schemes)
					yield download_from_http(download, preserve_filename);
				else
					yield download_from_filesystem(download);
			}
			catch(IOError.CANCELLED error)
			{
				download.status = new DownloadStatus(DownloadState.CANCELLED);
				if(info != null) dl_ended(info);
				throw error;
			}
			catch(Error error)
			{
				download.status = new DownloadStatus(DownloadState.FAILED);
				download_failed(download, error);
				if(info != null) dl_ended(info);
				throw error;
			}
			finally
			{
				downloads.remove(uri);
				dl_info.remove(uri);
			}

			if(download.local_tmp.query_exists())
			{
				download.local_tmp.move(download.local, FileCopyFlags.OVERWRITE);
			}

			debug("[SoupDownloader] Downloaded '%s'", uri);

			downloaded(download);
			if(info != null) dl_ended(info);

			return download.local;
		}

		private async void download_from_http(SoupDownload download, bool preserve_filename=true) throws Error
		{
			var msg = new Message("GET", download.remote.get_uri());
			msg.response_body.set_accumulate(false);

			download.session = session;
			download.message = msg;

			#if !FLATPAK
			var address = msg.get_address();
			var connectable = new NetworkAddress(address.name, (uint16) address.port);
			var network_monitor = NetworkMonitor.get_default();
			if(!(yield network_monitor.can_reach_async(connectable)))
				throw new IOError.HOST_UNREACHABLE("Failed to reach host");
			#endif

			GLib.Error? err = null;

			FileOutputStream? local_stream = null;

			int64 dl_bytes = 0;
			int64 dl_bytes_total = 0;

			int64 resume_from = 0;
			var resume_dl = false;

			if(download.local_tmp.get_basename().has_suffix("~") && download.local_tmp.query_exists())
			{
				var info = yield download.local_tmp.query_info_async(FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE);
				resume_from = info.get_size();
				if(resume_from > 0)
				{
					resume_dl = true;
					msg.request_headers.set_range(resume_from, -1);
					debug(@"[SoupDownloader] Download part found, size: $(resume_from)");
				}
			}

			msg.got_headers.connect(() => {
				dl_bytes_total = msg.response_headers.get_content_length();
				debug(@"[SoupDownloader] Content-Length: $(dl_bytes_total)");
				try
				{
					if(preserve_filename)
					{
						string filename = null;
						string disposition = null;
						HashTable<string, string> dparams = null;

						if(msg.response_headers.get_content_disposition(out disposition, out dparams))
						{
							if(disposition == "attachment" && dparams != null)
							{
								filename = dparams.get("filename");
								if(filename != null)
								{
									debug(@"[SoupDownloader] Content-Disposition: filename=%s", filename);
								}
							}
						}

						if(filename == null)
						{
							filename = download.remote.get_basename();
						}

						if(filename != null)
						{
							download.local = download.local.get_parent().get_child(filename);
							if(download.local.query_exists())
							{
								debug(@"[SoupDownloader] '%s' exists", download.local.get_path());
								var info = download.local.query_info(FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE);
								if(info.get_size() == dl_bytes_total)
								{
									session.cancel_message(msg, Status.OK);
									return;
								}
							}
							debug(@"[SoupDownloader] Downloading to '%s'", download.local.get_path());
						}
					}

					int64 rstart = -1, rend = -1;
					if(resume_dl && msg.response_headers.get_content_range(out rstart, out rend, out dl_bytes_total))
					{
						debug(@"[SoupDownloader] Content-Range is supported($(rstart)-$(rend)), resuming from $(resume_from)");
						debug(@"[SoupDownloader] Content-Length: $(dl_bytes_total)");
						dl_bytes = resume_from;
						local_stream = download.local_tmp.append_to(FileCreateFlags.NONE);
					}
					else
					{
						local_stream = download.local_tmp.replace(null, false, FileCreateFlags.REPLACE_DESTINATION);
					}
				}
				catch(Error e)
				{
					warning(e.message);
				}
			});

			msg.got_chunk.connect((msg, chunk) => {
				if(session.would_redirect(msg) || local_stream == null) return;

				dl_bytes += chunk.length;
				try
				{
					local_stream.write(chunk.data);
					download.status = new DownloadStatus(DownloadState.DOWNLOADING, dl_bytes, dl_bytes_total);
				}
				catch(Error e)
				{
					err = e;
					session.cancel_message(msg, Status.CANCELLED);
				}
			});

			session.queue_message(msg, (session, msg) => {
				download_from_http.callback();
			});

			yield;

			if(local_stream == null) return;

			yield local_stream.close_async(Priority.DEFAULT);

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

		private async File? await_download(SoupDownload download) throws Error
		{
			File downloaded_file = null;
			Error download_error = null;

			SourceFunc callback = await_download.callback;
			var downloaded_id = downloaded.connect((downloader, downloaded) => {
				if(downloaded.remote.get_uri() != download.remote.get_uri()) return;
				downloaded_file = downloaded.local_tmp;
				callback();
			});
			var downloaded_failed_id = download_failed.connect((downloader, failed_download, error) => {
				if(failed_download.remote.get_uri() != download.remote.get_uri()) return;
				download_error = error;
				callback();
			});

			yield;

			disconnect(downloaded_id);
			disconnect(downloaded_failed_id);

			if(download_error != null) throw download_error;

			return downloaded_file;
		}

		private async void download_from_filesystem(SoupDownload download) throws GLib.Error
		{
			try
			{
				debug("[SoupDownloader] Copying '%s' to '%s'", download.remote.get_path(), download.local_tmp.get_path());
				yield download.remote.copy_async(
					download.local_tmp,
					FileCopyFlags.OVERWRITE,
					Priority.DEFAULT,
					null,
					(current, total) => { download.status = new DownloadStatus(DownloadState.DOWNLOADING, current, total); });
			}
			catch(IOError.EXISTS error){}
		}
	}

	public class SoupDownload: PausableDownload
	{
		public Session? session;
		public Message? message;

		public SoupDownload(File remote, File local, File local_tmp)
		{
			base(remote, local, local_tmp);
		}

		public override void pause()
		{
			if(session != null && message != null && _status.state == DownloadState.DOWNLOADING)
			{
				session.pause_message(message);
				_status.state = DownloadState.PAUSED;
				status_change(_status);
			}
		}
		public override void resume()
		{
			if(session != null && message != null && _status.state == DownloadState.PAUSED)
			{
				session.unpause_message(message);
			}
		}
		public override void cancel()
		{
			if(session != null && message != null)
			{
				session.cancel_message(message, Status.CANCELLED);
			}
		}
	}
}
