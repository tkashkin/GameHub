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

using Gee;

using GameHub.Data;
using GameHub.Utils;

namespace GameHub.Settings.Paths
{
	public class Steam: GameHub.Settings.SettingsSchema
	{
		public string home { get; set; }

		public Steam()
		{
			base(ProjectConfig.PROJECT_NAME + ".paths.steam");
		}

		private static Steam _instance;
		public static Steam instance
		{
			get
			{
				if(_instance == null)
				{
					_instance = new Steam();
				}
				return _instance;
			}
		}
	}

	public class GOG: GameHub.Settings.SettingsSchema
	{
		public string[] game_directories { get; set; }
		public string default_game_directory { get; set; }

		public GOG()
		{
			base(ProjectConfig.PROJECT_NAME + ".paths.gog");
		}

		private static GOG _instance;
		public static GOG instance
		{
			get
			{
				if(_instance == null)
				{
					_instance = new GOG();
				}
				return _instance;
			}
		}
	}

	public class Humble: GameHub.Settings.SettingsSchema
	{
		public string[] game_directories { get; set; }
		public string default_game_directory { get; set; }

		public Humble()
		{
			base(ProjectConfig.PROJECT_NAME + ".paths.humble");
		}

		private static Humble _instance;
		public static Humble instance
		{
			get
			{
				if(_instance == null)
				{
					_instance = new Humble();
				}
				return _instance;
			}
		}
	}

	public class Itch: GameHub.Settings.SettingsSchema
	{
		public string home { get; set; }
		public string[] game_directories { get; set; }
		public string default_game_directory { get; set; }

		public Itch()
		{
			base(ProjectConfig.PROJECT_NAME + ".paths.itch");
		}

		private static Itch _instance;
		public static Itch instance
		{
			get
			{
				if(_instance == null)
				{
					_instance = new Itch();
				}
				return _instance;
			}
		}
	}

	public class Collection: GameHub.Settings.SettingsSchema
	{
		public string root { get; set; }

		public static string expand_root()
		{
			return FS.expand(instance.root);
		}

		public Collection()
		{
			base(ProjectConfig.PROJECT_NAME + ".paths.collection");
		}

		private static Collection? _instance;
		public static unowned Collection instance
		{
			get
			{
				if(_instance == null)
				{
					_instance = new Collection();
				}
				return _instance;
			}
		}

		public class GOG: GameHub.Settings.SettingsSchema
		{
			public string game_dir { get; set; }
			public string installers { get; set; }
			public string dlc { get; set; }
			public string bonus { get; set; }

			public static string expand_game_dir(string game, Platform? platform=null)
			{
				var g = game.replace(": ", " - ").replace(":", "");
				var variables = new HashMap<string, string>();
				variables.set("root", Collection.instance.root);
				variables.set("game", g);
				variables.set("platform_name", platform == null ? "" : platform.name());
				variables.set("platform", platform == null ? "" : platform.id());
				return FS.expand(instance.game_dir, null, variables);
			}
			public static string expand_dlc(string game, Platform? platform=null)
			{
				var g = game.replace(": ", " - ").replace(":", "");
				var variables = new HashMap<string, string>();
				variables.set("root", Collection.instance.root);
				variables.set("platform_name", platform == null ? "." : platform.name());
				variables.set("platform", platform == null ? "." : platform.id());
				variables.set("game_dir", expand_game_dir(g, platform));
				return FS.expand(instance.dlc, null, variables);
			}
			public static string expand_installers(string game, string? dlc=null, Platform? platform=null)
			{
				var g = game.replace(": ", " - ").replace(":", "");
				var d = dlc == null ? null : dlc.replace(": ", " - ").replace(":", "");
				var variables = new HashMap<string, string>();
				variables.set("root", Collection.instance.root);
				variables.set("platform_name", platform == null ? "." : platform.name());
				variables.set("platform", platform == null ? "." : platform.id());
				if(d == null)
				{
					variables.set("game_dir", expand_game_dir(g, platform));
				}
				else
				{
					variables.set("game_dir", expand_dlc(g, platform) + "/" + d);
				}
				return FS.expand(instance.installers, null, variables);
			}
			public static string expand_bonus(string game, string? dlc=null)
			{
				var g = game.replace(": ", " - ").replace(":", "");
				var d = dlc == null ? null : dlc.replace(": ", " - ").replace(":", "");
				var variables = new HashMap<string, string>();
				variables.set("root", Collection.instance.root);
				if(d == null)
				{
					variables.set("game_dir", expand_game_dir(g));
				}
				else
				{
					variables.set("game_dir", expand_dlc(g) + "/" + d);
				}
				return FS.expand(instance.bonus, null, variables);
			}

			public GOG()
			{
				base(ProjectConfig.PROJECT_NAME + ".paths.collection.gog");
			}

			private static GOG? _instance;
			public static unowned GOG instance
			{
				get
				{
					if(_instance == null)
					{
						_instance = new GOG();
					}
					return _instance;
				}
			}
		}

		public class Humble: GameHub.Settings.SettingsSchema
		{
			public string game_dir { get; set; }
			public string installers { get; set; }

			public static string expand_game_dir(string game, Platform? platform=null)
			{
				var g = game.replace(": ", " - ").replace(":", "");
				var variables = new HashMap<string, string>();
				variables.set("root", Collection.instance.root);
				variables.set("game", g);
				variables.set("platform_name", platform == null ? "." : platform.name());
				variables.set("platform", platform == null ? "." : platform.id());
				return FS.expand(instance.game_dir, null, variables);
			}
			public static string expand_installers(string game, Platform? platform=null)
			{
				var g = game.replace(": ", " - ").replace(":", "");
				var variables = new HashMap<string, string>();
				variables.set("root", Collection.instance.root);
				variables.set("platform_name", platform == null ? "." : platform.name());
				variables.set("platform", platform == null ? "." : platform.id());
				variables.set("game_dir", expand_game_dir(g, platform));
				return FS.expand(instance.installers, null, variables);
			}

			public Humble()
			{
				base(ProjectConfig.PROJECT_NAME + ".paths.collection.humble");
			}

			private static Humble? _instance;
			public static unowned Humble instance
			{
				get
				{
					if(_instance == null)
					{
						_instance = new Humble();
					}
					return _instance;
				}
			}
		}
	}
}
