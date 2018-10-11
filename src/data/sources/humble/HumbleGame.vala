/*
This file is part of GameHub.
Copyright (C) 2018 Anatoliy Kashkin

GameHub is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

GameHub is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with GameHub.  If not, see <https://www.gnu.org/licenses/>.
*/

using Gee;
using GameHub.Data.DB;
using GameHub.Utils;

namespace GameHub.Data.Sources.Humble
{
	public class HumbleGame: Game
	{
		public string order_id;

		private bool game_info_updated = false;
		private bool game_info_refreshed = false;

		public ArrayList<Game.Installer>? installers { get; protected set; default = new ArrayList<Game.Installer>(); }

		public HumbleGame(Humble src, string order, Json.Node json_node)
		{
			source = src;

			var json_obj = json_node.get_object();

			id = json_obj.get_string_member("machine_name");
			name = json_obj.get_string_member("human_name");
			image = json_obj.get_string_member("icon");
			icon = image;
			order_id = order;

			info = Json.to_string(json_node, false);

			platforms.clear();
			if(json_obj.has_member("downloads") && json_obj.get_member("downloads").get_node_type() == Json.NodeType.ARRAY)
			{
				foreach(var dl in json_obj.get_array_member("downloads").get_elements())
				{
					var pl = dl.get_object().get_string_member("platform");
					foreach(var p in Platforms)
					{
						if(pl == p.id())
						{
							platforms.add(p);
						}
					}
				}
			}

			install_dir = FSUtils.file(FSUtils.Paths.Humble.Games, escaped_name);
			executable = FSUtils.file(install_dir.get_path(), "start.sh");
			info_detailed = @"{\"order\":\"$(order_id)\"}";
			update_status();
		}

		public HumbleGame.from_db(Humble src, Sqlite.Statement s)
		{
			source = src;
			id = Tables.Games.ID.get(s);
			name = Tables.Games.NAME.get(s);
			info = Tables.Games.INFO.get(s);
			info_detailed = Tables.Games.INFO_DETAILED.get(s);
			icon = Tables.Games.ICON.get(s);
			image = Tables.Games.IMAGE.get(s);
			install_dir = FSUtils.file(Tables.Games.INSTALL_PATH.get(s)) ?? FSUtils.file(FSUtils.Paths.Humble.Games, escaped_name);
			executable = FSUtils.file(Tables.Games.EXECUTABLE.get(s)) ?? FSUtils.file(install_dir.get_path(), "start.sh");
			compat_tool = Tables.Games.COMPAT_TOOL.get(s);
			compat_tool_settings = Tables.Games.COMPAT_TOOL_SETTINGS.get(s);
			arguments = Tables.Games.ARGUMENTS.get(s);

			platforms.clear();
			var pls = Tables.Games.PLATFORMS.get(s).split(",");
			foreach(var pl in pls)
			{
				foreach(var p in Platforms)
				{
					if(pl == p.id())
					{
						platforms.add(p);
						break;
					}
				}
			}

			tags.clear();
			var tag_ids = (Tables.Games.TAGS.get(s) ?? "").split(",");
			foreach(var tid in tag_ids)
			{
				foreach(var t in Tables.Tags.TAGS)
				{
					if(tid == t.id)
					{
						if(!tags.contains(t)) tags.add(t);
						break;
					}
				}
			}

			var json = Parser.parse_json(info_detailed).get_object();
			order_id = json.get_string_member("order");
			update_status();
		}

		public override void update_status()
		{
			if(status.state == Game.State.DOWNLOADING && status.download.status.state != Downloader.DownloadState.CANCELLED) return;

			status = new Game.Status(executable.query_exists() ? Game.State.INSTALLED : Game.State.UNINSTALLED);
			if(status.state == Game.State.INSTALLED)
			{
				remove_tag(Tables.Tags.BUILTIN_UNINSTALLED);
				add_tag(Tables.Tags.BUILTIN_INSTALLED);
			}
			else
			{
				add_tag(Tables.Tags.BUILTIN_UNINSTALLED);
				remove_tag(Tables.Tags.BUILTIN_INSTALLED);
			}
		}

		public override async void update_game_info()
		{
			update_status();

			if((icon == null || icon == "") && (info != null && info.length > 0))
			{
				var i = Parser.parse_json(info).get_object();
				icon = i.get_string_member("icon");
			}

			if(image == null || image == "")
			{
				image = icon;
			}

			if(game_info_updated) return;

			if(info == null || info.length == 0)
			{
				var token = ((Humble) source).user_token;

				var headers = new HashMap<string, string>();
				headers["Cookie"] = @"$(Humble.AUTH_COOKIE)=\"$(token)\";";

				var root_node = yield Parser.parse_remote_json_file_async(@"https://www.humblebundle.com/api/v1/order/$(order_id)?ajax=true", "GET", null, headers);
				if(root_node == null || root_node.get_node_type() != Json.NodeType.OBJECT) return;
				var root = root_node.get_object();
				if(root == null) return;
				var products = root.get_array_member("subproducts");
				if(products == null) return;
				foreach(var product_node in products.get_elements())
				{
					if(product_node.get_object().get_string_member("machine_name") != id) continue;
					info = Json.to_string(product_node, false);
					break;
				}
			}

			if(installers.size > 0) return;

			var product = Parser.parse_json(info).get_object();
			if(product == null) return;

			if(product.has_member("_gamehub_description"))
			{
				description = product.get_string_member("_gamehub_description");
			}

			if(product.has_member("downloads") && product.get_member("downloads").get_node_type() == Json.NodeType.ARRAY)
			{
				foreach(var dl_node in product.get_array_member("downloads").get_elements())
				{
					var dl = dl_node.get_object();
					var id = dl.get_string_member("machine_name");
					var dl_id = dl.has_member("download_identifier") ? dl.get_string_member("download_identifier") : null;
					var os = dl.get_string_member("platform");
					var platform = CurrentPlatform;
					foreach(var p in Platforms)
					{
						if(os == p.id())
						{
							platform = p;
							break;
						}
					}

					bool refresh = false;

					if(dl.has_member("download_struct") && dl.get_member("download_struct").get_node_type() == Json.NodeType.ARRAY)
					{
						foreach(var dls_node in dl.get_array_member("download_struct").get_elements())
						{
							var installer = new Installer(this, id, dl_id, platform, dls_node.get_object());
							if(installer.is_url_update_required())
							{
								if(source is Trove)
								{
									var old_url = installer.part.url;
									var new_url = installer.update_url(this);
									if(new_url != null)
									{
										info = info.replace(old_url, new_url);
									}
									refresh = true;
								}
								else
								{
									info = null;
									refresh = true;
								}
							}
							if(!refresh) installers.add(installer);
						}
					}

					if(refresh && !game_info_refreshed)
					{
						debug("[HumbleGame.update_game_info] Refreshing");
						game_info_refreshed = true;
						game_info_updated = false;
						installers.clear();
						yield update_game_info();
						return;
					}
				}
			}

			save();

			update_status();

			game_info_updated = true;
		}

		public override async void install()
		{
			yield update_game_info();

			if(installers.size < 1) return;

			var wnd = new GameHub.UI.Dialogs.GameInstallDialog(this, installers);

			wnd.cancelled.connect(() => Idle.add(install.callback));

			wnd.install.connect((installer, tool) => {
				FSUtils.mkdir(FSUtils.Paths.Humble.Games);
				FSUtils.mkdir(installer.parts.get(0).local.get_parent().get_path());

				installer.install.begin(this, tool, (obj, res) => {
					installer.install.end(res);
					update_status();
					Idle.add(install.callback);
				});
			});

			wnd.import.connect(() => {
				import();
				Idle.add(install.callback);
			});

			wnd.show_all();
			wnd.present();

			yield;
		}

		public override async void uninstall()
		{
			if(executable.query_exists())
			{
				FSUtils.rm(install_dir.get_path(), "", "-rf");
				update_status();
			}
			if(!install_dir.query_exists() && !executable.query_exists())
			{
				install_dir = FSUtils.file(FSUtils.Paths.GOG.Games, escaped_name);
				executable = FSUtils.file(install_dir.get_path(), "start.sh");
				save();
				update_status();
			}
		}

		public class Installer: Game.Installer
		{
			public string dl_name;
			public string? dl_id;
			public Game.Installer.Part part;

			public override string name { get { return dl_name; } }

			public Installer(HumbleGame game, string machine_name, string? download_identifier, Platform platform, Json.Object download)
			{
				id = machine_name;
				this.platform = platform;
				this.dl_id = download_identifier;
				dl_name = download.has_member("name") ? download.get_string_member("name") : "";
				var url_obj = download.has_member("url") ? download.get_object_member("url") : null;
				var url = url_obj != null && url_obj.has_member("web") ? url_obj.get_string_member("web") : "";
				full_size = download.has_member("file_size") ? download.get_int_member("file_size") : 0;
				var remote = File.new_for_uri(url);
				var installers_dir = FSUtils.Paths.Collection.Humble.expand_installers(game.name);
				var local = FSUtils.file(installers_dir, "humble_" + game.id + "_" + id);
				part = new Game.Installer.Part(id, url, full_size, remote, local);
				parts.add(part);
			}

			public bool is_url_update_required()
			{
				if(part.url == null || part.url.length == 0) return true;
				if(!part.url.contains("&ttl=")) return false;
				var ttl_string = part.url.split("&ttl=")[1].split("&")[0];
				var ttl = new DateTime.from_unix_utc(int64.parse(ttl_string));
				var now = new DateTime.now_utc();
				var res = ttl.compare(now);
				return res != 1;
			}

			public string? update_url(HumbleGame game)
			{
				if(!(game.source is Trove) || !is_url_update_required()) return null;

				debug("[HumbleGame.Installer.update_url] Old URL: '%s'; (%s)", part.url, game.full_id);
				var new_url = Trove.sign_url(id, dl_id, ((Humble) game.source).user_token);
				debug("[HumbleGame.Installer.update_url] New URL: '%s'; (%s)", new_url, game.full_id);

				if(new_url != null) part.url = new_url;

				return new_url;
			}
		}
	}
}
