using Gtk;
using Gdk;
using Gee;
using Granite;
using GameHub.Data;
using GameHub.Utils;
using GameHub.UI.Widgets;
using WebKit;

namespace GameHub.UI.Views
{
	public class GameDetailsView: BaseView
	{
		private Game? _game;

		public Game? game
		{
			get { return _game; }
			set { _game = value; update_game.begin(); }
		}

		public GameDetailsView(Game? game=null)
		{
			Object(game: game);
		}

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

		private ActionButton action_install;
		private ActionButton action_run;
		private ActionButton action_open_directory;
		private ActionButton action_open_store_page;

		private WebView description;

		private const string CSS_LIGHT = "background: rgb(245, 245, 245); color: black";
		private const string CSS_DARK = "background: rgb(59, 63, 69); color: white";

		construct
		{
			stack = new Stack();
			stack.transition_type = StackTransitionType.CROSSFADE;
			stack.vexpand = true;

			spinner = new Spinner();
			spinner.active = true;
			spinner.set_size_request(36, 36);
			spinner.halign = Align.CENTER;
			spinner.valign = Align.CENTER;

			content_scrolled = new ScrolledWindow(null, null);
			content_scrolled.propagate_natural_width = true;
			content_scrolled.propagate_natural_height = true;

			content = new Box(Orientation.VERTICAL, 24);
			content.margin_start = content.margin_end = 8;

			var title_hbox = new Box(Orientation.HORIZONTAL, 16);
			title_hbox.margin_start = title_hbox.margin_end = 8;

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
			src_icon.opacity = 0.1;

			var title_vbox = new Box(Orientation.VERTICAL, 0);

			title_vbox.add(title);
			title_vbox.add(status);
			title_vbox.add(download_progress);

			title_hbox.add(icon);
			title_hbox.add(title_vbox);
			title_hbox.add(src_icon);

			description = new WebView();
			description.hexpand = true;
			description.vexpand = (get_toplevel() is GameHub.UI.Windows.MainWindow);

			var ui_settings = GameHub.Settings.UI.get_instance();
			ui_settings.notify["dark-theme"].connect(() => {
				description.user_content_manager.remove_all_style_sheets();
				var style = ui_settings.dark_theme ? CSS_DARK : CSS_LIGHT;
				description.user_content_manager.add_style_sheet(new UserStyleSheet(@"body{overflow: hidden; font-size: 0.8em; $(style)}", UserContentInjectedFrames.TOP_FRAME, UserStyleLevel.USER, null, null));
			});
			ui_settings.notify_property("dark-theme");

			actions = new Box(Orientation.VERTICAL, 0);

			content.add(title_hbox);
			content.add(actions);
			content.add(description);

			content_scrolled.add(content);

			stack.add(spinner);
			stack.add(content_scrolled);

			stack.set_visible_child(spinner);

			add(stack);

			action_install = add_action("go-down", _("Install"), install_game);
			action_run = add_action("media-playback-start", _("Run"), run_game);
			action_open_directory = add_action("folder", _("Open installation directory"), open_game_directory);
			action_open_store_page = add_action("internet-web-browser", _("Open store page"), open_game_store_page);
		}

		private async void update_game()
		{
			stack.set_visible_child(spinner);

			if(_game == null) return;

			yield _game.update_game_info();

			title.label = _game.name;
			src_icon.pixbuf = FSUtils.get_icon(_game.source.icon, 48);
			if(_game.description != null)
			{
				description.show();
				description.set_size_request(-1, -1);
				var desc = _game.description + "<script>setInterval(function(){document.title = -1; document.title = document.documentElement.clientHeight;},250);</script>";
				description.load_html(desc, null);
				description.notify["title"].connect(e => {
					description.set_size_request(-1, -1);
					var height = int.parse(description.title);
					description.set_size_request(-1, height);
				});
			}
			else
			{
				description.hide();
			}

			_game.status_change.connect(s => {
				status.label = s.description;
				download_progress.hide();
				if(s.state == DOWNLOADING)
				{
					download_progress.show();
					download_progress.fraction = (double) s.dl_bytes / s.dl_bytes_total;
				}
				action_install.visible = s.state == UNINSTALLED;
				action_run.visible = s.state == INSTALLED;
				action_open_directory.visible = s.state == INSTALLED;
				action_open_store_page.visible = _game.store_page != null;
			});
			_game.status_change(_game.status);

			yield Utils.load_image(icon, _game.icon, "icon");

			stack.set_visible_child(content_scrolled);
		}

		private void install_game()
		{
			if(_game != null && _game.status.state == UNINSTALLED)
			{
				_game.install.begin();
			}
		}

		private void open_game_directory()
		{
			if(_game != null && _game.status.state == INSTALLED)
			{
				Utils.open_uri(_game.install_dir.get_uri());
			}
		}

		private void open_game_store_page()
		{
			if(_game != null && _game.store_page != null)
			{
				Utils.open_uri(_game.store_page);
			}
		}

		private void run_game()
		{
			if(_game != null && _game.status.state == INSTALLED)
			{
				_game.run.begin();
			}
		}

		private delegate void Action();
		private ActionButton add_action(string icon, string title, Action action)
		{
			var button = new ActionButton(new Image.from_icon_name(icon, IconSize.DIALOG), title);
			actions.add(button);
			button.clicked.connect(() => action());
			return button;
		}
	}
}
