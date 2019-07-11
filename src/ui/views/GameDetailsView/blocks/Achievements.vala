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
using GameHub.Data.Sources.Steam;
using GameHub.Data.Sources.GOG;

using GameHub.Utils;

using GameHub.UI.Widgets;

namespace GameHub.UI.Views.GameDetailsView.Blocks
{
	public class Achievements: GameDetailsBlock
	{
		private const int IMAGE_SIZE = 32;

		public Achievements(Game game, bool is_dialog)
		{
			Object(game: game, orientation: Orientation.VERTICAL, text_max_width: is_dialog ? 80 : -1);
		}

		construct
		{
			if(!supports_game) return;

			var header = Styled.H4Label(_("Achievements"), "description-header");
			header.margin_start = header.margin_end = 7;

			var achievements_scrolled = new ScrolledWindow(null, null);
			achievements_scrolled.hscrollbar_policy = PolicyType.AUTOMATIC;
			achievements_scrolled.vscrollbar_policy = PolicyType.NEVER;

			var achievements_box = new Box(Orientation.HORIZONTAL, 4);
			achievements_box.margin_top = 8;
			achievements_box.margin_start = achievements_box.margin_end = 7;
			achievements_box.margin_bottom = 12;

			achievements_scrolled.add(achievements_box);

			game.load_achievements.begin((obj, res) => {
				game.load_achievements.end(res);

				if(game.achievements == null || game.achievements.size < 1) return;

				achievements_box.foreach(a => a.destroy());

				foreach(var achievement in game.achievements)
				{
					var image = new AutoSizeImage();
					image.valign = Align.CENTER;
					image.corner_radius = IMAGE_SIZE / 2;
					image.set_constraint(IMAGE_SIZE, IMAGE_SIZE, 1);
					image.set_size_request(IMAGE_SIZE, IMAGE_SIZE);
					image.opacity = achievement.unlocked ? 1 : 0.2;

					image.tooltip_markup = """<span weight="600">%s</span>""".printf(achievement.name.replace("&amp;", "&").replace("&", "&amp;")) + "\n";

					if(achievement.description.length > 0)
					{
						image.tooltip_markup += """<span>%s</span>""".printf(achievement.description.replace("&amp;", "&").replace("&", "&amp;")) + "\n";
					}

					if(achievement.unlocked)
					{
						image.tooltip_markup += "\n" + """<span weight="600" size="smaller">%s</span>""".printf(_("Unlocked: %s").printf(achievement.unlock_time));
					}

					if(achievement.global_percentage > 0)
					{
						image.tooltip_markup += "\n" + """<span weight="600" size="smaller">%s</span>""".printf(_("Global percentage: %g%%").printf(achievement.global_percentage));
					}

					image.load(achievement.image, @"achievement_$(game.source.id)_$(game.id)");
					achievements_box.add(image);
				}
				achievements_box.show_all();

				Idle.add(() => {
					add(header);
					add(achievements_scrolled);
					show_all();
					if(parent != null) parent.queue_draw();
					return Source.REMOVE;
				});
			});
		}

		public override bool supports_game { get { return game is SteamGame || game is GOGGame; } }
	}
}
