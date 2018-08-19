using Gtk;
using Gdk;
using Gee;
using Granite;
using GameHub.Data;
using GameHub.Utils;
using GameHub.UI.Widgets;
using WebKit;

namespace GameHub.UI.Views.GameDetailsView
{
	public class GameDetailsPage: Grid
	{
		public Game game { get; construct; }

		public GameDetailsPage(Game game)
		{
			Object(game: game);
		}

		private bool is_dialog = false;
		private bool is_updated = false;

		private Stack stack;
		private Spinner spinner;

		private ScrolledWindow content_scrolled;
		public Box content;
		private Box actions;

		private Label title;
		private Label status;
		private ProgressBar download_progress;
		private AutoSizeImage icon;
		private Image src_icon;

		private Downloader.Download? download;

		private Button action_pause;
		private Button action_resume;
		private Button action_cancel;

		private ActionButton action_install;
		private ActionButton action_run;
		private ActionButton action_open_directory;
		private ActionButton action_open_store_page;
		private ActionButton action_uninstall;

		private Box blocks;

		construct
		{
			stack = new Stack();
			stack.transition_type = StackTransitionType.NONE;
			stack.vexpand = true;

			spinner = new Spinner();
			spinner.active = true;
			spinner.set_size_request(36, 36);
			spinner.halign = Align.CENTER;
			spinner.valign = Align.CENTER;

			content_scrolled = new ScrolledWindow(null, null);
			#if GTK_3_22
			content_scrolled.propagate_natural_width = true;
			content_scrolled.propagate_natural_height = true;
			#endif

			content = new Box(Orientation.VERTICAL, 0);
			content.margin_start = content.margin_end = 8;

			var title_hbox = new Box(Orientation.HORIZONTAL, 15);
			title_hbox.margin_start = title_hbox.margin_end = 7;

			icon = new AutoSizeImage();
			icon.set_constraint(48, 48, 1);
			icon.set_size_request(48, 48);

			title = new Label(null);
			title.halign = Align.START;
			title.hexpand = true;
			title.get_style_context().add_class(Granite.STYLE_CLASS_H2_LABEL);

			status = new Label(null);
			status.halign = Align.START;
			status.hexpand = true;

			download_progress = new ProgressBar();
			download_progress.hexpand = true;
			download_progress.fraction = 0d;
			download_progress.get_style_context().add_class(Gtk.STYLE_CLASS_OSD);
			download_progress.hide();

			src_icon = new Image();
			src_icon.icon_size = IconSize.DIALOG;
			src_icon.opacity = 0.1;

			var title_vbox = new Box(Orientation.VERTICAL, 0);
			var vbox_labels = new Box(Orientation.VERTICAL, 0);
			vbox_labels.hexpand = true;

			var hbox_inner = new Box(Orientation.HORIZONTAL, 8);
			var hbox_actions = new Box(Orientation.HORIZONTAL, 0);
			hbox_actions.vexpand = false;
			hbox_actions.valign = Align.CENTER;

			action_pause = new Button.from_icon_name("media-playback-pause-symbolic");
			action_pause.set_size_request(36, 36);
			action_pause.tooltip_text = _("Pause download");
			action_pause.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
			action_pause.visible = false;

			action_resume = new Button.from_icon_name("media-playback-start-symbolic");
			action_resume.set_size_request(36, 36);
			action_resume.tooltip_text = _("Resume download");
			action_resume.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
			action_resume.visible = false;

			action_cancel = new Button.from_icon_name("process-stop-symbolic");
			action_cancel.set_size_request(36, 36);
			action_cancel.tooltip_text = _("Cancel download");
			action_cancel.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
			action_cancel.visible = false;

			vbox_labels.add(title);
			vbox_labels.add(status);

			hbox_inner.add(vbox_labels);
			hbox_inner.add(hbox_actions);

			hbox_actions.add(action_pause);
			hbox_actions.add(action_resume);
			hbox_actions.add(action_cancel);

			title_vbox.add(hbox_inner);
			title_vbox.add(download_progress);

			title_hbox.add(icon);
			title_hbox.add(title_vbox);
			title_hbox.add(src_icon);

			blocks = new Box(Orientation.VERTICAL, 0);
			blocks.hexpand = false;

			actions = new Box(Orientation.HORIZONTAL, 0);
			actions.margin_top = actions.margin_bottom = 16;

			content.add(title_hbox);
			content.add(actions);
			content.add(blocks);

			content_scrolled.add(content);

			stack.add(spinner);
			stack.add(content_scrolled);

			stack.set_visible_child(spinner);

			add(stack);

			action_install = add_action("go-down", _("Install"), install_game, true);
			action_run = add_action("media-playback-start", _("Run"), run_game, true);
			action_open_directory = add_action("folder", _("Open installation directory"), open_game_directory);
			action_open_store_page = add_action("web-browser", _("Open store page"), open_game_store_page);
			action_uninstall = add_action("edit-delete", _("Uninstall"), uninstall_game);

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
		}

		public void update()
		{
			update_game.begin();
		}

		private async void update_game()
		{
			is_dialog = !(get_toplevel() is GameHub.UI.Windows.MainWindow);

			#if GTK_3_22
			content_scrolled.max_content_height = is_dialog ? 640 : -1;
			#endif

			if(is_updated) return;

			stack.set_visible_child(spinner);

			if(game == null) return;

			yield game.update_game_info();

			is_updated = true;

			title.label = game.name;
			src_icon.icon_name = game.source.icon + "-symbolic";

			blocks.foreach(b => blocks.remove(b));

			GameDetailsBlock[] blk = { new Blocks.GOGDetails(game), new Blocks.SteamDetails(game), new Blocks.Description(game) };
			foreach(var b in blk)
			{
				if(b.supports_game)
				{
					blocks.add(new Separator(Orientation.HORIZONTAL));
					blocks.add(b);
				}
			}
			blocks.show_all();

			game.status_change.connect(s => {
				status.label = s.description;
				download_progress.hide();
				if(s.state == Game.State.DOWNLOADING && s.download != null)
				{
					download = s.download;
					var ds = download.status.state;

					download_progress.show();
					download_progress.fraction = s.download.status.progress;

					action_cancel.visible = true;
					action_cancel.sensitive = ds == Downloader.DownloadState.DOWNLOADING || ds == Downloader.DownloadState.PAUSED;
					action_pause.visible = download is Downloader.PausableDownload && ds != Downloader.DownloadState.PAUSED;
					action_resume.visible = download is Downloader.PausableDownload && ds == Downloader.DownloadState.PAUSED;
				}
				else
				{
					action_cancel.visible = false;
					action_pause.visible = false;
					action_resume.visible = false;
				}
				action_install.visible = s.state != Game.State.INSTALLED;
				action_install.sensitive = s.state == Game.State.UNINSTALLED;
				action_run.visible = s.state == Game.State.INSTALLED;
				action_open_directory.visible = s.state == Game.State.INSTALLED;
				action_open_store_page.visible = game.store_page != null;
				action_uninstall.visible = s.state == Game.State.INSTALLED;
			});
			game.status_change(game.status);

			yield Utils.load_image(icon, game.icon, "icon");

			stack.set_visible_child(content_scrolled);
		}

		private void install_game()
		{
			if(_game != null && game.status.state == Game.State.UNINSTALLED)
			{
				game.install.begin();
			}
		}

		private void open_game_directory()
		{
			if(_game != null && game.status.state == Game.State.INSTALLED)
			{
				Utils.open_uri(game.install_dir.get_uri());
			}
		}

		private void open_game_store_page()
		{
			if(_game != null && game.store_page != null)
			{
				Utils.open_uri(game.store_page);
			}
		}

		private void run_game()
		{
			if(_game != null && game.status.state == Game.State.INSTALLED)
			{
				game.run.begin();
			}
		}

		private void uninstall_game()
		{
			if(_game != null && game.status.state == Game.State.INSTALLED)
			{
				game.uninstall.begin();
			}
		}

		private delegate void Action();
		private ActionButton add_action(string icon, string title, Action action, bool primary=false)
		{
			var button = new ActionButton(new Image.from_icon_name(icon, IconSize.DIALOG), title, primary);
			button.hexpand = primary;
			actions.add(button);
			button.clicked.connect(() => action());
			return button;
		}
	}
}
