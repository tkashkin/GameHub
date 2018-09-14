using GameHub.Utils;

namespace GameHub.Data
{
	public abstract class CompatTool: Object
	{
		public string id { get; protected set; default = "null"; }
		public string name { get; protected set; default = ""; }
		public string icon { get; protected set; default = "application-x-executable-symbolic"; }
		public File? executable { get; protected set; default = null; }
		public bool installed { get; protected set; default = false; }

		public Option[]? options = null;
		public Action[]? actions = null;

		public virtual bool can_install(Game game) { return false; }
		public virtual bool can_run(Game game) { return false; }

		public virtual File get_install_root(Game game) { return game.install_dir; }

		public virtual async void install(Game game, File installer){}
		public virtual async void run(Game game){}

		public class Option: Object
		{
			public string name { get; construct; }
			public string description { get; construct; }
			public bool enabled { get; construct set; }
			public Option(string name, string description, bool enabled)
			{
				Object(name: name, description: description, enabled: enabled);
			}
		}

		public class Action: Object
		{
			public delegate void Delegate(Game game);
			public string name { get; construct; }
			public string description { get; construct; }
			private Delegate action;
			public Action(string name, string description, owned Delegate action)
			{
				Object(name: name, description: description);
				this.action = (owned) action;
			}
			public void invoke(Game game)
			{
				action(game);
			}
		}
	}
	public static CompatTool[] CompatTools;
}
