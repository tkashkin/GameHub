using Gee;
using Soup;
using WebKit;

using GameHub.Data.DB;
using GameHub.Data.Runnables;
//  using GameHub.Data.Tweaks;
using GameHub.Utils;

namespace GameHub.Data.Sources.EpicGames
{
	internal bool log_chunk               = false;
	internal bool log_chunk_part          = false;
	internal bool log_chunk_data_list     = false;
	internal bool log_epic_games_services = false;
	internal bool log_file_manifest_list  = false;
	internal bool log_manifest            = false;
	internal bool log_meta                = false;

	public class EpicGames: GameSource
	{
		public static EpicGames instance;

		private Settings.Auth.EpicGames settings;

		private Json.Node? userdata { get; default = new Json.Node(Json.NodeType.NULL); }

		public override string          id          { get { return "epicgames"; } }
		public override string          name        { get { return "EpicGames"; } }
		public override string          icon        { get { return "source-epicgames-symbolic"; } }
		public override ArrayList<Game> games       { get; default = new ArrayList<Game>(Game.is_equal); }

		public override bool enabled
		{
			get { return Settings.Auth.EpicGames.instance.enabled; }
			set { Settings.Auth.EpicGames.instance.enabled = value; }
		}

		public string? user_name
		{
			get
			{
				return_val_if_fail(userdata.get_object().has_member("displayName"), null);

				return userdata.get_object().get_string_member("displayName");
			}
		}

		internal string? access_token
		{
			get
			{
				return_val_if_fail(userdata.get_node_type() == Json.NodeType.OBJECT, null);
				return_val_if_fail(userdata.get_object().has_member("access_token"), null);
				return_val_if_fail(userdata.get_object().get_member("access_token").get_node_type() == Json.NodeType.VALUE, null);

				return userdata.get_object().get_string_member("access_token");
			}
		}

		internal string user_id
		{
			get
			{
				assert(userdata.get_node_type() == Json.NodeType.OBJECT);
				assert(userdata.get_object().has_member("account_id"));

				return userdata.get_object().get_string_member("account_id");
			}
		}

		private ArrayList<EpicGame.Asset> _assets = new ArrayList<EpicGame.Asset>(EpicGame.Asset.is_equal);
		private ArrayList<EpicGame.Asset> assets
		{
			get
			{
				if(_assets.is_empty)
				{
					//  read from cache
					var json = Parser.parse_json_file(FS.Paths.EpicGames.Cache, "assets.json");

					if(json.get_node_type() == Json.NodeType.ARRAY)
					{
						json.get_array().foreach_element((array, index, node) => {
							var asset = new EpicGame.Asset.from_json(node);

							//  debug("loaded asset: " + asset.to_string(true));
							if(!_assets.contains(asset))
							{
								_assets.add(asset);
							}
						});
					}
				}

				return _assets;
			}
			set
			{
				_assets = value;

				//  save to cache
				FS.mkdir(FS.Paths.EpicGames.Cache);
				var json = new Json.Node(Json.NodeType.ARRAY);
				json.set_array(new Json.Array());
				_assets.foreach(asset => {
					json.get_array().add_object_element(asset.to_json().get_object());

					return true;
				});

				write(FS.Paths.EpicGames.Cache,
				      "assets.json",
				      Json.to_string(json, true).data);
			}
		}

		public EpicGames()
		{
			instance  = this;
			settings  = Settings.Auth.EpicGames.instance;
			_userdata = Parser.parse_json(settings.userdata);

			//  Session we're using to access the api
			new EpicGamesServices();
		}

		public override bool is_installed(bool refresh = false)
		{
			//  Internal, this source is always installed
			return true;
		}

		public override async bool install()
		{
			//  Internal, this source is always installed
			return true;
		}

		public override bool is_authenticated()
		{
			return_val_if_fail(userdata.get_node_type() == Json.NodeType.OBJECT, false);

			if(!userdata.get_object().has_member("access_token")) return false;

			if(!userdata.get_object().has_member("expires_at")) return false;

			var now            = new DateTime.now_local();
			var access_expires = new DateTime.from_iso8601(userdata.get_object().get_string_member("expires_at"), null);

			if(access_expires.difference(now) < TimeSpan.MINUTE * 10)
			{
				if(Application.log_auth) debug("[Sources.EpicGames.is_authenticated] Access token is less than 10 minutes valid.");

				return false;
			}

			return access_token != null && access_token.length > 0;
		}

		public override bool can_authenticate_automatically()
		{
			return_val_if_fail(userdata.get_node_type() == Json.NodeType.OBJECT, false);

			if(!userdata.get_object().has_member("refresh_token")) return false;

			if(!userdata.get_object().has_member("refresh_expires_at")) return false;

			var now             = new DateTime.now_local();
			var refresh_expires = new DateTime.from_iso8601(userdata.get_object().get_string_member("refresh_expires_at"), null);

			if(refresh_expires.difference(now) < TimeSpan.MINUTE * 10)
			{
				debug("[Sources.EpicGames.can_authenticate_automatically] Refresh token is less than 10 minutes valid.");

				return false;
			}

			return userdata.get_object().get_string_member_with_default("refresh_token", "") != "" && settings.authenticated;
		}

		public override async bool authenticate()
		{
			settings.authenticated = true;

			if(is_authenticated()) return true;

			if(can_authenticate_automatically())
			{
				_userdata         = EpicGamesServices.instance.start_session(userdata.get_object().get_string_member("refresh_token"));
				settings.userdata = Json.to_string(userdata, false);

				return is_authenticated();
			}

			var wnd = new GameHub.UI.Windows.WebAuthWindow(
				this.name,
				"https://www.epicgames.com/id/login?redirectUrl=https%3A%2F%2Fwww.epicgames.com%2Fid%2Fapi%2Fredirect",
				"https://www.epicgames.com/id/api/redirect",
				null);

			wnd.finished.connect(() =>
			{
				wnd.webview.web_context.get_cookie_manager().get_cookies.begin(
					"https://www.epicgames.com",
					null,
					(obj, res) => {
					try
					{
						var webview_cookies        = wnd.webview.web_context.get_cookie_manager().get_cookies.end(res);
						SList<Soup.Cookie> cookies = new SList<Soup.Cookie>();

						webview_cookies.foreach(cookie => {
							cookies.append(cookie);
						});

						authenticate_with_exchange_code(authenticate_with_sid(cookies));
					}
					catch (Error e) {}

					Idle.add(authenticate.callback);
				});
			});

			wnd.canceled.connect(() => Idle.add(authenticate.callback));

			wnd.set_size_request(640, 800); // FIXME: Doesn't work?
			wnd.show_all();
			wnd.present();

			yield;

			settings.userdata = Json.to_string(userdata, false);

			return is_authenticated();
		}

		public async bool logout()
		{
			EpicGamesServices.instance.invalidate_session();

			_userdata              = new Json.Node(Json.NodeType.NULL);
			settings.userdata      = Json.to_string(userdata, false);
			settings.authenticated = false;

			//  invalidate webkit session to allow logging in with a different account
			#if WEBKIT2GTK
			try
			{
				var webview = new WebView();

				var cookies_file = FS.expand(FS.Paths.Cache.Cookies);
				webview.web_context.get_cookie_manager().set_persistent_storage(cookies_file, CookiePersistentStorage.TEXT);

				var website_data = yield webview.get_website_data_manager().fetch(WebsiteDataTypes.COOKIES);
				foreach(var website in website_data)
				{
					if(website.get_name() == "epicgames.com")
					{
						var list = new GLib.List<WebsiteData>();
						list.append(website);

						if(yield webview.get_website_data_manager().remove(WebsiteDataTypes.COOKIES, list))
						{
							debug("[Sources.EpicGames.logout] Deleted cookies for: %s", website.get_name());
						}
					}
				}
			}
			catch (Error e) {}
			#endif

			return true;
		}

		public override async ArrayList<Game> load_games(Utils.FutureResult2<Game, bool>? game_loaded  = null,
		                                                 Utils.Future?                    cache_loaded = null)
		{
			if(!is_authenticated() || _games.size > 0)
			{
				return games;
			}

			Utils.thread("EpicGamesLoading",
			             () =>
			{
				_games.clear();

				var cached  = Tables.Games.get_all(this);
				games_count = 0;

				if(cached.size > 0)
				{
					foreach(var g in cached)
					{
						if(g.platforms.size == 0) continue;

						if(!Settings.UI.Behavior.instance.merge_games || !Tables.Merges.is_game_merged(g))
						{
							_games.add(g);

							if(game_loaded != null)
							{
								game_loaded(g, true);
							}
						}

						games_count++;
					}
				}

				if(cache_loaded != null)
				{
					cache_loaded();
				}

				var owned_games = get_game_and_dlc_list(true);

				owned_games.foreach(tuple =>
				{
					var game = tuple.value;
					bool is_new_game = !_games.contains(game);

					if(is_new_game && (!Settings.UI.Behavior.instance.merge_games || !Tables.Merges.is_game_merged(game)))
					{
						_games.add(game);

						if(game_loaded != null)
						{
							game_loaded(game, false);
						}
					}

					if(is_new_game)
					{
						games_count++;
						game.save();
					}

					return true;
				});

				Idle.add(load_games.callback);
			});

			yield;

			return games;
		}

		public override ArrayList<File>? game_dirs
		{
			owned get
			{
				ArrayList<File>? dirs = null;

				var paths = GameHub.Settings.Paths.EpicGames.instance.game_directories;

				if(paths != null && paths.length > 0)
				{
					foreach(var path in paths)
					{
						if(path != null && path.length > 0)
						{
							var dir = FS.file(path);

							if(dir != null)
							{
								if(dirs == null) dirs = new ArrayList<File>();

								dirs.add(dir);
							}
						}
					}
				}

				return dirs;
			}
		}

		public override File? default_game_dir
		{
			owned get
			{
				var path = GameHub.Settings.Paths.EpicGames.instance.default_game_directory;

				if(path != null && path.length > 0)
				{
					var dir = FS.file(path);

					if(dir != null && dir.query_exists())
					{
						return dir;
					}
				}

				var dirs = game_dirs;

				if(dirs != null && dirs.size > 0)
				{
					return dirs.first();
				}

				return null;
			}
		}

		//  Legendary core replication ==============================================================

		public string authenticate_with_sid(SList<Soup.Cookie> cookies)
		{
			var session = new Session();
			session.timeout            = 5;
			session.max_conns          = 256;
			session.max_conns_per_host = 256;

			//  FIXME: header setting looks ugly
			debug("[Sources.EpicGames.LegendaryCore.with_sid] Getting xsrf");
			var message = new Message("GET", "https://www.epicgames.com/id/api/csrf");
			message.request_headers.append("X-Epic-Event-Action", "login");
			message.request_headers.append("X-Epic-Event-Category", "login");
			message.request_headers.append("X-Epic-Strategy-Flags", "");
			message.request_headers.append("X-Requested-With", "XMLHttpRequest");
			message.request_headers.append("User-Agent",
			                               "Mozilla/5.0 (Windows NT 10.0; Win64; x64) " +
			                               "AppleWebKit/537.36 (KHTML, like Gecko) " +
			                               "EpicGamesLauncher/11.0.1-14907503+++Portal+Release-Live " +
			                               "UnrealEngine/4.23.0-14907503+++Portal+Release-Live " +
			                               "Chrome/84.0.4147.38 Safari/537.36");
			cookies_to_request(cookies, message);
			var status = session.send_message(message);
			debug("[Sources.EpicGames.LegendaryCore.with_sid] Status: %s", status.to_string());
			assert(status == 204);

			debug("[Sources.EpicGames.LegendaryCore.with_sid] Getting exchange code");
			var cookies_from_response = cookies_from_response(message);
			message = new Message("POST", "https://www.epicgames.com/id/api/exchange/generate");
			message.request_headers.append("X-Epic-Event-Action", "login");
			message.request_headers.append("X-Epic-Event-Category", "login");
			message.request_headers.append("X-Epic-Strategy-Flags", "");
			message.request_headers.append("X-Requested-With", "XMLHttpRequest");
			message.request_headers.append("User-Agent",
			                               "Mozilla/5.0 (Windows NT 10.0; Win64; x64) " +
			                               "AppleWebKit/537.36 (KHTML, like Gecko) " +
			                               "EpicGamesLauncher/11.0.1-14907503+++Portal+Release-Live " +
			                               "UnrealEngine/4.23.0-14907503+++Portal+Release-Live " +
			                               "Chrome/84.0.4147.38 Safari/537.36");
			cookies_to_request(cookies, message);
			cookies_to_request(cookies_from_response, message);

			cookies_from_response.foreach(cookie => {
				if(cookie.get_name() == "XSRF-TOKEN")
				{
					message.request_headers.append("X-XSRF-TOKEN", cookie.get_value());
				}
			});

			status = session.send_message(message);
			debug("[Sources.EpicGames.LegendaryCore.with_sid] Status: %s", status.to_string());
			assert(status == 200);

			var json = Parser.parse_json((string) message.response_body.data);

			if(GameHub.Application.log_auth)
			{
				debug(Json.to_string(json, true));
			}

			assert(json.get_node_type() == Json.NodeType.OBJECT);
			assert(json.get_object().has_member("code"));

			var exchange_code = json.get_object().get_string_member("code");

			if(GameHub.Application.log_auth)
			{
				debug("[Sources.EpicGames.LegendaryCore.with_sid] EGS exchange_code: %s",
				      exchange_code);
			}

			return exchange_code;
		}

		public void authenticate_with_exchange_code(string exchange_code)
		{
			assert(exchange_code != "");

			_userdata = EpicGamesServices.instance.start_session(null, exchange_code);

			return;
		}

		//  public bool login()
		//  {
		//  	return_val_if_fail(userdata.get_node_type() == Json.NodeType.OBJECT, false);
		//  	return_val_if_fail(userdata.get_object().has_member("expires_at"), false);
		//  	return_val_if_fail(userdata.get_object().has_member("refresh_expires_at"), false);

		//  	var now = new DateTime.now_local();
		//  	var access_expires = new DateTime.from_iso8601(userdata.get_object().get_string_member("expires_at"), null);
		//  	var refresh_expires = new DateTime.from_iso8601(userdata.get_object().get_string_member("refresh_expires_at"), null);

		//  	if(access_expires.difference(now) > TimeSpan.MINUTE * 10)
		//  	{
		//  		debug("[Sources.EpicGames.login] Trying to re-use existing login session…");
		//  		_userdata = EpicGamesServices.instance.resume_session(userdata, access_token);

		//  		return_val_if_fail(userdata.get_node_type() == Json.NodeType.OBJECT, false);
		//  		return_val_if_fail(userdata.get_object().has_member("access_token"), false);

		//  		return userdata.get_object().get_string_member("access_token") != "";
		//  	}

		//  	if(refresh_expires.difference(now) > TimeSpan.MINUTE * 10)
		//  	{
		//  		return_val_if_fail(userdata.get_object().has_member("refresh_token"), false);

		//  		debug("[Sources.EpicGames.login] Logging in…");
		//  		var refresh_token = userdata.get_object().get_string_member("refresh_token");

		//  		_userdata = EpicGamesServices.instance.start_session(refresh_token, null);

		//  		return_val_if_fail(userdata.get_node_type() == Json.NodeType.OBJECT, false);
		//  		return_val_if_fail(userdata.get_object().has_member("access_token"), false);

		//  		return userdata.get_object().get_string_member("access_token") != "";
		//  	}

		//  	//  TODO: invalidate
		//  	_userdata = new Json.Node(Json.NodeType.OBJECT);
		//  	userdata.set_object(new Json.Object());
		//  	settings.userdata = Json.to_string(userdata, false);

		//  	return false;
		//  }

		public ArrayList<EpicGame.Asset> get_game_assets(bool    update_assets     = false,
		                                                 string? platform_override = null)
		{
			if(platform_override != null && access_token != null && access_token.length > 0)
			{
				var list       = new ArrayList<EpicGame.Asset>();
				var games_json = EpicGamesServices.instance.get_game_assets(access_token, platform_override);

				games_json.get_array().foreach_element((array, index, node) => {
					assert(node.get_node_type() == Json.NodeType.OBJECT);
					var asset = new EpicGame.Asset.from_egs_json(node);
					list.add(asset);
				});

				return list;
			}


			if(update_assets || assets.is_empty && access_token != null && access_token.length > 0)
			{
				var games_json = EpicGamesServices.instance.get_game_assets(access_token);

				games_json.get_array().foreach_element((array, index, node) => {
					assert(node.get_node_type() == Json.NodeType.OBJECT);
					var asset = new EpicGame.Asset.from_egs_json(node);

					if(!assets.contains(asset))
					{
						assets.add(asset);
					}
					else
					{
						assets.set(assets.index_of(asset), asset);
					}
				});
			}

			return assets;
		}

		public EpicGame.Asset? get_game_asset(string id, bool update = false)
		{
			if(update)
			{
				assets = get_game_assets(update);
			}

			foreach(var asset in assets)
			{
				if(asset.asset_id == id)
				{
					return asset;
				}
			}

			return null;
		}

		public void asset_valid() {}

		public EpicGame? get_game(string id, bool update_meta = false)
		{
			if(update_meta)
			{
				var owned_games = get_game_and_dlc_list(true);

				_games.foreach(game => {
					if(owned_games.has_key(game.id))
					{
						game = owned_games.get(game.id);
						owned_games.unset(game.id);
					}

					return true;
				});

				if(!owned_games.is_empty)
				{
					_games.add_all(owned_games.values);
				}
			}

			return (EpicGame) _games.first_match(game => {
				return game.id == id;
			});
		}

		//  Not needed, dlcs are always bound to games
		//  public void get_game_list() {}

		public HashMap<string, EpicGame> get_game_and_dlc_list(bool    update_assets      = true,
		                                                       string? platform_override  = null,
		                                                       bool    skip_unreal_engine = true)
		{
			HashMap<string, EpicGame> owned_games = new HashMap<string, EpicGame>();

			//  I don't really need the inner HashMap - a list of tuples would be enough.
			//  Vala should be able to handle tuples but I couldn't figure it out
			var dlcs = new HashMap<string, HashMap<EpicGame.Asset, Json.Node?> >();

			var tmp_assets = get_game_assets(update_assets, platform_override);
			foreach(var asset in tmp_assets)
			{
				Json.Node? metadata = null;

				if(asset.ns == "ue" && skip_unreal_engine) continue;

				var game = get_game(asset.app_name);

				if(update_assets && (game == null || (game != null
				                                      && game.version != asset.build_version
				                                      && platform_override != null)))
				{
					if(game != null
					   && game.version != asset.build_version
					   && platform_override != null)
					{
						debug("[LegendaryCore] Updating meta information for %s due to build version mismatch",
						      asset.app_name);
					}

					metadata = EpicGamesServices.instance.get_game_info(asset.ns, asset.catalog_item_id);
					assert(metadata.get_node_type() == Json.NodeType.OBJECT);

					//  var title = metadata.get_object().get_string_member_with_default("title", "");
					game = new EpicGame(EpicGames.instance, asset, metadata);

					//  if(platform_override == null) game.save_metadata();
				}

				//  replace asset info with the platform specific one if override is used
				//  FIXME: do we want this?
				//  if(platform_override != null)
				//  {
				//  	game.version = asset.build_version;
				//  	game.asset_info = asset;
				//  }

				if(game.is_dlc)
				{
					var json = Parser.parse_json(game.info_detailed);
					return_val_if_fail(json.get_node_type() == Json.NodeType.OBJECT, false);

					var main_id = json.get_object().get_object_member("mainGameItem").get_string_member("id");

					//  add later when we got all games
					var tmp = dlcs.get(main_id);

					if(tmp == null)
					{
						tmp = new HashMap<EpicGame.Asset, Json.Node?>();
					}

					tmp.set(asset, metadata);
					dlcs.set(main_id, tmp);
				}
				else
				{
					owned_games.set(game.id, game);
				}

				//  TODO: mods?
			}

			//  we got all games, add the dlcs to it
			foreach(var game_name in dlcs)
			{
				if(game_name.value == null) continue;

				foreach(var tuple in game_name.value)
				{
					var game = owned_games.get(game_name.key);
					game.add_dlc(tuple.key, tuple.value);
				}
			}

			return owned_games;
		}

		public void get_dlc_for_game() {}
		public void get_installed_list() {}
		public void get_installed_dlc_list() {}
		public void get_installed_game() {}
		//  public void get_save_games() {}
		//  public void get_save_path() {}
		//  public void check_savegame_state() {}
		//  public void upload_save() {}
		//  public void download_saves() {}
		public void is_offline_game() {}
		public void is_noupdate_game() {}
		public void is_latest() {}
		public void is_game_installed() {}
		public void is_dlc() {}

		internal static Manifest? load_manifest(Bytes data)
		{
			//  FIXME: ugly json detection?
			if(data[0] == '{')
			{
				return new Manifest.from_json(Parser.parse_json((string) data.get_data()));
			}

			return new Manifest.from_bytes(data);
		}

		public void get_uri_manifest() {}
		public static void check_installation_conditions() {}
		public void get_default_install_dir() {}

		//  public Json.Node install_game(EpicGame game)
		//  {
		//  	//  TODO: EGL stuff?
		//  	//  if(egl_sync_enabled && !game.is_dlc)
		//  	//  {
		//  	//  if(game.egl_guid != null)
		//  	//  {
		//  	//  	game.egl_guid = uuid4.replace("-", "").up();
		//  	//  }
		//  	//  var prereq = _install_game(game);
		//  	//  egl_export(game.id);
		//  	//  return prereq;
		//  	//  else
		//  	//  {
		//  	return _install_game(game);
		//  	//  }
		//  }

		//  Save game metadata and info to mark it "installed" and also show the user the prerequisites
		//  private Json.Node _install_game(EpicGame game)
		//  {
		//  	//  set_installed_game(game.id, game);
		//  	//  installed_games.set(game.id, game);
		//  	if(game.prereq_info != null)
		//  	{
		//  		if(game.prereq_info.get_object().has_member("installed")
		//  		   && game.prereq_info.get_object().get_boolean_member_with_default("installed", false))
		//  		{
		//  			return game.prereq_info;
		//  		}
		//  	}
		//  	var node = new Json.Node(Json.NodeType.OBJECT);
		//  	node.set_object(new Json.Object());
		//  	return node;
		//  }

		//  private void set_installed_game(string id, EpicGame game)
		//  {
		//  	installed_games.set(id, game);
		//  	write to file
		//  }

		public void uninstall_tag() {}
		public void prereq_installed() {}

		//  TODO: EGL stuff?
	}
}
