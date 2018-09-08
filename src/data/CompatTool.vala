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

		public virtual bool can_install(Game game) { return false; }
		public virtual bool can_run(Game game) { return false; }

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
	}
	public static CompatTool[] CompatTools;
}
