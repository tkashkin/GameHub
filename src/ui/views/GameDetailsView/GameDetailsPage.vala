/*
This file is part of GameHub.
Copyright (C) 2018-2019 Anatoliy Kashkin

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

using Gtk;
using Gdk;
using Gee;

using GameHub.Data;
using GameHub.Utils;
using GameHub.UI.Widgets;
using GameHub.UI.Views.GamesView;

namespace GameHub.UI.Views.GameDetailsView
{
	public class GameDetailsPage: Gtk.Grid
	{
		public Game game { get; construct; }

		public GameDetailsView details_view { get; construct; }

		public GameDetailsPage(Game game, GameDetailsView parent)
		{
			Object(game: game, details_view: parent);
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
		private Image no_icon_indicator;
		private Image src_icon;

		private Box platform_icons;

		private Downloader.Download? download;

		private Button action_pause;
		private Button action_resume;
		private Button action_cancel;

		private ActionButton action_install;
		private ActionButton action_run;
		private ActionButton action_run_with_compat;
		private ActionButton action_properties;
		private ActionButton action_open_directory;
		private ActionButton action_open_installer_collection_directory;
		private ActionButton action_open_bonus_collection_directory;
		private ActionButton action_open_screenshots_directory;
		private ActionButton action_open_store_page;
		private ActionButton action_uninstall;

		private Box blocks;
		private Box sidebar;

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

			var title_hbox_eventbox = new EventBox();

			var title_overlay = new Overlay();
			title_overlay.margin_start = title_overlay.margin_end = 7;

			var title_icons = new Box(Orientation.HORIZONTAL, 15);
			title_icons.valign = Align.START;
			title_icons.halign = Align.END;

			var title_hbox = new Box(Orientation.HORIZONTAL, 15);

			var icon_overlay = new Overlay();
			icon_overlay.set_size_request(48, 48);
			icon_overlay.valign = Align.START;

			no_icon_indicator = new Image.from_icon_name("gamehub-symbolic", IconSize.DND);
			no_icon_indicator.get_style_context().add_class("no-icon-indicator");
			no_icon_indicator.halign = Align.CENTER;
			no_icon_indicator.valign = Align.CENTER;
			no_icon_indicator.opacity = 0.8;

			icon = new AutoSizeImage();
			icon.halign = Align.CENTER;
			icon.valign = Align.CENTER;
			icon.set_constraint(48, 48, 1);

			icon_overlay.add(no_icon_indicator);
			icon_overlay.add_overlay(icon);

			title = Styled.H2Label(null);
			title.halign = Align.START;
			title.wrap = true;
			title.xalign = 0;
			title.hexpand = true;

			status = new Label(null);
			status.halign = Align.START;
			status.hexpand = true;

			download_progress = new ProgressBar();
			download_progress.hexpand = true;
			download_progress.fraction = 0d;
			download_progress.hide();

			src_icon = new Image();
			src_icon.icon_size = IconSize.DIALOG;
			src_icon.opacity = 0.1;

			platform_icons = new Box(Orientation.HORIZONTAL, 15);

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

			title_hbox.add(icon_overlay);
			title_hbox.add(title_vbox);

			title_icons.add(platform_icons);
			title_icons.add(src_icon);

			title_overlay.add(title_hbox);
			title_overlay.add_overlay(title_icons);
			title_overlay.set_overlay_pass_through(title_icons, true);

			title_hbox_eventbox.add(title_overlay);

			content.add(title_hbox_eventbox);

			actions = new Box(Orientation.HORIZONTAL, 0);
			actions.margin_top = actions.margin_bottom = 16;

			content.add(actions);

			var blocks_hbox = new Box(Orientation.HORIZONTAL, 8);

			blocks = new Box(Orientation.VERTICAL, 0);
			blocks.hexpand = true;

			sidebar = new Box(Orientation.VERTICAL, 6);
			sidebar.hexpand = false;
			sidebar.halign = Align.END;

			blocks_hbox.add(blocks);
			blocks_hbox.add(sidebar);

			content.add(blocks_hbox);

			content_scrolled.add(content);

			stack.add(spinner);
			stack.add(content_scrolled);

			add(stack);

			stack.visible_child = spinner;

			action_install = add_action("go-down", null, _("Install"), install_game, true);
			action_run = add_action("media-playback-start", null, _("Run"), run_game, true);
			action_run_with_compat = add_action("media-playback-start", "platform-windows-symbolic", _("Run with compatibility layer"), run_game_with_compat, true);
			action_open_directory = add_action("folder", null, _("Open installation directory"), open_game_directory);
			action_open_installer_collection_directory = add_action("folder-download", null, _("Open installers collection directory"), open_installer_collection_directory);
			action_open_bonus_collection_directory = add_action("folder-documents", null, _("Open bonus collection directory"), open_bonus_collection_directory);
			action_open_screenshots_directory = add_action("folder-pictures", null, _("Open screenshots directory"), open_screenshots_directory);
			action_open_store_page = add_action("web-browser", null, _("Open store page"), open_game_store_page);
			action_uninstall = add_action("edit-delete", null, (game is Sources.User.UserGame) ? _("Remove") : _("Uninstall"), uninstall_game);
			action_properties = add_action("system-run", null, _("Game properties"), game_properties);

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

			title_hbox_eventbox.add_events(EventMask.BUTTON_RELEASE_MASK);
			title_hbox_eventbox.button_release_event.connect(e => {
				switch(e.button)
				{
					case 3:
						open_context_menu(e, true);
						break;
				}
				return true;
			});
		}

		private void set_visible_widgets(Game.Status s)
		{
			status.label = s.description;
			download_progress.hide();
			if(s.state == Game.State.DOWNLOADING && s.download != null && s.download.status != null)
			{
				download = s.download;
				var ds = download.status.state;

				download_progress.show();
				download_progress.fraction = download.status.progress;

				action_cancel.visible = true;
				action_cancel.sensitive = ds == Downloader.Download.State.DOWNLOADING || ds == Downloader.Download.State.QUEUED || ds == Downloader.Download.State.PAUSED;
				action_pause.visible = download is Downloader.PausableDownload && ds != Downloader.Download.State.PAUSED && ds != Downloader.Download.State.QUEUED;
				action_resume.visible = download is Downloader.PausableDownload && ds == Downloader.Download.State.PAUSED && ds != Downloader.Download.State.QUEUED;
			}
			else
			{
				action_cancel.visible = false;
				action_pause.visible = false;
				action_resume.visible = false;
			}
			action_install.visible = s.state != Game.State.INSTALLED;
			action_install.sensitive = s.state == Game.State.UNINSTALLED && game.is_installable;
			action_run_with_compat.visible = s.state == Game.State.INSTALLED && game.use_compat;
			action_run_with_compat.sensitive = game.can_be_launched();
			action_run.visible = s.state == Game.State.INSTALLED && !action_run_with_compat.visible;
			action_run.sensitive = game.can_be_launched();
			action_open_directory.visible = s.state == Game.State.INSTALLED && game.install_dir != null && game.install_dir.query_exists();
			action_open_installer_collection_directory.visible = game.installers_dir != null && game.installers_dir.query_exists();
			action_open_bonus_collection_directory.visible = game is GameHub.Data.Sources.GOG.GOGGame && (game as GameHub.Data.Sources.GOG.GOGGame).bonus_content_dir != null && (game as GameHub.Data.Sources.GOG.GOGGame).bonus_content_dir.query_exists();
			action_open_screenshots_directory.visible = game is GameHub.Data.Sources.Steam.SteamGame && (game as GameHub.Data.Sources.Steam.SteamGame).screenshots_dir != null && (game as GameHub.Data.Sources.Steam.SteamGame).screenshots_dir.query_exists();
			action_open_store_page.visible = game.store_page != null;
			action_uninstall.visible = s.state == Game.State.INSTALLED && !(game is GameHub.Data.Sources.GOG.GOGGame.DLC);
			action_properties.visible = !(game is GameHub.Data.Sources.GOG.GOGGame.DLC);

			if(action_run_with_compat.visible && game.compat_tool != null)
			{
				foreach(var tool in CompatTools)
				{
					if(tool.id == game.compat_tool)
					{
						action_run_with_compat.icon_overlay = tool.icon;
						break;
					}
				}
			}
		}

		public void update()
		{
			Utils.thread("GameDetailsPageUpdate", () => {
				update_game.begin();
			});
		}

		private async void update_game()
		{
			is_dialog = !(get_toplevel() is GameHub.UI.Windows.MainWindow);

			title.max_width_chars = is_dialog ? 36 : -1;

			#if GTK_3_22
			content_scrolled.max_content_height = is_dialog ? 640 : -1;
			#endif

			if(is_updated) return;

			if(spinner.parent == stack)
			{
				stack.visible_child = spinner;
			}

			if(game == null) return;

			try
			{
				yield game.update_game_info();
				
				is_updated = true;
			}
			catch(Utils.RunError error)
			{
				is_updated = false;
				
				//FIXME [DEV-ART]: Replace this with inline error display?
				yield GameHub.UI.Dialogs.QuickErrorDialog.display_and_log(
					this, error, Log.METHOD,
					_("Updating game information failed")
				);
			}

			title.label = game.name;
			src_icon.icon_name = game.source.icon;

			platform_icons.foreach(w => platform_icons.remove(w));
			foreach(var p in game.platforms)
			{
				var icon = new Image();
				icon.icon_name = p.icon();
				icon.icon_size = IconSize.DIALOG;
				icon.opacity = 0.1;
				platform_icons.add(icon);
			}
			platform_icons.show_all();

			blocks.foreach(b => b.destroy());
			sidebar.foreach(b => b.destroy());

			var desc = new Blocks.Description(game, is_dialog);
			var igdb = new Blocks.IGDBInfo(game, desc, is_dialog);

			GameDetailsBlock[] blk = {
				new Blocks.Achievements(game, is_dialog),
				igdb.description,
				desc
			};
			GameDetailsBlock[] sidebar_blk = {
				new Blocks.Artwork(game, details_view),
				new Blocks.Playtime(game),
				igdb,
				new Blocks.SteamDetails(game),
				new Blocks.GOGDetails(game, this)
			};

			foreach(var b in blk)
			{
				if(b.supports_game)
				{
					blocks.add(b);
				}
			}
			foreach(var b in sidebar_blk)
			{
				if(b.supports_game)
				{
					sidebar.add(b);
				}
			}

			game.status_change.connect(s => {
				Idle.add(() => {
					set_visible_widgets(s);
					return Source.REMOVE;
				});
			});
			set_visible_widgets(game.status);

			icon.load(game.icon, null, @"games/$(game.source.id)/$(game.id)/icons/");
			no_icon_indicator.visible = game.icon == null || icon.source == null;

			if(content_scrolled.parent == stack)
			{
				stack.visible_child = content_scrolled;
			}
		}

		private void install_game()
		{
			if(_game != null && game.status.state == Game.State.UNINSTALLED)
			{
				game.install.begin();
			}
		}

		private void game_properties()
		{
			if(_game != null)
			{
				new Dialogs.GamePropertiesDialog(game).show_all();
			}
		}

		private void open_game_directory()
		{
			if(_game != null && game.status.state == Game.State.INSTALLED && game.install_dir != null && game.install_dir.query_exists())
			{
				try
				{
					Utils.open_uri(game.install_dir.get_uri());
				}
				catch(Utils.RunError error)
				{
					//FIXME [DEV-ART]: Replace this with inline error display?
					GameHub.UI.Dialogs.QuickErrorDialog.display_and_log.begin(
						this, error, Log.METHOD,
						_("Opening game directory “%s” of game “%s” failed").printf(
							game.install_dir.get_path(), game.name
						)
					);
				}
			}
		}

		private void open_installer_collection_directory()
		{
			if(_game != null && game.installers_dir != null && game.installers_dir.query_exists())
			{
				try
				{
					Utils.open_uri(game.installers_dir.get_uri());
				}
				catch(Utils.RunError error)
				{
					//FIXME [DEV-ART]: Replace this with inline error display?
					GameHub.UI.Dialogs.QuickErrorDialog.display_and_log.begin(
						this, error, Log.METHOD,
						_("Opening installer directory “%s” of game “%s” failed").printf(
							game.installers_dir.get_path(), game.name
						)
					);
				}
			}
		}

		private void open_bonus_collection_directory()
		{
			if(_game != null && game is GameHub.Data.Sources.GOG.GOGGame)
			{
				var gog_game = game as GameHub.Data.Sources.GOG.GOGGame;
				if(gog_game != null && gog_game.bonus_content_dir != null && gog_game.bonus_content_dir.query_exists())
				{
					try
					{
						Utils.open_uri(gog_game.bonus_content_dir.get_uri());
					}
					catch(Utils.RunError error)
					{
						//FIXME [DEV-ART]: Replace this with inline error display?
						GameHub.UI.Dialogs.QuickErrorDialog.display_and_log.begin(
							this, error, Log.METHOD,
							_("Opening bonus content directory “%s” of game “%s” failed").printf(
								gog_game.bonus_content_dir.get_path(), game.name
							)
						);
					}
				}
			}
		}

		private void open_screenshots_directory()
		{
			if(_game != null && game is GameHub.Data.Sources.Steam.SteamGame)
			{
				var steam_game = game as GameHub.Data.Sources.Steam.SteamGame;
				if(steam_game != null && steam_game.screenshots_dir != null && steam_game.screenshots_dir.query_exists())
				{
					try
					{
						Utils.open_uri(steam_game.screenshots_dir.get_uri());
					}
					catch(Utils.RunError error)
					{
						//FIXME [DEV-ART]: Replace this with inline error display?
						GameHub.UI.Dialogs.QuickErrorDialog.display_and_log.begin(
							this, error, Log.METHOD,
							_("Opening screenshot directory “%s” of game “%s” failed").printf(
								steam_game.screenshots_dir.get_path(), game.name
							)
						);
					}
				}
			}
		}

		private void open_game_store_page()
		{
			if(_game != null && game.store_page != null)
			{
				try
				{
					Utils.open_uri(game.store_page);
				}
				catch(Utils.RunError error)
				{
					//FIXME [DEV-ART]: Replace this with inline error display?
					GameHub.UI.Dialogs.QuickErrorDialog.display_and_log.begin(
						this, error, Log.METHOD,
						_("Opening game store page “%s” of game “%s” failed").printf(
							game.store_page, game.name
						)
					);
				}
			}
		}

		private void run_game()
		{
			if(_game != null && game.status.state == Game.State.INSTALLED)
			{
				game.run.begin((obj, res) => {
					try
					{
						game.run.end(res);
					}
					catch(Utils.RunError error)
					{
						//FIXME [DEV-ART]: Replace this with inline error display?
						GameHub.UI.Dialogs.QuickErrorDialog.display_and_log.begin(
							this, error, Log.METHOD,
							_("Launching game “%s” failed").printf(game.name)
						);
					}
				});
			}
		}

		private void run_game_with_compat()
		{
			if(_game != null && game.status.state == Game.State.INSTALLED)
			{
				game.run_with_compat.begin(false, (obj, res) => {
					try
					{
						game.run_with_compat.end(res);
					}
					catch(Utils.RunError error)
					{
						//FIXME [DEV-ART]: Replace this with inline error display?
						GameHub.UI.Dialogs.QuickErrorDialog.display_and_log.begin(
							this, error, Log.METHOD,
							_("Launching game “%s” failed").printf(game.name)
						);
					}
				});
			}
		}

		private void uninstall_game()
		{
			if(_game != null && game.status.state == Game.State.INSTALLED)
			{
				game.uninstall.begin((obj, res) => {
					try
					{
						game.uninstall.end(res);
					}
					catch(Utils.RunError error)
					{
						//FIXME [DEV-ART]: Replace this with inline error display?
						GameHub.UI.Dialogs.QuickErrorDialog.display_and_log.begin(
							this, error, Log.METHOD,
							_("Uninstalling game “%s” failed").printf(game.name)
						);
					}
				});
			}
		}

		private void open_context_menu(Event e, bool at_pointer=true)
		{
			if(_game != null)
			{
				new GameContextMenu(game, this).open(e, at_pointer);
			}
		}

		private delegate void Action();
		private ActionButton add_action(string icon, string? icon_overlay, string title, Action action, bool primary=false)
		{
			var ui_settings = Settings.UI.Appearance.instance;
			var button = new ActionButton(icon + Settings.UI.Appearance.symbolic_icon_suffix, icon_overlay, title, primary, ui_settings.icon_style.is_symbolic());
			button.hexpand = primary;
			actions.add(button);
			button.clicked.connect(() => action());
			ui_settings.notify["icon-style"].connect(() => {
				button.icon = icon + Settings.UI.Appearance.symbolic_icon_suffix;
				button.compact = ui_settings.icon_style.is_symbolic();
			});
			return button;
		}
	}
}
