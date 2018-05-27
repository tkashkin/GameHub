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
		
		public string path { get; protected set; }
		public string command { get; protected set; }
		
		public float playtime { get; protected set; default = 0; }
		
		public virtual async bool is_for_linux(){ return true; }
	}
}
