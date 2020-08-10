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

using GameHub.Data;
using GameHub.Data.Runnables;

using GameHub.UI.Widgets;
using GameHub.Utils;

namespace GameHub.UI.Dialogs.GamePropertiesDialog
{
	public class GamePropertiesDialog: Dialog
	{
		public Game game { get; construct; }

		private HeaderBar headerbar;
		private Notebook tabs;

		public GamePropertiesDialog(Game game)
		{
			Object(resizable: false, use_header_bar: 1, title: game.name, game: game);
		}

		construct
		{
			//set_size_request(700, 500);
			set_size_request(800, 640);

			get_style_context().add_class("game-properties-dialog");

			headerbar = (HeaderBar) get_header_bar();
			headerbar.has_subtitle = true;
			headerbar.show_close_button = true;
			headerbar.subtitle = _("Properties");

			tabs = new Notebook();
			tabs.show_border = false;
			tabs.expand = true;

			var stack = new Stack();
			stack.get_style_context().add_class("root-stack");
			stack.expand = true;
			stack.transition_type = StackTransitionType.CROSSFADE;
			stack.vhomogeneous = true;

			var loading_spinner = new Spinner();
			loading_spinner.active = true;
			loading_spinner.set_size_request(36, 36);
			loading_spinner.halign = Align.CENTER;
			loading_spinner.valign = Align.CENTER;

			stack.add(loading_spinner);
			stack.add(tabs);
			stack.visible_child = loading_spinner;

			get_content_area().add(stack);

			game.update_game_info.begin((obj, res) => {
				game.update_game_info.end(res);

				var icon = new AutoSizeImage();
				icon.valign = Align.CENTER;
				icon.set_constraint(36, 36);
				icon.load(game.icon, null, @"games/$(game.source.id)/$(game.id)/icons/");
				game.notify["icon"].connect(() => {
					Idle.add(() => {
						icon.load(game.icon, null, @"games/$(game.source.id)/$(game.id)/icons/");
						return Source.REMOVE;
					});
				});
				headerbar.pack_start(icon);
				headerbar.show_all();

				game.notify["name"].connect(() => {
					Idle.add(() => {
						headerbar.title = game.name;
						return Source.REMOVE;
					});
				});

				add_tab(new Tabs.General(game));

				game.cast<Traits.HasExecutableFile>(game => add_tab(new DummyTab(_("Executable"))));
				game.cast<Traits.SupportsCompatTools>(game => add_tab(new DummyTab(_("Compatibility"))));

				game.cast<Traits.Game.SupportsTweaks>(game => add_tab(new Tabs.Tweaks(game)));
				game.cast<Traits.Game.SupportsOverlays>(game => add_tab(new Tabs.Overlays(game)));

				tabs.show_tabs = tabs.get_n_pages() > 1;
				tabs.show_all();
				stack.visible_child = tabs;
			});

			show_all();
		}

		private void add_tab(GamePropertiesDialogTab tab)
		{
			tabs.append_page(tab, new Label(tab.title));
		}
	}

	public abstract class GamePropertiesDialogTab: Box
	{
		public string title { get; construct; }

		construct
		{
			get_style_context().add_class(Gtk.STYLE_CLASS_BACKGROUND);
			get_style_context().add_class("game-properties-dialog-tab");
		}
	}

	private class DummyTab: GamePropertiesDialogTab
	{
		public DummyTab(string title)
		{
			Object(title: title);
		}
	}
}
