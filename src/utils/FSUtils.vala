using Gtk;
using Gdk;
using GLib;

namespace GameHub.Utils
{
	public class FSUtils
	{
		public class Paths
		{
			public class Settings: Granite.Services.Settings
			{
				public string steam_home { get; set; }
				public string gog_games { get; set; }

				public Settings()
				{
					base(ProjectConfig.PROJECT_NAME + ".paths");
				}
			
				private static Settings? instance;
				public static unowned Settings get_instance()
				{
					if(instance == null)
					{
						instance = new Settings();
					}
					return instance;
				}
			}
			
			public class Cache
			{
				public const string Home = "~/.cache/com.github.tkashkin.gamehub";
				
				public const string Cookies = FSUtils.Paths.Cache.Home + "/cookies";
				public const string Images = FSUtils.Paths.Cache.Home + "/images";
				
				public const string GamesDB = FSUtils.Paths.Cache.Home + "/games.db";
			}
			
			public class Steam
			{
				public static string Home { get { return FSUtils.Paths.Settings.get_instance().steam_home; } }
				public static string Config { owned get { return FSUtils.Paths.Steam.Home + "/steam/config"; } }
				public static string LoginUsersVDF { owned get { return FSUtils.Paths.Steam.Config + "/loginusers.vdf"; } }
				
				public static string SteamApps { owned get { return FSUtils.Paths.Steam.Home + "/steam/steamapps"; } }
				public static string LibraryFoldersVDF { owned get { return FSUtils.Paths.Steam.SteamApps + "/libraryfolders.vdf"; } }
			}
			
			public class GOG
			{
				public const string Installers = FSUtils.Paths.Cache.Home + "/gog/installers";
				public static string Games { get { return FSUtils.Paths.Settings.get_instance().gog_games; } }
			}
		}
		
		public static string expand(string path, string file="")
		{
			return path.replace("~", Environment.get_home_dir()) + (file != "" ? "/" + file : "");
		}
		
		public static File file(string path, string file="")
		{
			return File.new_for_path(FSUtils.expand(path, file));
		}
		
		public static File? mkdir(string path, string file="")
		{
			try
			{
				var dir = FSUtils.file(path, file);
				if(!dir.query_exists()) dir.make_directory_with_parents();
				return dir;
			}
			catch(Error e)
			{
				error(e.message);
			}
			return null;
		}
		
		public static void make_dirs()
		{
			mkdir(FSUtils.Paths.Cache.Home);
			mkdir(FSUtils.Paths.Cache.Images);
			mkdir(FSUtils.Paths.GOG.Installers);
		}
		
		public static Pixbuf? get_icon(string name, int size=48)
		{
			try
			{
				return new Pixbuf.from_resource_at_scale(@"/com/github/tkashkin/gamehub/icons/$(name).svg", size, size, true);
			}
			catch(Error e)
			{
				error(e.message);
			}
			return null;
		}
	}
}
