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


namespace GameHub.Settings.UI
{
	public class Appearance: SettingsSchema
	{
		public const string[] COLORED_ICONS_THEMES = { "elementary" };

		public bool dark_theme { get; set; }
		public Appearance.IconStyle icon_style { get; set; }

		public bool grid_titles { get; set; }
		public bool grid_platform_icons { get; set; }

		public int grid_card_width  { get; set; }
		public int grid_card_height { get; set; }

		public string[] list_style_cache;
		public string[] list_style { get; set; }
		public signal void list_style_updated(string[] style);

		public static string symbolic_icon_suffix
		{
			owned get
			{
				return instance.icon_style.icon_suffix();
			}
		}

		public static IconSize headerbar_icon_size
		{
			get
			{
				return instance.icon_style.headerbar_icon_size();
			}
		}

		public Appearance()
		{
			base(ProjectConfig.PROJECT_NAME + ".ui.appearance");
			list_style_cache = list_style;
		}

		public void update_list_style(string[] new_style)
		{
			list_style_cache = new_style;
			list_style_updated(list_style_cache);
			list_style = list_style_cache;
		}

		public static Gtk.Settings gtk_settings;
		private static Appearance? _instance;
		public static unowned Appearance instance
		{
			get
			{
				if(_instance == null)
				{
					_instance = new Appearance();
					gtk_settings = Gtk.Settings.get_default();
					gtk_settings.gtk_application_prefer_dark_theme = _instance.dark_theme;
					_instance.notify["dark-theme"].connect(() => {
						gtk_settings.gtk_application_prefer_dark_theme = _instance.dark_theme;
					});
					gtk_settings.notify["gtk-theme-name"].connect(() => {
						_instance.notify_property("icon-style");
					});
				}
				return _instance;
			}
		}

		public enum IconStyle
		{
			THEME = 0, SYMBOLIC = 1, COLORED = 2;

			public bool is_symbolic()
			{
				if(this == IconStyle.THEME)
				{
					return !(gtk_settings.gtk_theme_name in COLORED_ICONS_THEMES);
				}
				return this == IconStyle.SYMBOLIC;
			}

			public string icon_suffix()
			{
				return is_symbolic() ? "-symbolic" : "";
			}

			public IconSize headerbar_icon_size()
			{
				return is_symbolic() ? IconSize.SMALL_TOOLBAR : IconSize.LARGE_TOOLBAR;
			}
		}

		public enum GameGridSizePreset
		{
			STEAM = 0, STEAM_VERTICAL = 1, GOG = 2, GOG_VERTICAL = 3, SQUARE = 4, CUSTOM = 5;

			public const GameGridSizePreset[] PRESETS = { STEAM, STEAM_VERTICAL, GOG, GOG_VERTICAL, SQUARE, CUSTOM };

			public int width()
			{
				switch(this)
				{
					case STEAM:          return 460;
					case STEAM_VERTICAL: return 300;
					case GOG:            return 392;
					case GOG_VERTICAL:   return 342;
					case SQUARE:         return 320;
					case CUSTOM:         return -1;
				}
				assert_not_reached();
			}

			public int height()
			{
				switch(this)
				{
					case STEAM:          return 215;
					case STEAM_VERTICAL: return 450;
					case GOG:            return 220;
					case GOG_VERTICAL:   return 482;
					case SQUARE:         return 320;
					case CUSTOM:         return -1;
				}
				assert_not_reached();
			}

			public string name()
			{
				switch(this)
				{
					case STEAM:          return C_("grid_size_preset", "Steam");
					case STEAM_VERTICAL: return C_("grid_size_preset", "Steam (vertical)");
					case GOG:            return C_("grid_size_preset", "GOG");
					case GOG_VERTICAL:   return C_("grid_size_preset", "GOG (vertical)");
					case SQUARE:         return C_("grid_size_preset", "Square");
					case CUSTOM:         return C_("grid_size_preset", "Custom");
				}
				assert_not_reached();
			}

			public string icon()
			{
				switch(this)
				{
					case STEAM, STEAM_VERTICAL: return "source-steam-symbolic";
					case GOG, GOG_VERTICAL:     return "source-gog-symbolic";
					case SQUARE:                return "image-x-generic-symbolic";
					case CUSTOM:                return "document-properties-symbolic";
				}
				assert_not_reached();
			}

			public string? description()
			{
				var desc = name();
				if(this != CUSTOM)
				{
					desc += "\n" + """<span size="smaller" weight="600">%d × %d</span>""".printf(width(), height());
				}
				return desc;
			}

			public static GameGridSizePreset from_size(int? w, int? h)
			{
				foreach(var preset in PRESETS)
				{
					if(w == preset.width() && h == preset.height())
					{
						return preset;
					}
				}
				return CUSTOM;
			}
		}
	}

	public class Behavior: SettingsSchema
	{
		public bool grid_doubleclick { get; set; }
		public bool merge_games { get; set; }
		public bool import_tags { get; set; }
		public bool inhibit_screensaver { get; set; }

		public Behavior()
		{
			base(ProjectConfig.PROJECT_NAME + ".ui.behavior");
		}

		private static Behavior? _instance;
		public static unowned Behavior instance
		{
			get
			{
				if(_instance == null)
				{
					_instance = new Behavior();
				}
				return _instance;
			}
		}
	}
}
