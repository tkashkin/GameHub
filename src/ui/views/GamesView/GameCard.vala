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
using Granite;
using GameHub.Data;
using GameHub.Data.DB;
using GameHub.Utils;
using GameHub.UI.Widgets;

namespace GameHub.UI.Views.GamesView
{
	public class GameCard: FlowBoxChild
	{
		public Game game { get; construct; }

		public signal void update_tags();

		private Frame card;
		private Overlay content;
		private AutoSizeImage image;
		private Label label;
		private Label status_label;

		private Box src_icons;
		private Image src_icon;

		private Image favorite_icon;
		private Image updated_icon;

		private Box platform_icons;

		private Box actions;

		private const int CARD_WIDTH_MIN = 320;
		private const int CARD_WIDTH_MAX = 680;
		private const float CARD_RATIO = 0.467f; // 460x215

		private Frame progress_bar;

		private Image no_image_indicator;
		private Image running_indicator;

		construct
		{
			margin = 0;

			card = new Frame(null);
			card.get_style_context().add_class(Granite.STYLE_CLASS_CARD);
			card.get_style_context().add_class("gamecard");
			card.shadow_type = ShadowType.NONE;
			card.margin = 4;

			child = card;

			content = new Overlay();

			image = new AutoSizeImage();
			image.set_constraint(CARD_WIDTH_MIN, CARD_WIDTH_MAX, CARD_RATIO);

			src_icons = new Box(Orientation.HORIZONTAL, 4);
			src_icons.valign = Align.START;
			src_icons.halign = Align.START;
			src_icons.margin = 8;
			src_icons.set_events(0);

			platform_icons = new Box(Orientation.HORIZONTAL, 4);
			platform_icons.valign = Align.START;
			platform_icons.halign = Align.END;
			platform_icons.margin = 8;
			platform_icons.set_events(0);

			src_icon = new Image();
			src_icon.icon_size = IconSize.LARGE_TOOLBAR;

			label = new Label("");
			label.xpad = 8;
			label.ypad = 4;
			label.hexpand = true;
			label.justify = Justification.CENTER;
			label.lines = 3;
			label.ellipsize = Pango.EllipsizeMode.END;
			label.set_line_wrap(true);

			favorite_icon = new Image.from_icon_name("gh-game-favorite-symbolic", IconSize.BUTTON);
			favorite_icon.valign = Align.END;
			favorite_icon.halign = Align.START;
			favorite_icon.margin = 6;

			updated_icon = new Image.from_icon_name("gh-game-updated-symbolic", IconSize.BUTTON);
			updated_icon.valign = Align.END;
			updated_icon.halign = Align.END;
			updated_icon.margin = 6;

			favorite_icon.pixel_size = updated_icon.pixel_size = 12;

			status_label = new Label("");
			status_label.get_style_context().add_class("status");
			status_label.xpad = 8;
			status_label.ypad = 2;
			status_label.hexpand = true;
			status_label.justify = Justification.CENTER;
			status_label.lines = 1;

			var info = new Box(Orientation.VERTICAL, 0);
			info.get_style_context().add_class("info");
			info.add(label);
			info.add(status_label);
			info.valign = Align.END;

			actions = new Box(Orientation.VERTICAL, 0);
			actions.get_style_context().add_class("actions");
			actions.hexpand = true;
			actions.vexpand = true;

			progress_bar = new Frame(null);
			progress_bar.halign = Align.START;
			progress_bar.valign = Align.END;
			progress_bar.get_style_context().add_class("progress");

			no_image_indicator = new Image.from_icon_name("gamehub-symbolic", IconSize.DIALOG);
			no_image_indicator.get_style_context().add_class("no-image-indicator");
			no_image_indicator.halign = Align.CENTER;
			no_image_indicator.valign = Align.CENTER;
			no_image_indicator.opacity = 0;

			running_indicator = new Image.from_icon_name("system-run-symbolic", IconSize.DIALOG);
			running_indicator.get_style_context().add_class("running-indicator");
			running_indicator.halign = Align.CENTER;
			running_indicator.valign = Align.CENTER;
			running_indicator.opacity = 0;

			content.add(image);
			content.add_overlay(actions);
			content.add_overlay(info);
			content.add_overlay(platform_icons);
			content.add_overlay(src_icons);
			content.add_overlay(favorite_icon);
			content.add_overlay(updated_icon);
			content.add_overlay(progress_bar);
			content.add_overlay(no_image_indicator);
			content.add_overlay(running_indicator);

			card.add(content);

			content.add_events(EventMask.ALL_EVENTS_MASK);
			content.enter_notify_event.connect(e => { card.get_style_context().add_class("hover"); });
			content.leave_notify_event.connect(e => { card.get_style_context().remove_class("hover"); });
			content.button_press_event.connect(e => {
				switch(e.button)
				{
					case 1:
						if(!Settings.UI.get_instance().grid_doubleclick || (Settings.UI.get_instance().grid_doubleclick && e.type == EventType.2BUTTON_PRESS))
						{
							game.run_or_install.begin();
						}
						break;

					case 3:
						open_context_menu(e, true);
						break;
				}
				((FlowBox) parent).select_child(this);
				grab_focus();
				return true;
			});
			key_release_event.connect(e => {
				switch(((EventKey) e).keyval)
				{
					case Key.Return:
					case Key.space:
					case Key.KP_Space:
						game.run_or_install.begin();
						return true;

					case Key.Menu:
						open_context_menu(e, false);
						return true;
				}
				return false;
			});
		}

		public GameCard(Game game)
		{
			Object(game: game);

			Idle.add(() => {
				label.label = game.name;
				src_icon.icon_name = game.source.icon;
				return Source.REMOVE;
			});

			update();

			card.get_style_context().add_class("installed");

			game.status_change.connect(s => {
				Idle.add(() => {
					label.label = game.name;
					status_label.label = s.description;
					favorite_icon.visible = game.has_tag(Tables.Tags.BUILTIN_FAVORITES);
					switch(s.state)
					{
						case Game.State.UNINSTALLED:
							card.get_style_context().remove_class("installed");
							card.get_style_context().remove_class("downloading");
							card.get_style_context().remove_class("installing");
							break;

						case Game.State.INSTALLED:
							card.get_style_context().add_class("installed");
							card.get_style_context().remove_class("downloading");
							card.get_style_context().remove_class("installing");
							break;

						case Game.State.DOWNLOADING:
							card.get_style_context().remove_class("installed");
							card.get_style_context().add_class("downloading");
							card.get_style_context().remove_class("installing");
							Allocation alloc;
							card.get_allocation(out alloc);
							if(s.download != null)
							{
								progress_bar.set_size_request((int) (s.download.status.progress * alloc.width), 8);
							}
							break;

						case Game.State.INSTALLING:
							card.get_style_context().remove_class("installed");
							card.get_style_context().remove_class("downloading");
							card.get_style_context().add_class("installing");
							break;
					}
					if(game.is_running)
					{
						card.get_style_context().add_class("running");
						running_indicator.opacity = 1;
						no_image_indicator.opacity = 0;
					}
					else
					{
						card.get_style_context().remove_class("running");
						running_indicator.opacity = 0;
						no_image_indicator.opacity = game.image == null ? 1 : 0;
					}
					return Source.REMOVE;
				});
			});
			game.status_change(game.status);

			game.notify["image"].connect(() => {
				image.load(game.image, "image");
				no_image_indicator.opacity = game.image == null && !game.is_running ? 1 : 0;
			});
			game.notify_property("image");

			updated_icon.visible = false;
			if(game is GameHub.Data.Sources.GOG.GOGGame)
			{
				game.notify["has-updates"].connect(() => {
					Idle.add(() => {
						updated_icon.visible = (game as GameHub.Data.Sources.GOG.GOGGame).has_updates;
						return Source.REMOVE;
					});
				});
				game.notify_property("has-updates");
			}

			Settings.UI.get_instance().notify["show-grid-icons"].connect(update);
		}

		private void open_context_menu(Event e, bool at_pointer=true)
		{
			new GameContextMenu(game, this).open(e, at_pointer);
		}

		public void update()
		{
			src_icons.foreach(w => src_icons.remove(w));
			src_icons.add(src_icon);

			var merges = Tables.Merges.get(game);
			if(merges != null && merges.size > 0)
			{
				foreach(var g in merges)
				{
					var icon_name = g.source.icon;

					src_icons.foreach(w => { if((w as Image).icon_name == icon_name) src_icons.remove(w); });

					var icon = new Image();
					icon.icon_name = icon_name;
					icon.icon_size = IconSize.LARGE_TOOLBAR;
					src_icons.add(icon);
				}
			}
			src_icons.show_all();

			platform_icons.foreach(w => platform_icons.remove(w));
			foreach(var p in game.platforms)
			{
				var icon = new Image();
				icon.icon_name = p.icon();
				icon.icon_size = IconSize.LARGE_TOOLBAR;
				platform_icons.add(icon);
			}
			platform_icons.show_all();

			src_icons.visible = platform_icons.visible = Settings.UI.get_instance().show_grid_icons;
		}

		public override void show_all()
		{
			base.show_all();
			update();
		}
	}
}
