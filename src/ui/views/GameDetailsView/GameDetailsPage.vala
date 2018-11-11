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

using Gtk;
using Gdk;
using Gee;
using Granite;
using GameHub.Data;
using GameHub.Utils;
using GameHub.UI.Widgets;
using GameHub.UI.Views.GamesView;
using WebKit;

namespace GameHub.UI.Views.GameDetailsView
{
	public class GameDetailsPage: Grid
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

			var title_hbox_eventbox = new EventBox();

			var title_overlay = new Overlay();
			title_overlay.margin_start = title_overlay.margin_end = 7;

			var title_icons = new Box(Orientation.HORIZONTAL, 15);
			title_icons.valign = Align.END;
			title_icons.halign = Align.END;

			var title_hbox = new Box(Orientation.HORIZONTAL, 15);

			icon = new AutoSizeImage();
			icon.set_constraint(48, 48, 1);
			icon.set_size_request(48, 48);

			title = new Label(null);
			title.halign = Align.START;
			title.wrap = true;
			title.xalign = 0;
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

			title_hbox.add(icon);
			title_hbox.add(title_vbox);

			title_icons.add(platform_icons);
			title_icons.add(src_icon);

			title_overlay.add(title_hbox);
			title_overlay.add_overlay(title_icons);

			title_hbox_eventbox.add(title_overlay);

			content.add(title_hbox_eventbox);

			blocks = new Box(Orientation.VERTICAL, 0);
			blocks.hexpand = false;

			actions = new Box(Orientation.HORIZONTAL, 0);
			actions.margin_top = actions.margin_bottom = 16;

			content.add(actions);
			content.add(blocks);

			content_scrolled.add(content);

			stack.add(spinner);
			stack.add(content_scrolled);

			stack.set_visible_child(spinner);

			add(stack);

			action_install = add_action("go-down", null, _("Install"), install_game, true);
			action_run = add_action("media-playback-start", null, _("Run"), run_game, true);
			action_run_with_compat = add_action("media-playback-start", "platform-windows-symbolic", _("Run with compatibility layer"), run_game_with_compat, true);
			action_open_directory = add_action("folder", null, _("Open installation directory"), open_game_directory);
			action_open_installer_collection_directory = add_action("folder-download", null, _("Open installers collection directory"), open_installer_collection_directory);
			action_open_bonus_collection_directory = add_action("folder-documents", null, _("Open bonus collection directory"), open_bonus_collection_directory);
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

		public void update()
		{
			update_game.begin();
		}

		private async void update_game()
		{
			is_dialog = !(get_toplevel() is GameHub.UI.Windows.MainWindow);

			title.max_width_chars = is_dialog ? 36 : -1;

			#if GTK_3_22
			content_scrolled.max_content_height = is_dialog ? 640 : -1;
			#endif

			if(is_updated) return;

			stack.set_visible_child(spinner);

			if(game == null) return;

			yield game.update_game_info();

			is_updated = true;

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

			blocks.foreach(b => blocks.remove(b));

			GameDetailsBlock[] blk = { new Blocks.Playtime(game, is_dialog), new Blocks.Achievements(game, is_dialog), new Blocks.GOGDetails(game, this, is_dialog), new Blocks.SteamDetails(game, is_dialog), new Blocks.Description(game, is_dialog) };
			foreach(var b in blk)
			{
				if(b.supports_game)
				{
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
				action_install.sensitive = s.state == Game.State.UNINSTALLED && game.is_installable;
				action_run_with_compat.visible = s.state == Game.State.INSTALLED && game.use_compat;
				action_run_with_compat.sensitive = Settings.UI.get_instance().use_compat;
				action_run.visible = s.state == Game.State.INSTALLED && !action_run_with_compat.visible;
				action_open_directory.visible = s.state == Game.State.INSTALLED && game.install_dir != null && game.install_dir.query_exists();
				action_open_installer_collection_directory.visible = game.installers_dir != null && game.installers_dir.query_exists();
				action_open_bonus_collection_directory.visible = game is GameHub.Data.Sources.GOG.GOGGame && (game as GameHub.Data.Sources.GOG.GOGGame).bonus_content_dir != null && (game as GameHub.Data.Sources.GOG.GOGGame).bonus_content_dir.query_exists();
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

		private void game_properties()
		{
			if(_game != null)
			{
				new Dialogs.GamePropertiesDialog(game).show_all();
			}
		}

		private void open_game_directory()
		{
			if(_game != null && game.status.state == Game.State.INSTALLED)
			{
				Utils.open_uri(game.install_dir.get_uri());
			}
		}

		private void open_installer_collection_directory()
		{
			if(_game != null && game.installers_dir != null && game.installers_dir.query_exists())
			{
				Utils.open_uri(game.installers_dir.get_uri());
			}
		}

		private void open_bonus_collection_directory()
		{
			if(_game != null && game is GameHub.Data.Sources.GOG.GOGGame)
			{
				var gog_game = game as GameHub.Data.Sources.GOG.GOGGame;
				if(gog_game != null && gog_game.bonus_content_dir != null && gog_game.bonus_content_dir.query_exists())
				{
					Utils.open_uri(gog_game.bonus_content_dir.get_uri());
				}
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

		private void run_game_with_compat()
		{
			if(_game != null && game.status.state == Game.State.INSTALLED)
			{
				game.run_with_compat.begin(false);
			}
		}

		private void uninstall_game()
		{
			if(_game != null && game.status.state == Game.State.INSTALLED)
			{
				game.uninstall.begin();
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
			var button = new ActionButton(icon, icon_overlay, title, primary);
			button.hexpand = primary;
			actions.add(button);
			button.clicked.connect(() => action());
			return button;
		}
	}
}
