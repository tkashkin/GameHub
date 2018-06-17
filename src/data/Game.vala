using Gtk;

namespace GameHub.Data
{
	public abstract class Game
	{
		public GameSource source { get; protected set; }
		
		public string id { get; protected set; }
		public string name { get; protected set; }
		
		public string icon { get; protected set; }
		public string image { get; protected set; }
		
		public string custom_info { get; protected set; default = ""; }
		
		public virtual async bool is_for_linux(){ return true; }
		
		public virtual bool is_installed(){ return false; }
		
		public abstract async void install(Utils.DownloadProgress progress = (d, t) => {});
		public abstract async void run();
		
		public static bool is_equal(Game first, Game second)
		{
			return first == second || (first.source == second.source && first.id == second.id);
		}
		
		public abstract class Installer
		{
			public string id { get; protected set; }
			public string os { get; protected set; }
			public string file { get; protected set; }
			
			public virtual string name { get { return id; } }
		}
	}
}
