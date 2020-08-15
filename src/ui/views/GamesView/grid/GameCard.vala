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
using GameHub.Data.Adapters;
using GameHub.Data.DB;
using GameHub.Data.Runnables;
using GameHub.Utils;
using GameHub.UI.Widgets;

namespace GameHub.UI.Views.GamesView.Grid
{
	public class GameCard: FlowBoxChild
	{
		public GamesAdapter? adapter { private get; construct; default = null; }
		private ArrayList<Game>? merges = null;

		private Game? _game = null;
		private Game? _visible_game = null;
		public Game? game
		{
			get
			{
				return _visible_game;
			}
			construct set
			{
				update_game(value);
			}
		}

		public signal void update_tags();

		private Frame card;
		private Overlay content;
		private Box scrim;
		private AutoSizeImage image;

		private Box info;
		private Label label;
		private Label status_label;

		private Box src_icons;
		private Box platform_icons;

		private Image favorite_icon;
		private Image updated_icon;

		private Frame progress_bar;

		private Image no_image_indicator;
		private Image running_indicator;

		private bool _image_is_visible = false;
		public bool image_is_visible
		{
			get
			{
				return _image_is_visible;
			}
			set
			{
				if(_image_is_visible != value)
				{
					_image_is_visible = value;
					update_image();
				}
			}
		}

		public GameCard(Game? game=null, GamesAdapter? adapter=null)
		{
			Object(game: game, adapter: adapter);
		}

		construct
		{
			margin = 0;

			card = Styled.Card("gamecard");
			card.margin = 4;

			child = card;

			content = new Overlay();

			image = new AutoSizeImage();

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

			info = new Box(Orientation.VERTICAL, 0);
			info.get_style_context().add_class("info");
			info.add(label);
			info.add(status_label);
			info.valign = Align.END;

			scrim = new Box(Orientation.VERTICAL, 0);
			scrim.get_style_context().add_class("scrim");
			scrim.hexpand = true;
			scrim.vexpand = true;

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
			content.add_overlay(scrim);
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
						if(!Settings.UI.Behavior.instance.grid_doubleclick || (Settings.UI.Behavior.instance.grid_doubleclick && e.type == EventType.2BUTTON_PRESS))
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

			favorite_icon.no_show_all = true;
			updated_icon.no_show_all = true;
			src_icons.no_show_all = true;
			platform_icons.no_show_all = true;
			info.no_show_all = true;
			show_all();

			Settings.UI.Appearance.instance.notify["grid-titles"].connect(update_appearance);
			Settings.UI.Appearance.instance.notify["grid-platform-icons"].connect(update_appearance);
			update_appearance();

			Settings.UI.Appearance.instance.notify["grid-card-width"].connect(update_image_constraints);
			Settings.UI.Appearance.instance.notify["grid-card-height"].connect(update_image_constraints);
			update_image_constraints();
		}

		private ulong status_handler_id;
		private ulong image_handler_id;
		private ulong image_vertical_handler_id;
		private ulong updates_handler_id;

		private void update_game(Game? new_game)
		{
			if(new_game == _game || new_game == null) return;

			if(_game != null)
			{
				_game.disconnect(status_handler_id);
				_game.disconnect(image_handler_id);
				_game.disconnect(image_vertical_handler_id);
				_game.disconnect(updates_handler_id);
			}

			_game = new_game;

			if(Settings.UI.Behavior.instance.merge_games)
			{
				merges = Tables.Merges.get(_game);
			}

			if(adapter != null)
			{
				adapter.notify["filter-source"].connect(() => {
					update_source(adapter.filter_source);
				});
				update_source(adapter.filter_source);
			}
			else
			{
				update_source(null);
			}
		}

		private void update_source(GameSource? source=null)
		{
			if(!Settings.UI.Behavior.instance.merge_games || merges == null || merges.size == 0)
			{
				update(_game);
				return;
			}

			var vg = _game;

			if(merges != null && merges.size > 0)
			{
				foreach(var g in merges)
				{
					if(vg is Sources.User.UserGame) break;
					if(source == null)
					{
						if(g.status.state > vg.status.state || g is Sources.User.UserGame)
						{
							vg = g;
						}
					}
					else if(g.source == source)
					{
						vg = g;
						break;
					}
				}
			}

			update(vg);
		}

		private void update(Game? vg)
		{
			_visible_game = vg;

			Idle.add(() => {
				label.label = game.name;

				src_icons.foreach(w => w.destroy());
				add_src_icon(game.source.icon);

				if(game != _game)
				{
					add_src_icon(_game.source.icon);
				}
				if(Settings.UI.Behavior.instance.merge_games && merges != null && merges.size > 0)
				{
					foreach(var g in merges)
					{
						if(g == game) continue;
						add_src_icon(g.source.icon);
					}
				}

				platform_icons.foreach(w => w.destroy());
				Platform[] platforms = {};
				foreach(var p in game.platforms)
				{
					if(!(p in platforms))
					{
						platforms += p;
					}
				}
				if(Settings.UI.Behavior.instance.merge_games && adapter.filter_source == null && merges != null && merges.size > 0)
				{
					foreach(var g in merges)
					{
						if(g == game) continue;
						foreach(var p in g.platforms)
						{
							if(!(p in platforms))
							{
								platforms += p;
							}
						}
					}
				}
				foreach(var p in platforms)
				{
					var icon = new Image();
					icon.icon_name = p.icon();
					icon.icon_size = IconSize.LARGE_TOOLBAR;
					platform_icons.add(icon);
				}

				update_appearance();

				return Source.REMOVE;
			});

			status_handler_id = game.notify["status"].connect(status_handler);
			status_handler();

			image_handler_id = game.notify["image"].connect(update_image);
			image_vertical_handler_id = game.notify["image-vertical"].connect(update_image);
			update_image();

			updates_handler_id = game.notify["has-updates"].connect(updates_handler);
			updates_handler();
		}

		private void add_src_icon(string icon_name)
		{
			var icon = new Image();
			icon.icon_name = icon_name;
			icon.icon_size = IconSize.LARGE_TOOLBAR;
			src_icons.add(icon);
		}

		private void status_handler()
		{
			Idle.add(() => {
				label.label = game.name;
				status_label.label = game.status.description;
				favorite_icon.visible = game.has_tag(Tables.Tags.BUILTIN_FAVORITES);
				switch(game.status.state)
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
						if(game.status.download != null && game.status.download.status != null && game.status.download.status.progress >= 0)
						{
							progress_bar.set_size_request((int) (game.status.download.status.progress * alloc.width), 8);
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
					no_image_indicator.opacity = game.image == null && game.image_vertical == null ? 1 : 0;
				}
				return Source.REMOVE;
			}, Priority.LOW);
		}

		private void update_image()
		{
			if(image == null) return;
			if(image_is_visible)
			{
				image.load(game.image, game.image_vertical, @"games/$(game.source.id)/$(game.id)/images/");
				no_image_indicator.opacity = game.image == null && game.image_vertical == null && !game.is_running ? 1 : 0;
			}
			else
			{
				#if PERF_GAMECARD_UNLOAD_IMAGES
				image.unload();
				#endif
			}
		}

		private void updates_handler()
		{
			Idle.add(() => {
				updated_icon.visible = game is GameHub.Data.Sources.GOG.GOGGame && ((GameHub.Data.Sources.GOG.GOGGame) game).has_updates;
				return Source.REMOVE;
			}, Priority.LOW);
		}

		private void update_appearance()
		{
			info.no_show_all = !Settings.UI.Appearance.instance.grid_titles;
			if(Settings.UI.Appearance.instance.grid_titles)
			{
				info.show_all();
			}
			else
			{
				info.hide();
			}
			src_icons.no_show_all = platform_icons.no_show_all = !Settings.UI.Appearance.instance.grid_platform_icons;
			if(Settings.UI.Appearance.instance.grid_platform_icons)
			{
				src_icons.show_all();
				platform_icons.show_all();
			}
			else
			{
				src_icons.hide();
				platform_icons.hide();
			}
		}

		private void update_image_constraints()
		{
			var w = Settings.UI.Appearance.instance.grid_card_width;
			var h = Settings.UI.Appearance.instance.grid_card_height;
			var ratio = (float) h / w;
			var min = (int) (w / 1.5f);
			var max = (int) (w * 1.5f);
			image.set_constraint(min, max, ratio);
		}

		private void open_context_menu(Event e, bool at_pointer=true)
		{
			new GameContextMenu(game, this).open(e, at_pointer);
		}
	}
}
