using Gtk;
using Gee;
using GameHub.Utils;

namespace GameHub.Data.Sources.Humble
{
	public class Humble: GameSource
	{
		public const string AUTH_COOKIE = "_simpleauth_sess";
		
		public override string name { get { return "Humble Bundle"; } }
		public override string icon { get { return "humble"; } }

		public override bool enabled
		{
			get { return Settings.Auth.Humble.get_instance().enabled; }
			set { Settings.Auth.Humble.get_instance().enabled = value; }
		}
		
		public string? user_token = null;
		
		private Settings.Auth.Humble settings;
		
		public Humble()
		{
			settings = Settings.Auth.Humble.get_instance();
			var access_token = settings.access_token;
			if(access_token.length > 0)
			{
				user_token = access_token;
			}
		}

		public override bool is_installed(bool refresh)
		{
			return true;
		}

		public override async bool install()
		{
			return true;
		}
		
		public override async bool authenticate()
		{
			settings.authenticated = true;
			
			return yield get_token();
		}
		
		public override bool is_authenticated()
		{
			return user_token != null;
		}
		
		public override bool can_authenticate_automatically()
		{
			return user_token != null && settings.authenticated;
		}
		
		private async bool get_token()
		{
			if(user_token != null)
			{
				return true;
			}
			
			var wnd = new GameHub.UI.Windows.WebAuthWindow(this.name, "https://www.humblebundle.com/login?goto=home", "https://www.humblebundle.com/home/library", AUTH_COOKIE);
			
			wnd.finished.connect(token =>
			{
				user_token = token.replace("\"", "");
				settings.access_token = user_token ?? "";
				debug("[Auth] Humble access token: %s", user_token);
				Idle.add(get_token.callback);
			});
			
			wnd.canceled.connect(() => Idle.add(get_token.callback));
			
			wnd.show_all();
			wnd.present();
			
			yield;
			
			return user_token != null;
		}

		private ArrayList<Game> games = new ArrayList<Game>(Game.is_equal);
		public override async ArrayList<Game> load_games(FutureResult<Game>? game_loaded = null)
		{
			if(user_token == null || games.size > 0)
			{
				return games;
			}
			
			games.clear();
			
			var cached = GamesDB.get_instance().get_games(this);
			if(cached.size > 0)
			{
				games = cached;
				if(game_loaded != null)
				{
					foreach(var g in cached)
					{
						game_loaded(g);
					}
				}
			}
			games_count = games.size;
			
			var headers = new HashMap<string, string>();
			headers["Cookie"] = @"$(AUTH_COOKIE)=\"$(user_token)\";";
			
			var orders = (yield Parser.parse_remote_json_file_async("https://www.humblebundle.com/api/v1/user/order?ajax=true", "GET", null, headers)).get_array();
			
			foreach(var order in orders.get_elements())
			{
				var key = order.get_object().get_string_member("gamekey");
				
				var root = (yield Parser.parse_remote_json_file_async(@"https://www.humblebundle.com/api/v1/order/$(key)?ajax=true", "GET", null, headers)).get_object();
				var products = root.get_array_member("subproducts");
				
				foreach(var product in products.get_elements())
				{
					var game = new HumbleGame(this, key, product.get_object());
					if(!games.contains(game) && yield game.is_for_linux())
					{
						games.add(game);
						if(game_loaded != null) game_loaded(game);
						GamesDB.get_instance().add_game(game);
					}
					games_count = games.size;
				}
			}
			
			return games;
		}
	}
}
