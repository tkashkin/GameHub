using Gtk;
using GLib;
using Granite;

namespace GameHub.Settings
{
	public enum WindowState
	{
		NORMAL = 0,
		MAXIMIZED = 1,
		FULLSCREEN = 2
	}
	
	public class SavedState: Granite.Services.Settings
	{
		public int window_width { get; set; }
		public int window_height { get; set; }
		public WindowState window_state { get; set; }
		public int window_x { get; set; }
		public int window_y { get; set; }

		public SavedState()
		{
			base(ProjectConfig.PROJECT_NAME + ".saved-state");
		}
		
		private static SavedState? instance;
		public static unowned SavedState get_instance()
		{
			if(instance == null)
			{
				instance = new SavedState();
			}
			return instance;
		}
	}
	
	namespace Auth
	{		
		public class Steam: Granite.Services.Settings
		{
			public bool authenticated { get; set; }

			public Steam()
			{
				base(ProjectConfig.PROJECT_NAME + ".auth.steam");
			}
		
			private static Steam? instance;
			public static unowned Steam get_instance()
			{
				if(instance == null)
				{
					instance = new Steam();
				}
				return instance;
			}
		}
		
		public class GOG: Granite.Services.Settings
		{
			public bool authenticated { get; set; }
			public string access_token { get; set; }
			public string refresh_token { get; set; }

			public GOG()
			{
				base(ProjectConfig.PROJECT_NAME + ".auth.gog");
			}
		
			private static GOG? instance;
			public static unowned GOG get_instance()
			{
				if(instance == null)
				{
					instance = new GOG();
				}
				return instance;
			}
		}
	}
}
