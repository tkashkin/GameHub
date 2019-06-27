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

		public bool list_compact { get; set; }
		public bool grid_platform_icons { get; set; }

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
	}

	public class Behavior: SettingsSchema
	{
		public bool grid_doubleclick { get; set; }
		public bool merge_games { get; set; }
		public bool import_tags { get; set; }

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
