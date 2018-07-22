using Gtk;
using Gdk;
using Granite;
using GameHub.Data;
using GameHub.Utils;
using GameHub.UI.Widgets;

namespace GameHub.UI.Views
{
	public class GameDownloadProgressView: ListBoxRow
	{
		public Game game;
		private Downloader.Download? download;
		
		private AutoSizeImage image;
		private ProgressBar progress_bar;
		
		private Button action_pause;
		private Button action_resume;
		private Button action_cancel;

		public GameDownloadProgressView(Game game)
		{
			this.game = game;
			
			selectable = false;
			
			var hbox = new Box(Orientation.HORIZONTAL, 16);
			hbox.margin = 8;
			var hbox_inner = new Box(Orientation.HORIZONTAL, 8);
			var hbox_actions = new Box(Orientation.HORIZONTAL, 0);
			hbox_actions.vexpand = false;
			hbox_actions.valign = Align.CENTER;

			var vbox = new Box(Orientation.VERTICAL, 0);
			var vbox_labels = new Box(Orientation.VERTICAL, 0);
			vbox_labels.hexpand = true;
			
			image = new AutoSizeImage();
			image.set_constraint(48, 48, 1);
			image.set_size_request(48, 48);
			
			hbox.add(image);
			
			var label = new Label(game.name);
			label.halign = Align.START;
			label.get_style_context().add_class("category-label");
			label.ypad = 2;

			var state_label = new Label(null);
			state_label.halign = Align.START;

			progress_bar = new ProgressBar();
			progress_bar.hexpand = true;
			progress_bar.fraction = 0d;
			progress_bar.get_style_context().add_class(Gtk.STYLE_CLASS_OSD);

			action_pause = new Button.from_icon_name("media-playback-pause-symbolic");
			action_pause.tooltip_text = _("Pause download");
			action_pause.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
			action_pause.visible = false;

			action_resume = new Button.from_icon_name("media-playback-start-symbolic");
			action_resume.tooltip_text = _("Resume download");
			action_resume.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
			action_resume.visible = false;
			
			action_cancel = new Button.from_icon_name("process-stop-symbolic");
			action_cancel.tooltip_text = _("Cancel download");
			action_cancel.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
			action_cancel.visible = false;

			vbox_labels.add(label);
			vbox_labels.add(state_label);

			hbox_inner.add(vbox_labels);
			hbox_inner.add(hbox_actions);

			hbox_actions.add(action_pause);
			hbox_actions.add(action_resume);
			hbox_actions.add(action_cancel);

			vbox.add(hbox_inner);
			vbox.add(progress_bar);
			
			hbox.add(vbox);
			
			child = hbox;
			
			game.status_change.connect(s => {
				state_label.label = s.description;
				if(s.state == Game.State.DOWNLOADING && s.download != null)
				{
					download = s.download;
					var ds = download.status.state;

					progress_bar.fraction = download.status.progress;

					action_cancel.visible = true;
					action_cancel.sensitive = ds == Downloader.DownloadState.DOWNLOADING || ds == Downloader.DownloadState.PAUSED;
					action_pause.visible = download is Downloader.PausableDownload && ds != Downloader.DownloadState.PAUSED;
					action_resume.visible = download is Downloader.PausableDownload && ds == Downloader.DownloadState.PAUSED;
				}
			});

			action_cancel.clicked.connect(() => {
				if(download != null) download.cancel();
			});

			action_pause.clicked.connect(() => {
				if(download != null && download is Downloader.PausableDownload)
				{
					((Downloader.PausableDownload) download).pause();
				}
			});

			action_resume.clicked.connect(() => {
				if(download != null && download is Downloader.PausableDownload)
				{
					((Downloader.PausableDownload) download).resume();
				}
			});

			Utils.load_image.begin(image, game.icon, "icon");

			show_all();
		}
	}
}
