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
using GameHub.Data.Sources.GOG;

using GameHub.UI.Widgets;
using GameHub.UI.Views.GamesView;

using GameHub.Utils;

namespace GameHub.UI.Views.GameDetailsView.Blocks
{
	public class GOGDetails: GameDetailsBlock
	{
		public GameDetailsPage details_page { get; construct; }

		public GOGDetails(Game game, GameDetailsPage page)
		{
			Object(game: game, orientation: Orientation.VERTICAL, details_page: page, text_max_width: 48);
		}

		construct
		{
			if(!supports_game) return;

			var gog_game = game as GOGGame;

			var root = Parser.parse_json(game.info_detailed);

			if(root == null || gog_game == null) return;

			get_style_context().add_class("gameinfo-sidebar-block");

			var link = new ActionButton(game.source.icon, null, "GOG", true, true);
			if(game.store_page != null)
			{
				link.tooltip_text = game.store_page;
				link.clicked.connect(() => {
					try
					{
						Utils.open_uri(game.store_page);
					}
					catch(Utils.RunError error)
					{
						//FIXME [DEV-ART]: Replace this with inline error display?
						GameHub.UI.Dialogs.QuickErrorDialog.display_and_log.begin(
							this, error, Log.METHOD,
							_("Opening website “%s” failed").printf(game.store_page)
						);
					}
				});
			}

			add(link);
			add(new Separator(Orientation.HORIZONTAL));

			var langs = Parser.json_object(root, {"languages"});
			if(langs != null)
			{
				var sys_langs = Intl.get_language_names();
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
				add_info_label(langs_label, langs_string, langs_string.contains(","), true);
			}

			if(gog_game.dlc != null && gog_game.dlc.size > 0)
			{
				add(new Separator(Orientation.HORIZONTAL));

				var installable = new ArrayList<GOGGame.DLC>();
				var not_installable = new ArrayList<GOGGame.DLC>();

				foreach(var dlc in gog_game.dlc)
				{
					(dlc.is_installable ? installable : not_installable).add(dlc);
				}

				var dlcbox = new Box(Orientation.VERTICAL, 0);
				var header = Styled.H4Label(_("DLC"));
				header.margin_start = header.margin_end = 8;
				dlcbox.add(header);

				if(installable.size > 0 || not_installable.size <= 3)
				{
					var dlclist = new ListBox();
					dlclist.selection_mode = SelectionMode.NONE;
					dlclist.get_style_context().add_class("gameinfo-content-list");

					foreach(var dlc in installable)
					{
						dlclist.add(new DLCRow(dlc, details_page));
					}

					if(not_installable.size <= 3)
					{
						foreach(var dlc in not_installable)
						{
							dlclist.add(new DLCRow(dlc, details_page));
						}
					}

					dlcbox.add(dlclist);
				}

				if(not_installable.size > 3)
				{
					var dlclist_scrolled = new ScrolledWindow(null, null);
					dlclist_scrolled.hscrollbar_policy = PolicyType.NEVER;
					dlclist_scrolled.set_size_request(420, 64);

					#if GTK_3_22
					dlclist_scrolled.propagate_natural_width = true;
					dlclist_scrolled.propagate_natural_height = true;
					dlclist_scrolled.max_content_height = 720;
					#endif

					var dlclist = new ListBox();
					dlclist.selection_mode = SelectionMode.NONE;
					dlclist.get_style_context().add_class("gameinfo-content-list");

					foreach(var dlc in not_installable)
					{
						dlclist.add(new DLCRow(dlc, details_page, false));
					}

					dlclist_scrolled.add(dlclist);

					var dlc_popover_button = new Button.with_label(_("%u DLCs cannot be installed").printf(not_installable.size));
					dlc_popover_button.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
					dlc_popover_button.get_style_context().add_class(Gtk.STYLE_CLASS_DIM_LABEL);

					var dlc_popover = new Popover(dlc_popover_button);
					dlc_popover.position = PositionType.LEFT;

					dlc_popover.add(dlclist_scrolled);
					dlclist_scrolled.show_all();

					dlc_popover_button.clicked.connect(() => {
						#if GTK_3_22
						dlc_popover.popup();
						#else
						dlc_popover.show();
						#endif
					});

					dlcbox.add(new Separator(Orientation.HORIZONTAL));
					dlcbox.add(dlc_popover_button);
				}

				add(dlcbox);
			}

			if(gog_game.bonus_content != null && gog_game.bonus_content.size > 0)
			{
				add(new Separator(Orientation.HORIZONTAL));

				var bonuslist_scrolled = new ScrolledWindow(null, null);
				bonuslist_scrolled.hscrollbar_policy = PolicyType.NEVER;
				bonuslist_scrolled.set_size_request(420, 64);

				#if GTK_3_22
				bonuslist_scrolled.propagate_natural_width = true;
				bonuslist_scrolled.propagate_natural_height = true;
				bonuslist_scrolled.max_content_height = 720;
				#endif

				var bonuslist = new ListBox();
				bonuslist.selection_mode = SelectionMode.NONE;
				bonuslist.get_style_context().add_class("gameinfo-content-list");

				foreach(var bonus in gog_game.bonus_content)
				{
					bonuslist.add(new BonusContentRow(bonus));
				}

				bonuslist_scrolled.add(bonuslist);

				var bonus_popover_button = new ActionButton("folder-download-symbolic", null, _("Bonus content"), true, true);

				var bonus_popover = new Popover(bonus_popover_button);
				bonus_popover.position = PositionType.LEFT;

				bonus_popover.add(bonuslist_scrolled);
				bonuslist_scrolled.show_all();

				bonus_popover_button.clicked.connect(() => {
					#if GTK_3_22
					bonus_popover.popup();
					#else
					bonus_popover.show();
					#endif
				});

				add(bonus_popover_button);
			}

			show_all();
			if(parent != null) parent.queue_draw();
		}

		public override bool supports_game { get { return (game is GOGGame) && game.info_detailed != null && game.info_detailed.length > 0; } }

		public class BonusContentRow: ListBoxRow
		{
			public GOGGame.BonusContent bonus;

			public BonusContentRow(GOGGame.BonusContent bonus)
			{
				this.bonus = bonus;

				var content = new Overlay();

				var progress_bar = new Frame(null);
				progress_bar.halign = Align.START;
				progress_bar.vexpand = true;
				progress_bar.get_style_context().add_class("progress");

				var box = new Box(Orientation.HORIZONTAL, 8);
				box.margin_start = box.margin_end = 8;
				box.margin_top = box.margin_bottom = 8;

				var icon = new Image.from_icon_name(bonus.icon, IconSize.BUTTON);

				var name = new Label(bonus.text);
				name.ellipsize = Pango.EllipsizeMode.END;
				name.hexpand = true;
				name.halign = Align.START;
				name.xalign = 0;

				var desc_label = new Label(format_size(bonus.size));
				desc_label.halign = Align.END;

				var status_icon = new Image.from_icon_name("folder-download-symbolic", IconSize.BUTTON);
				status_icon.halign = Align.END;

				box.add(icon);
				box.add(name);
				box.add(desc_label);
				box.add(status_icon);

				var event_box = new Box(Orientation.VERTICAL, 0);
				event_box.expand = true;

				content.add(box);
				content.add_overlay(progress_bar);
				content.add_overlay(event_box);

				bonus.status_change.connect(s => {
					if(s.state == GOGGame.BonusContent.State.DOWNLOADING)
					{
						Allocation alloc;
						content.get_allocation(out alloc);
						if(s.download != null && s.download.status != null)
						{
							progress_bar.get_style_context().add_class("downloading");
							progress_bar.set_size_request((int) (s.download.status.progress * alloc.width), alloc.height);
							desc_label.label = s.download.status.description;
							desc_label.get_style_context().remove_class(Gtk.STYLE_CLASS_DIM_LABEL);
							desc_label.ellipsize = Pango.EllipsizeMode.NONE;
							status_icon.icon_name = "folder-download-symbolic";
						}
						return;
					}

					progress_bar.get_style_context().remove_class("downloading");
					progress_bar.set_size_request(0, 0);

					if(s.state == GOGGame.BonusContent.State.DOWNLOADED && (bonus.downloaded_file == null || !bonus.downloaded_file.query_exists()))
					{
						s.state = GOGGame.BonusContent.State.NOT_DOWNLOADED;
					}

					if(s.state == GOGGame.BonusContent.State.DOWNLOADED)
					{
						desc_label.label = bonus.filename;
						desc_label.get_style_context().add_class(Gtk.STYLE_CLASS_DIM_LABEL);
						desc_label.ellipsize = Pango.EllipsizeMode.MIDDLE;
						status_icon.icon_name = "document-open-symbolic";
					}
					else
					{
						desc_label.label = format_size(bonus.size);
						desc_label.get_style_context().remove_class(Gtk.STYLE_CLASS_DIM_LABEL);
						desc_label.ellipsize = Pango.EllipsizeMode.NONE;
						status_icon.icon_name = "folder-download-symbolic";
					}
				});
				bonus.status_change(bonus.status);

				content.add_events(EventMask.ALL_EVENTS_MASK);
				content.button_release_event.connect(e => {
					if(e.button == 1)
					{
						if(bonus.status.state == GOGGame.BonusContent.State.NOT_DOWNLOADED || (bonus.status.state == GOGGame.BonusContent.State.DOWNLOADED && (bonus.downloaded_file == null || !bonus.downloaded_file.query_exists())))
						{
							bonus.download.begin();
						}
						else if(bonus.status.state == GOGGame.BonusContent.State.DOWNLOADED)
						{
							try
							{
								bonus.open();
							}
							catch(Utils.RunError error)
							{
								//FIXME [DEV-ART]: Replace this with inline error display?
								GameHub.UI.Dialogs.QuickErrorDialog.display_and_log.begin(
									this, error, Log.METHOD,
									_("Opening bonus content “%s” failed").printf(bonus.text)
								);
							}
						}
					}
					return true;
				});

				child = content;
			}
		}

		public class DLCRow: ListBoxRow
		{
			public GOGGame.DLC dlc;

			public DLCRow(GOGGame.DLC dlc, GameDetailsPage details_page, bool limit_name_width=true)
			{
				this.dlc = dlc;

				var ebox = new EventBox();
				ebox.margin_start = ebox.margin_end = 8;
				ebox.margin_top = ebox.margin_bottom = 6;

				var box = new Box(Orientation.HORIZONTAL, 8);

				var name = new Label(dlc.name);
				name.ellipsize = Pango.EllipsizeMode.END;
				name.hexpand = true;
				name.halign = Align.START;
				name.xalign = 0;

				if(limit_name_width)
				{
					name.max_width_chars = 42;
					name.tooltip_text = dlc.name;
				}

				var status_icon = new Image.from_icon_name(dlc.status.state == Game.State.INSTALLED ? "process-completed-symbolic" : "folder-download-symbolic", IconSize.BUTTON);
				status_icon.opacity = dlc.is_installable ? 1 : 0.6;
				status_icon.halign = Align.END;

				ebox.add_events(EventMask.BUTTON_RELEASE_MASK);
				ebox.button_release_event.connect(e => {
					switch(e.button)
					{
						case 1:
							details_page.details_view.navigate(dlc);
							break;

						case 3:
							new GameContextMenu(dlc, this).open(e, true);
							break;
					}
					return true;
				});

				dlc.status_change.connect(() => {
					Idle.add(() => {
						status_icon.icon_name = dlc.status.state == Game.State.INSTALLED ? "process-completed-symbolic" : "folder-download-symbolic";
						status_icon.opacity = dlc.is_installable ? 1 : 0.6;
						return Source.REMOVE;
					});
				});

				dlc.update_game_info.begin();

				box.add(name);
				box.add(status_icon);

				ebox.add(box);

				child = ebox;
			}
		}
	}
}
