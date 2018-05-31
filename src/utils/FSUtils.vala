using Gtk;
using Gdk;
using GLib;

namespace GameHub.Utils
{
	public class FSUtils
	{
		public class Paths
		{
			public class Cache
			{
				public const string Home = "~/.cache/com.github.tkashkin.gamehub";
				
				public const string Cookies = FSUtils.Paths.Cache.Home + @"/cookies";
				public const string Images = FSUtils.Paths.Cache.Home + @"/images";
			}
			
			public class Steam
			{
				public const string Home = "~/.steam";
				public const string Config = FSUtils.Paths.Steam.Home + "/steam/config";
				public const string ConfigOld = FSUtils.Paths.Steam.Home + "/config";
				public const string LoginUsersVDF = FSUtils.Paths.Steam.Config + @"/loginusers.vdf";
				public const string LoginUsersVDFOld = FSUtils.Paths.Steam.ConfigOld + @"/loginusers.vdf";
				
				public const string SteamApps = FSUtils.Paths.Steam.Home + "/steam/steamapps";
				public const string LibraryFoldersVDF = FSUtils.Paths.Steam.SteamApps + "/libraryfolders.vdf";
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
		
		private static void mkdir(string path, string file="")
		{
			try
			{
				var dir = FSUtils.file(path, file);
				if(!dir.query_exists()) dir.make_directory_with_parents();
			}
			catch(Error e)
			{
				error(e.message);
			}
		}
		
		public static void make_dirs()
		{
			mkdir(FSUtils.Paths.Cache.Home);
			mkdir(FSUtils.Paths.Cache.Images);
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
