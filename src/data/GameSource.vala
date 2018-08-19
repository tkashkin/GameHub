using Gtk;
using Gee;
using GameHub.Utils;
using GameHub.Data.Sources.Steam;
using GameHub.Data.Sources.GOG;

namespace GameHub.Data
{
	public abstract class GameSource
	{
		public virtual string name { get { return ""; } }
		public virtual string icon { get { return ""; } }
		public virtual string auth_description { owned get { return ""; } }
		
		public abstract bool enabled { get; set; }

		public int games_count { get; protected set; }

		public abstract bool is_installed(bool refresh=false);
		
		public abstract async bool install();
		
		public abstract async bool authenticate();
		public abstract bool is_authenticated();
		public abstract bool can_authenticate_automatically();
		
		public abstract ArrayList<Game> games { get; }

		public abstract async ArrayList<Game> load_games(Utils.FutureResult<Game>? game_loaded=null, Utils.Future? cache_loaded=null);
		
		public static GameSource? by_name(string name)
		{
			foreach(var src in GameSources)
			{
				if(src.name == name) return src;
			}
			return null;
		}
	}
	
	public static GameSource[] GameSources;
}
