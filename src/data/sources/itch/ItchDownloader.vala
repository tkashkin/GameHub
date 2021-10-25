/*
This file is part of GameHub.
Copyright (C) Anatoliy Kashkin

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

using GameHub.Data.DB;
using GameHub.Data.Runnables;
using GameHub.Utils;

using GameHub.Utils.Downloader;

namespace GameHub.Data.Sources.Itch
{
	public class ItchDownloader: GameHub.Utils.Downloader.Downloader
	{
		private static ItchDownloader? instance;

		private HashTable<string, ItchDownload> downloads;
		private HashTable<string, DownloadInfo> dl_info;

		public static ItchDownloader get_instance()
		{
			if(instance == null)
			{
				instance = new ItchDownloader();
			}
			return instance;
		}

		public ItchDownloader()
		{
			downloads = new HashTable<string, ItchDownload>(str_hash, str_equal);
			dl_info = new HashTable<string, DownloadInfo>(str_hash, str_equal);
			download_manager().add_downloader(this);
		}

		public override Download? get_download(string id)
		{
			lock(downloads)
			{
				return downloads.get(id);
			}
		}

		public ItchDownload? get_game_download(ItchGame? game)
		{
			if(game == null) return null;
			lock(downloads)
			{
				return (ItchDownload?) downloads.get(game.full_id);
			}
		}

		public async void download(ItchGame.Installer? installer, ButlerDaemon butler_daemon)
		{
			if(installer == null) return;
			var game = installer.game;

			var download = get_game_download(game);
			if(game == null || download != null) return;

			var connection = yield butler_daemon.create_connection();
			var install_id = Uuid.string_random();

			download = new ItchDownload(connection, install_id);

			lock(downloads) downloads.set(game.full_id, download);
			download_started(download);

			//download.status_change.connect(s => game.status_change(game.status));

			var info = new DownloadInfo(game.name, null, game.icon, null, null, game.source.icon);
			info.download = download;

			lock(dl_info) dl_info.set(game.full_id, info);
			dl_started(info);

			if(GameHub.Application.log_downloader)
			{
				debug("[ItchDownloader] Installing '%s'...", game.full_id);
			}

			game.status = new Game.Status(Game.State.DOWNLOADING, game, download);

			yield connection.install(game.int_id, installer.int_id, install_id);

			lock(downloads) downloads.remove(game.full_id);
			lock(dl_info) dl_info.remove(game.full_id);

			download_finished(download);
			dl_ended(info);

			game.update_status();
		}
	}

	/*
	TODO: Implement pause and resume
	*/
	public class ItchDownload: Download//, PausableDownload
	{
		private ButlerConnection butler_connection;
		private int64 bytes_total = -1;

		public ItchDownload(ButlerConnection butler_connection, string install_id)
		{
			base(install_id);
			this.butler_connection = butler_connection;

			status = new Status(Download.State.STARTING);

			butler_connection.notification.connect((s, method, @params) => {
				switch(method)
				{
					case "TaskStarted":
						bytes_total = params.get_int_member("totalSize");
						status = new Status(Download.State.STARTED);
						break;

					case "Progress":
						var progress = params.get_double_member("progress");
						var speed = params.get_double_member("bps");
						var eta = params.get_double_member("eta");
						status = new Status(Download.State.DOWNLOADING, bytes_total, progress, (int64) speed, (int64) eta);
						break;

					case "TaskSucceeded":
						status = new Status(Download.State.FINISHED);
						break;
				}
			});
		}

		/*
		TODO: Implement pause and resume
		public void pause(){}
		public void resume(){}
		*/

		public override void cancel()
		{
			butler_connection.cancel_install.begin(id, (obj, result) => {
				var cancelled = butler_connection.cancel_install.end(result);
				if(cancelled) {
					status = new Status(Download.State.CANCELLED);
				}
			});
		}

		public class Status: Download.Status
		{
			public int64 bytes_total = -1;
			public double dl_progress = -1;
			public int64 dl_speed = -1;
			public int64 eta = -1;

			public Status(Download.State state=Download.State.STARTING, int64 total=-1, double progress=-1, int64 speed=-1, int64 eta=-1)
			{
				base(state);
				this.bytes_total = total;
				this.dl_progress = progress;
				this.dl_speed = speed;
				this.eta = eta;
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
						result += C_("itch_dl_status", "%s left;").printf(Utils.seconds_to_string(eta));

					if(dl_progress >= 0)
						result += C_("itch_dl_status", "%d%%").printf((int) (dl_progress * 100));

					if(bytes_total >= 0)
						result += C_("itch_dl_status", "(%1$s / %2$s)").printf(format_size((int) (dl_progress * bytes_total)), format_size(bytes_total));

					if(dl_speed >= 0)
						result += C_("itch_dl_status", "[%s/s]").printf(format_size(dl_speed));

					return string.joinv(" ", result);
				}
			}
		}
	}
}
