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
using GameHub.Utils;
using GameHub.UI.Widgets;

namespace GameHub.UI.Views.GamesView.List
{
	public class GameListRow: ListBoxRow
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

		private Overlay icon_overlay;
		private AutoSizeImage icon;
		private Image no_icon_indicator;

		private Label label;
		private Label status_label;
		private Image favorite_icon;
		private Image updated_icon;

		private bool _icon_is_visible = false;
		public bool icon_is_visible
		{
			get
			{
				return _icon_is_visible;
			}
			set
			{
				if(_icon_is_visible != value)
				{
					_icon_is_visible = value;
					update_icon();
				}
			}
		}

		private GameHub.Settings.UI.Appearance ui_settings;

		public GameListRow(Game? game=null, GamesAdapter? adapter=null)
		{
			Object(game: game, adapter: adapter, activatable: true, selectable: true);
		}

		construct
		{
			get_style_context().add_class("game-list-row");

			var hbox = new Box(Orientation.HORIZONTAL, 4);
			hbox.margin = 4;
			var vbox = new Box(Orientation.VERTICAL, 0);
			vbox.margin_start = 4;
			vbox.valign = Align.CENTER;

			icon_overlay = new Overlay();
			icon_overlay.no_show_all = true;

			no_icon_indicator = new Image.from_icon_name("gamehub-symbolic", IconSize.BUTTON);
			no_icon_indicator.get_style_context().add_class("no-icon-indicator");
			no_icon_indicator.halign = Align.CENTER;
			no_icon_indicator.valign = Align.CENTER;
			no_icon_indicator.opacity = 0.8;

			icon = new AutoSizeImage();
			icon.halign = Align.CENTER;
			icon.valign = Align.CENTER;
			icon.scale = true;

			icon_overlay.add(no_icon_indicator);
			icon_overlay.add_overlay(icon);

			no_icon_indicator.show_all();
			icon.show_all();

			hbox.add(icon_overlay);

			var label_hbox = new Box(Orientation.HORIZONTAL, 4);

			favorite_icon = new Image.from_icon_name("gh-game-favorite-symbolic", IconSize.BUTTON);
			updated_icon = new Image.from_icon_name("gh-game-updated-symbolic", IconSize.BUTTON);
			favorite_icon.no_show_all = updated_icon.no_show_all = true;
			favorite_icon.margin_top = updated_icon.margin_top = 2;
			favorite_icon.valign = updated_icon.valign = Align.CENTER;
			favorite_icon.pixel_size = updated_icon.pixel_size = 8;

			label = Styled.Label(null, "title");
			label.hexpand = true;
			label.xalign = 0;
			label.ellipsize = Pango.EllipsizeMode.END;

			label_hbox.add(label);
			label_hbox.add(favorite_icon);
			label_hbox.add(updated_icon);

			status_label = Styled.Label(null, "status");
			status_label.halign = Align.START;
			status_label.xalign = 0;
			status_label.ellipsize = Pango.EllipsizeMode.END;
			status_label.no_show_all = true;

			vbox.add(label_hbox);
			vbox.add(status_label);

			hbox.add(vbox);

			notify["is-selected"].connect(update_icon);

			ui_settings = GameHub.Settings.UI.Appearance.instance;
			ui_settings.list_style_updated.connect(update_style);
			update_style(ui_settings.list_style_cache);

			var ebox = new EventBox();
			ebox.add(hbox);

			child = ebox;

			ebox.add_events(EventMask.ALL_EVENTS_MASK);
			ebox.button_press_event.connect(e => {
				switch(e.button)
				{
					case 1:
						var list = (ListBox) parent;

						if(ModifierType.CONTROL_MASK in e.state)
						{
							if(is_selected())
							{
								list.unselect_row(this);
							}
							else
							{
								list.select_row(this);
							}
						}
						else
						{
							list.unselect_all();
							activate();

							if(e.type == EventType.2BUTTON_PRESS)
							{
								game.run_or_install.begin();
							}
						}
						break;

					case 3:
						new GameContextMenu(game, icon).open(e, true);
						break;
				}
				return true;
			});
		}

		private ulong status_handler_id;
		private ulong updates_handler_id;

		private void update_game(Game? new_game)
		{
			if(new_game == _game || new_game == null) return;

			if(_game != null)
			{
				_game.disconnect(status_handler_id);
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

			status_handler_id = game.status_change.connect(status_handler);
			status_handler(game.status);

			updates_handler_id = game.notify["has-updates"].connect(updates_handler);
			updates_handler();
		}

		private void status_handler(Game.Status s)
		{
			// Use weak reference to avoid capturing `this` strongly
			weak GameListRow weak_self = this;

			Idle.add(() => {
				// early return when GameCard got destructed to prevent segfault
				if (weak_self == null)
					return Source.REMOVE;

				label.label = game.name;
				status_label.label = s.description;
				tooltip_markup = """<span weight="600">%s</span>""".printf(game.name.replace("&amp;", "&").replace("&", "&amp;")) + "\n" + """<span size="smaller">%s</span>""".printf(s.description.replace("&amp;", "&").replace("&", "&amp;"));
				update_style(ui_settings.list_style_cache);
				favorite_icon.visible = game.has_tag(Tables.Tags.BUILTIN_FAVORITES);
				update_icon();
				changed();
				return Source.REMOVE;
			}, Priority.LOW);
		}

		private void updates_handler()
		{
			Idle.add(() => {
				updated_icon.visible = game is GameHub.Data.Sources.GOG.GOGGame && (game as GameHub.Data.Sources.GOG.GOGGame).has_updates;
				return Source.REMOVE;
			}, Priority.LOW);
		}

		public void update_style(string[] style)
		{
			var is_gog_game = game is GameHub.Data.Sources.GOG.GOGGame;
			var is_installed = game != null && game.status != null && game.status.state != Game.State.UNINSTALLED;

			var style_prefix = is_installed ? "installed" : "uninstalled";

			var show_status = @"$(style_prefix)-status" in style;

			// GOG icons are rounded, make them bigger to compensate visual difference
			var image_size = !show_status ? (is_gog_game ? 18 : 16) : (is_gog_game ? 38 : 32);
			var overlay_size = !show_status ? 18 : 38;

			icon.set_constraint(image_size, image_size, 1);
			icon_overlay.set_size_request(overlay_size, overlay_size);

			status_label.visible = show_status;

			icon_overlay.visible = @"$(style_prefix)-icon" in style;

			if(@"$(style_prefix)-title-bold" in style)
			{
				StyleClass.add(label, "bold");
			}
			else
			{
				StyleClass.remove(label, "bold");
			}

			if(@"$(style_prefix)-dim" in style)
			{
				StyleClass.add(this, "dim");
			}
			else
			{
				StyleClass.remove(this, "dim");
			}
		}

		private void update_icon()
		{
			if(icon_is_visible)
			{
				icon.load(game.icon, null, @"games/$(game.source.id)/$(game.id)/icons/");
			}
			else
			{
				icon.unload();
			}
		}
	}
}
