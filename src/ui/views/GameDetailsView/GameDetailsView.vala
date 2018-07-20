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
		private ulong _game_status_handler_id = 0;

		public Game? game
		{
			get { return _game; }
			set
			{
				if(_game != null && _game_status_handler_id > 0)
				{
					SignalHandler.disconnect(_game, _game_status_handler_id);
				}
				_game = value;
				update_game.begin();
			}
		}

		public GameDetailsView(Game? game=null)
		{
			Object(game: game);
		}

		private bool is_dialog = false;

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
		private ActionButton action_uninstall;

		private Granite.HeaderLabel description_header;
		private WebView description;

		private Box custom_info;

		private const string CSS_LIGHT = "background: rgb(245, 245, 245); color: black";
		private const string CSS_DARK = "background: rgb(59, 63, 69); color: white";

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
			content_scrolled.propagate_natural_width = true;
			content_scrolled.propagate_natural_height = true;

			content = new Box(Orientation.VERTICAL, 0);
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
			src_icon.icon_size = IconSize.DIALOG;
			src_icon.opacity = 0.1;

			var title_vbox = new Box(Orientation.VERTICAL, 0);

			title_vbox.add(title);
			title_vbox.add(status);
			title_vbox.add(download_progress);

			title_hbox.add(icon);
			title_hbox.add(title_vbox);
			title_hbox.add(src_icon);

			description_header = new Granite.HeaderLabel(_("Description"));
			description_header.xpad = 8;

			description = new WebView();
			description.hexpand = true;
			description.vexpand = false; //(!is_dialog);
			description.get_settings().hardware_acceleration_policy = HardwareAccelerationPolicy.NEVER;

			custom_info = new Box(Orientation.VERTICAL, 0);
			custom_info.hexpand = false;
			custom_info.margin_start = custom_info.margin_end = 8;

			var ui_settings = GameHub.Settings.UI.get_instance();
			ui_settings.notify["dark-theme"].connect(() => {
				description.user_content_manager.remove_all_style_sheets();
				var style = ui_settings.dark_theme ? CSS_DARK : CSS_LIGHT;
				description.user_content_manager.add_style_sheet(new UserStyleSheet(@"body{overflow: hidden; font-size: 0.8em; line-height: 1.4; $(style)} h1,h2,h3{line-height: 1.2;} ul{padding: 4px 0 4px 16px;}", UserContentInjectedFrames.TOP_FRAME, UserStyleLevel.USER, null, null));
			});
			ui_settings.notify_property("dark-theme");

			actions = new Box(Orientation.HORIZONTAL, 0);
			actions.margin_top = actions.margin_bottom = 16;

			content.add(title_hbox);
			content.add(actions);
			content.add(custom_info);
			content.add(description_header);
			content.add(description);

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
		}

		private async void update_game()
		{
			is_dialog = !(get_toplevel() is GameHub.UI.Windows.MainWindow);

			content_scrolled.max_content_height = is_dialog ? 640 : -1;

			stack.set_visible_child(spinner);

			if(_game == null) return;

			yield _game.update_game_info();

			title.label = _game.name;
			src_icon.icon_name = _game.source.icon + "-symbolic";
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

			_game_status_handler_id = _game.status_change.connect(s => {
				status.label = s.description;
				download_progress.hide();
				if(s.state == Game.State.DOWNLOADING)
				{
					download_progress.show();
					download_progress.fraction = (double) s.dl_bytes / s.dl_bytes_total;
				}
				action_install.visible = s.state != Game.State.INSTALLED;
				action_install.sensitive = s.state == Game.State.UNINSTALLED;
				action_run.visible = s.state == Game.State.INSTALLED;
				action_open_directory.visible = s.state == Game.State.INSTALLED;
				action_open_store_page.visible = _game.store_page != null;
				action_uninstall.visible = s.state == Game.State.INSTALLED;
			});
			_game.status_change(_game.status);

			custom_info.forall(w => custom_info.remove(w));
			if(_game is GameHub.Data.Sources.GOG.GOGGame)
			{
				var root = Parser.parse_json(_game.custom_info).get_object();

				var sys_langs = Intl.get_language_names();
				var langs = root.get_object_member("languages");
				if(langs != null)
				{
					var langs_string = "";
					foreach(var l in langs.get_members())
					{
						var lang = langs.get_string_member(l);
						if(l in sys_langs) lang = @"<b>$(lang)</b>";
						langs_string += (langs_string.length > 0 ? ", " : "") + lang;
					}
					var langs_label = _("Language");
					if(langs_string.contains(","))
					{
						langs_label = _("Languages");
					}
					add_custom_info_label(langs_label, langs_string, false, true);
				}

				custom_info.show_all();
			}
			custom_info.margin_bottom = custom_info.get_children().length() > 0 ? 16 : 0;

			yield Utils.load_image(icon, _game.icon, "icon");

			stack.set_visible_child(content_scrolled);
		}

		private void install_game()
		{
			if(_game != null && _game.status.state == Game.State.UNINSTALLED)
			{
				_game.install.begin();
			}
		}

		private void open_game_directory()
		{
			if(_game != null && _game.status.state == Game.State.INSTALLED)
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
			if(_game != null && _game.status.state == Game.State.INSTALLED)
			{
				_game.run.begin();
			}
		}

		private void uninstall_game()
		{
			if(_game != null && _game.status.state == Game.State.INSTALLED)
			{
				_game.uninstall.begin();
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

		private void add_custom_info_label(string title, string? text, bool multiline=true, bool markup=false)
		{
			if(text == null || text == "") return;

			var title_label = new Granite.HeaderLabel(title);
			title_label.set_size_request(multiline ? -1 : 128, -1);
			title_label.valign = Align.START;

			var text_label = new Label(text);
			text_label.halign = Align.START;
			text_label.hexpand = false;
			text_label.wrap = true;
			text_label.xalign = 0;
			text_label.max_width_chars = is_dialog ? 80 : -1;
			text_label.use_markup = markup;

			if(!multiline)
			{
				text_label.get_style_context().add_class("gameinfo-singleline-value");
			}

			var box = new Box(multiline ? Orientation.VERTICAL : Orientation.HORIZONTAL, 0);
			box.add(title_label);
			box.add(text_label);
			custom_info.add(box);
		}
	}
}
