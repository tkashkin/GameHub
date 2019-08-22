using Gee;

namespace GameHub.Data.Sources.Itch
{
	public class Itch: GameSource
	{
        public static Itch instance;
		private ButlerDaemon butler_daemon;
		private ButlerConnection butler_connection = null;

		public Itch()
		{
			instance = this;
			butler_daemon = new ButlerDaemon();
        }

		public override string id { get { return "itch"; } }
		public override string name { get { return "Itch.io"; } }
		public override string icon { get { return "source-itch-symbolic"; } }
		public override string auth_description
		{
			owned get
			{
                return "";
			}
		}

		public int? user_id;
		public string? user_name;

		public override bool enabled
		{
			get { return true; }
			set { }
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
			yield ensure_butler_connection();

			string api_key = Settings.Auth.Itch.instance.api_key;
			yield butler_connection.login_with_api_key(api_key, out user_name, out user_id);
            return true;
		}

		public override bool is_authenticated()
		{
			return user_id != null;
		}

		public override bool can_authenticate_automatically()
		{
            return true;
		}

        private ArrayList<Game> _games = new ArrayList<Game>(null);

		public override ArrayList<Game> games { get { return _games; } }

		public override async ArrayList<Game> load_games(Utils.FutureResult2<Game, bool>? game_loaded=null, Utils.Future? cache_loaded=null)
		{
			yield ensure_butler_connection();
			ArrayList<Json.Node> items = yield butler_connection.get_owned_keys(user_id, true);

			_games.clear();
			_games.add_all_iterator(items.map<Game>((node) => {
				return new ItchGame(this, node);
			}));
            return _games;
		}

		async void ensure_butler_connection()
		{
			if(butler_connection == null) {
				butler_connection = yield create_butler_connection();
			}
		}

        async ButlerConnection create_butler_connection()
        {
            string address;
            string secret;
            yield butler_daemon.get_credentials(out address, out secret);

            ButlerConnection butler_connection = new ButlerConnection(address);
            yield butler_connection.authenticate(secret);

            return butler_connection;
        }
    }
}
