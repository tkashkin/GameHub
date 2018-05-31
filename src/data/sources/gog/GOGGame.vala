using Gtk;
using GameHub.Utils;

namespace GameHub.Data.Sources.GOG
{
	public class GOGGame: Game
	{
		private bool? _is_for_linux = null;
		
		public GOGGame(GOG src, Json.Object json)
		{
			this.source = src;
			
			this.id = json.get_int_member("id").to_string();
			this.name = json.get_string_member("title");
			
			this.image = "https:" + json.get_string_member("image") + "_392.jpg";
			this.icon = this.image;
			
			this._is_for_linux = json.get_object_member("worksOn").get_boolean_member("Linux");
		}
		
		public async bool is_for_linux()
		{
			return (!) _is_for_linux;
		}
		
		public override async void install(){}
		
		public override async void run(){}
	}
}
