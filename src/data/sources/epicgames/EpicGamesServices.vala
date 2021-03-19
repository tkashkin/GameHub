using Gee;

using GameHub.Utils;

using Soup;

namespace GameHub.Data.Sources.EpicGames
{
	//  https://dev.epicgames.com/docs/services/en-US/Interfaces/Auth/EASAuthentication/index.html
	//  https://dev.epicgames.com/docs/services/Images/Interfaces/Auth/EASAuthentication/EGSAuthFlow.webp
	internal class EpicGamesServices
	{
		internal static EpicGamesServices instance;

		//  These are coming from the Epic Launcher
		private const string username = "34a02cf8f4414e29b15921876da36f9a";
		private const string password = "daafbccc737745039dffe53d94fc76cf";

		private const string oauth_host = "account-public-service-prod03.ol.epicgames.com";
		private const string launcher_host = "launcher-public-service-prod06.ol.epicgames.com";
		private const string entitlements_host = "entitlement-public-service-prod08.ol.epicgames.com";
		private const string catalog_host = "catalog-public-service-prod06.ol.epicgames.com";
		private const string ecommerce_host = "ecommerceintegration-public-service-ecomprod02.ol.epicgames.com";
		private const string datastorage_host = "datastorage-public-service-liveegs.live.use1a.on.epicgames.com";
		private const string library_host = "library-service.live.use1a.on.epicgames.com";

		//  TODO: hardcoded for now
		private string language_code = "en";
		private string country_code = "US";

		//  used with session, does not include user-agent as that's already set for the session
		private HashMap<string, string> auth_headers = new HashMap<string, string>();
		//  does not include auth header so it can be used with access token for e.g. Utils.Parser
		private HashMap<string, string> unauth_headers = new HashMap<string, string>();

		private Session session = new Session();
		private string user_agent = "UELauncher/11.0.1-14907503+++Portal+Release-Live Windows/10.0.19041.1.256.64bit";

		internal EpicGamesServices()
		{
			instance = this;

			session.user_agent = user_agent;
			unauth_headers.set("User-Agent",
			                   user_agent);
		}

		internal Json.Node start_session(string? refresh_token = null,
		                                 string? exchange_code = null)
		{
			var form_data = new HashTable<string, string>(null,
			                                              null);

			if(refresh_token != null)
			{
				form_data.set("grant_type",
				              "refresh_token");
				form_data.set("refresh_token",
				              refresh_token);
				form_data.set("token_type",
				              "eg1");
			}
			else if(exchange_code != null)
			{
				form_data.set("grant_type",
				              "exchange_code");
				form_data.set("exchange_code",
				              exchange_code);
				form_data.set("token_type",
				              "eg1");
			}
			else
			{
				return_if_reached();
			}

			var message = Form.request_new_from_hash("POST",
			                                         @"https://$oauth_host/account/api/oauth/token",
			                                         form_data);

			message.request_headers.append("Authorization",
			                               "Basic " + Base64.encode((username + ":" + password).data));

			var status = session.send_message(message);

			assert(status < 500);

			var json = Parser.parse_json((string) message.response_body.data);

			if(GameHub.Application.log_auth)
			{
				debug("[start_session] " + Json.to_string(json,
				                                          true));
			}

			//  invalid userdata
			assert(json.get_node_type() == Json.NodeType.OBJECT);
			assert(!json.get_object().has_member("error"));

			auth_headers.set("Authorization",
			                 "Bearer %s".printf(json.get_object().get_string_member("access_token")));

			return json;

			//  {
			//  	"access_token": "eg1~eyJraWQ…fUL5uprW9D1dvIOfLcvME",
			//  	"expires_in": 28800,
			//  	"expires_at": "2021-02-09T23:17:40.545Z",
			//  	"token_type": "bearer",
			//  	"refresh_token": "eg1~eyJraWQ…9bepwb_5ihPp4zUqypGK",
			//  	"refresh_expires": 1987200,
			//  	"refresh_expires_at": "2021-03-04T15:17:40.545Z",
			//  	"account_id": "1b2a9…5b74bd2d7c",
			//  	"client_id": "34a02c…6da36f9a",
			//  	"internal_client": true,
			//  	"client_service": "launcher",
			//  	"displayName": "asdasd",
			//  	"app": "launcher",
			//  	"in_app_id": "1b2a9…5b74bd2d7c",
			//  	"device_id": "3b61f…905003dc"
			//  }
		}

		internal Json.Node resume_session(Json.Node userdata)
		requires(userdata.get_node_type() == Json.NodeType.OBJECT)
		{
			var refreshed_json = Parser.parse_remote_json_file(
				@"https://$oauth_host/account/api/oauth/verify",
				"GET",
				EpicGames.instance.access_token,
				unauth_headers);

			if(GameHub.Application.log_auth)
			{
				debug("[resume_session] downloaded json " + Json.to_string(refreshed_json,
				                                                           true));
			}

			assert(refreshed_json.get_node_type() == Json.NodeType.OBJECT);
			assert(!refreshed_json.get_object().has_member("error"));
			assert(!refreshed_json.get_object().has_member("errorMessage"));

			refreshed_json.get_object().foreach_member(
				(object, name, node) => {
				userdata.get_object().set_member(name,
				                                 node);
			});

			if(GameHub.Application.log_auth)
			{
				debug("[resume_session] updated userdata " + Json.to_string(userdata,
				                                                            true));
			}

			auth_headers.set("Authorization",
			                 "Bearer %s".printf(refreshed_json.get_object().get_string_member("access_token")));

			return userdata;

			//  {
			//  	"token": "eg1~eyJraWQiOiB…PvnPW6aj8l6",
			//  	"session_id": "22ed94dfc…e618bf",
			//  	"token_type": "bearer",
			//  	"client_id": "34a02…6f9a",
			//  	"internal_client": true,
			//  	"client_service": "launcher",
			//  	"account_id": "1b2a94d…d2d7c",
			//  	"expires_in": 28799,
			//  	"expires_at": "2021-02-10T09:15:48.157Z",
			//  	"auth_method": "exchange_code",
			//  	"display_name": "asdasd",
			//  	"app": "launcher",
			//  	"in_app_id": "1b2a94d…d7c",
			//  	"device_id": "3b61f…003dc"
			//  }
		}

		internal void invalidate_session()
		{
			var message = new Message("DELETE",
			                          @"https://$oauth_host/account/api/oauth/sessions/kill/$(EpicGames.instance.access_token)");
			auth_headers.foreach(header => {
				message.request_headers.append(header.key,
				                               header.value);

				return true;
			});

			session.send_message(message);
			auth_headers.unset("Authorization");
		}

		internal Json.Node get_game_token()
		{
			uint status;
			var json = Parser.parse_remote_json_file(
				@"https://$oauth_host/account/api/oauth/exchange",
				"GET",
				EpicGames.instance.access_token,
				unauth_headers,
				null,
				out status);
			assert(status < 400);

			if(log_epic_games_services) debug("[Sources.EpicGames.EpicGamesServices.get_game_token]: \n%s", Json.to_string(json, true));

			return json;
		}

		internal Bytes get_ownership_token(string ns,
		                                   string catalog_item_id)
		{
			var data = new HashMap<string, string>();
			var multipart = new Multipart("multipart/form-data");

			var message = new Message(
				"POST",
				@"https://$ecommerce_host/ecommerceintegration/api/public/" +
				@"platforms/EPIC/identities/$(EpicGames.instance.user_id)/ownershipToken");

			data.set("nsCatalogItemId",
			         @"$ns:$catalog_item_id");
			auth_headers.foreach(header => {
				message.request_headers.append(header.key,
				                               header.value);

				return true;
			});

			foreach(var v in data.entries)
			{
				multipart.append_form_string(v.key,
				                             v.value);
			}

			multipart.to_message(message.request_headers,
			                     message.request_body);

			var status = session.send_message(message);
			assert(status < 400);

			return new Bytes(message.response_body.data);
		}

		internal Json.Node get_game_assets(string platform = "Windows",
		                                   string label = "Live")
		{
			uint status;
			var json = Parser.parse_remote_json_file(
				@"https://$launcher_host/launcher/api/public/assets/$platform?label=$label",
				"GET",
				EpicGames.instance.access_token,
				unauth_headers,
				null,
				out status);

			if(log_epic_games_services) debug("Game assets: %s", Json.to_string(json, true));

			assert(status < 400);

			return json;
		}

		internal Json.Node get_game_manifest(string ns,
		                                     string catalog_item_id,
		                                     string app_name,
		                                     string platform = "Windows",
		                                     string label = "Live")
		{
			uint status;
			var json = Parser.parse_remote_json_file(
				@"https://$launcher_host/launcher/api/public/assets/v2/platform" +
				@"/$platform/namespace/$ns/catalogItem/$catalog_item_id/app" +
				@"/$app_name/label/$label",
				"GET",
				EpicGames.instance.access_token,
				unauth_headers,
				null,
				out status);

			if(log_epic_games_services) debug("[Sources.EpicGames.EpicGamesServices.get_game_manifest] json dump:\n%s", Json.to_string(json, true));

			assert(status < 400);

			return json;
		}

		internal void get_user_entitlements() {}

		internal Json.Node get_game_info(string _namespace,
		                                 string catalog_item_id)
		{
			uint status;

			Gee.HashMap<string, string> data = new Gee.HashMap<string, string>();
			data.set("id",
			         catalog_item_id);
			data.set("includeDLCDetails",
			         "True");
			data.set("includeMainGameDetails",
			         "True");
			data.set("country",
			         country_code);
			data.set("locale",
			         language_code);

			var json = Parser.parse_remote_json_file(
				@"https://$catalog_host/catalog/api/shared/namespace/$_namespace/bulk/items
				?id=$catalog_item_id
				&includeDLCDetails=True
				&includeMainGameDetails=True
				&country=$country_code
				&locale=$language_code",
				"GET",
				EpicGames.instance.access_token,
				unauth_headers,
				null,
				out status);

			if(log_epic_games_services) debug("[Source.EpicGames.EpicGamesServices.get_game_info] json dump: \n%s", Json.to_string(json, true));

			assert(status < 400);

			return json.get_object().get_member(catalog_item_id);
		}

		internal void get_library_items() {}

		internal Json.Node get_user_cloud_saves(string  game_id = "",
		                                        bool    manifests = false,
		                                        string? filenames = null)
		{
			var app_name = game_id;

			if(app_name.length > 0 && manifests)
			{
				app_name += "/manifests/";
			}
			else if(app_name.length > 0)
			{
				app_name += "/";
			}

			Json.Node json;
			uint status;
			string method = "GET";
			HashMap<string, string> data = null;

			if(filenames != null && filenames.length > 0)
			{
				method = "POST";
				data = new HashMap<string, string>();
				data.set("files",
				         filenames);
			}

			json = Parser.parse_remote_json_file(
				@"https://$datastorage_host/api/v1/access/egstore/savesync/" +
				@"$(EpicGames.instance.user_id)/$app_name",
				method,
				EpicGames.instance.access_token,
				auth_headers,
				data,
				out status);
			assert(status < 400);
			assert(json.get_node_type() != Json.NodeType.NULL);

			return json;
		}

		internal Json.Node create_game_cloud_saves(string game_id,
		                                           string filenames) { return get_user_cloud_saves(game_id,
			                                                                                   false,
			                                                                                   filenames); }

		internal void delete_game_cloud_save_files(string path)
		{
			var message = new Message("DELETE",
			                          @"https://$datastorage_host/api/v1/data/egstore/$path");
			auth_headers.foreach(header => {
				message.request_headers.append(header.key,
				                               header.value);

				return true;
			});

			var status = session.send_message(message);
			assert(status < 400);
		}

		internal void get_cdn_manifest(string    url,
		                               out Bytes data)
		{
			debug("[Sources.EpicGames.get_cdn_manifest] Downloading manifest from: %s…",
			      url);
			var message = new Message("GET",
			                          url);

			//  unauth on purpose
			var status = session.send_message(message);
			assert(status < 400);
			data = new Bytes(message.response_body.data);
		}

		/**
		 * Get optimized delta manifest (doesn't seem to exist for most games)
		 */
		internal Bytes? get_delta_manifest(string url,
		                                   string old_build_id,
		                                   string new_build_id)
		{
			if(old_build_id == new_build_id) return null;

			var message = new Message("GET",
			                          @"$url/Deltas/$new_build_id/$old_build_id.delta");

			//  unauth on purpose
			var status = session.send_message(message);

			return_val_if_fail(status == 200,
			                   null);

			return new Bytes(message.request_body.data);
		}

		//  TODO: fetch descriptions etc
		//  https://github.com/SD4RK/epicstore_api/blob/master/epicstore_api/api.py#L72
		//  https://store-content.ak.epicgames.com/api/de/content/products/rocket-league
		//  https://store-content.ak.epicgames.com/api/content/productmapping
	}
}
