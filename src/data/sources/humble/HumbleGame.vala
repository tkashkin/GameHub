/*
This file is part of GameHub.
Copyright (C) 2018-2019 Anatoliy Kashkin

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
	public class HumbleGame: Game, TweakableGame
	{
		public string[]? tweaks { get; set; default = null; }

		public string order_id;

		private bool game_info_updating = false;
		private bool game_info_updated = false;
		private bool game_info_refreshed = false;

		public ArrayList<Runnable.Installer>? installers { get; protected set; default = new ArrayList<Runnable.Installer>(); }

		public override File? default_install_dir
		{
			owned get
			{
				return FSUtils.file(FSUtils.Paths.Humble.Games, escaped_name);
			}
		}

		public HumbleGame(Humble src, string order, Json.Node json_node)
		{
			source = src;

			var json_obj = json_node.get_object();

			id = json_obj.get_string_member("machine_name");
			name = json_obj.has_member("human_name") ? json_obj.get_string_member("human_name") : json_obj.get_string_member("human-name");
			image = json_obj.has_member("image") ? json_obj.get_string_member("image") : json_obj.get_string_member("icon");
			icon = json_obj.has_member("icon") ? json_obj.get_string_member("icon") : image;
			order_id = order;

			info = Json.to_string(json_node, false);

			platforms.clear();

			if(json_obj.has_member("downloads"))
			{
				var downloads_node = json_obj.get_member("downloads");
				switch(downloads_node.get_node_type())
				{
					case Json.NodeType.ARRAY:
						foreach(var dl in downloads_node.get_array().get_elements())
						{
							var dl_platform = dl.get_object().get_string_member("platform");
							foreach(var p in Platform.PLATFORMS)
							{
								if(dl_platform == p.id())
								{
									platforms.add(p);
								}
							}
						}
						break;

					case Json.NodeType.OBJECT:
						foreach(var dl_platform in downloads_node.get_object().get_members())
						{
							foreach(var p in Platform.PLATFORMS)
							{
								if(dl_platform == p.id())
								{
									platforms.add(p);
								}
							}
						}
						break;
				}
			}

			install_dir = null;
			executable_path = "$game_dir/start.sh";
			work_dir_path = "$game_dir";
			info_detailed = @"{\"order\":\"$(order_id)\"}";

			mount_overlays.begin();
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
			install_dir = Tables.Games.INSTALL_PATH.get(s) != null ? FSUtils.file(Tables.Games.INSTALL_PATH.get(s)) : null;
			executable_path = Tables.Games.EXECUTABLE.get(s);
			work_dir_path = Tables.Games.WORK_DIR.get(s);
			compat_tool = Tables.Games.COMPAT_TOOL.get(s);
			compat_tool_settings = Tables.Games.COMPAT_TOOL_SETTINGS.get(s);
			arguments = Tables.Games.ARGUMENTS.get(s);
			last_launch = Tables.Games.LAST_LAUNCH.get_int64(s);
			playtime_source = Tables.Games.PLAYTIME_SOURCE.get_int64(s);
			playtime_tracked = Tables.Games.PLAYTIME_TRACKED.get_int64(s);
			image_vertical = Tables.Games.IMAGE_VERTICAL.get(s);

			platforms.clear();
			var pls = Tables.Games.PLATFORMS.get(s).split(",");
			foreach(var pl in pls)
			{
				foreach(var p in Platform.PLATFORMS)
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

			var json_node = Parser.parse_json(info_detailed);
			if(json_node != null && json_node.get_node_type() == Json.NodeType.OBJECT)
			{
				var json = json_node.get_object();
				if(json.has_member("order"))
				{
					order_id = json.get_string_member("order");
				}
			}

			var tweaks_string = Tables.Games.TWEAKS.get(s);
			if(tweaks_string != null)
			{
				tweaks = tweaks_string.split(",");
			}

			mount_overlays.begin();
			update_status();
		}

		public override void update_status()
		{
			if(status.state == Game.State.DOWNLOADING && status.download.status.state != Downloader.Download.State.CANCELLED) return;

			status = new Game.Status(executable != null && executable.query_exists() ? Game.State.INSTALLED : Game.State.UNINSTALLED, this);
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

			installers_dir = FSUtils.file(FSUtils.Paths.Collection.Humble.expand_installers(name));

			update_version();
		}

		public override async void update_game_info() throws Utils.RunError
		{
			if(game_info_updating) return;
			game_info_updating = true;

			yield mount_overlays();
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

			if(game_info_updated)
			{
				game_info_updating = false;
				return;
			}

			if(info == null || info.length == 0)
			{
				var token = ((Humble) source).user_token;

				var headers = new HashMap<string, string>();
				headers["Cookie"] = @"$(Humble.AUTH_COOKIE)=\"$(token)\";";

				var root_node = yield Parser.parse_remote_json_file_async(@"https://www.humblebundle.com/api/v1/order/$(order_id)?ajax=true", "GET", null, headers);
				if(root_node == null || root_node.get_node_type() != Json.NodeType.OBJECT)
				{
					game_info_updating = false;
					return;
				}
				var root = root_node.get_object();
				if(root == null)
				{
					game_info_updating = false;
					return;
				}
				var products = root.get_array_member("subproducts");
				if(products == null)
				{
					game_info_updating = false;
					return;
				}
				foreach(var product_node in products.get_elements())
				{
					if(product_node.get_object().get_string_member("machine_name") != id) continue;
					info = Json.to_string(product_node, false);
					break;
				}
			}

			var product_node = Parser.parse_json(info);
			if(product_node == null || product_node.get_node_type() != Json.NodeType.OBJECT)
			{
				game_info_updating = false;
				return;
			}

			var product = product_node.get_object();
			if(product == null)
			{
				game_info_updating = false;
				return;
			}

			if(product.has_member("description-text"))
			{
				description = product.get_string_member("description-text");
			}
			else if(product.has_member("_gamehub_description"))
			{
				description = product.get_string_member("_gamehub_description");
			}

			save();

			update_status();

			game_info_updated = true;
			game_info_updating = false;
		}

		private async void update_installers() throws Utils.RunError
		{
			if(installers.size > 0) return;

			var product_node = Parser.parse_json(info);
			if(product_node == null || product_node.get_node_type() != Json.NodeType.OBJECT) return;

			var product = product_node.get_object();
			if(product == null) return;

			if(product.has_member("downloads"))
			{
				bool refresh = false;

				var downloads_node = product.get_member("downloads");
				switch(downloads_node.get_node_type())
				{
					case Json.NodeType.ARRAY:
						foreach(var dl_node in downloads_node.get_array().get_elements())
						{
							var dl = dl_node.get_object();
							var id = dl.get_string_member("machine_name");
							var dl_id = dl.has_member("download_identifier") ? dl.get_string_member("download_identifier") : null;
							var os = dl.get_string_member("platform");
							if(dl.has_member("download_struct") && dl.get_member("download_struct").get_node_type() == Json.NodeType.ARRAY)
							{
								foreach(var dls_node in dl.get_array_member("download_struct").get_elements())
								{
									refresh = process_download(id, dl_id, os, dls_node.get_object());
								}
							}
						}
						break;

					case Json.NodeType.OBJECT:
						foreach(var os in downloads_node.get_object().get_members())
						{
							var dl = downloads_node.get_object().get_object_member(os);
							var id = dl.get_string_member("machine_name");
							var dl_id = dl.has_member("download_identifier") ? dl.get_string_member("download_identifier") : null;
							refresh = process_download(id, dl_id, os, dl);
						}
						break;
				}

				if(refresh && !game_info_refreshed)
				{
					game_info_refreshed = true;
					game_info_updated = false;
					installers.clear();
					yield update_game_info();
					yield update_installers();
					return;
				}
			}

			is_installable = installers.size > 0;

			if(installers.size == 0 && source is Trove)
			{
				Utils.notify(
					_("%s: no available installers").printf(name),
					_("Cannot get Trove download URL.\nMake sure your Humble Monthly subscription is active."),
					NotificationPriority.HIGH,
					n => {
						n.set_icon(new ThemedIcon("dialog-warning"));
						var cached_icon = ImageCache.local_file(icon, @"$(source.id)/$(id)/icons/");
						if(cached_icon != null && cached_icon.query_exists())
						{
							n.set_icon(new FileIcon(cached_icon));
						}
						return n;
					}
				);
			}
		}

		private bool process_download(string id, string? dl_id, string os, Json.Object dl_struct)
		{
			var platform = Platform.CURRENT;
			foreach(var p in Platform.PLATFORMS)
			{
				if(os == p.id())
				{
					platform = p;
					break;
				}
			}

			bool refresh = false;

			var installer = new Installer(this, id, dl_id, platform, dl_struct);
			if(installer.is_url_update_required())
			{
				if(source is Trove)
				{
					var old_url = installer.part.url;
					var new_url = installer.update_url(this);
					if(new_url != null)
					{
						var url_field = "\"%s\"";
						info = info.replace(url_field.printf(old_url), url_field.printf(new_url));
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

			return refresh;
		}

		public override async void install(Runnable.Installer.InstallMode install_mode=Runnable.Installer.InstallMode.INTERACTIVE) throws Utils.RunError
		{
			yield update_installers();
			if(installers.size < 1) return;
			new GameHub.UI.Dialogs.InstallDialog(this, installers, install_mode, install.callback);
			yield;
		}

		public override async void uninstall() throws Utils.RunError
		{
			if(install_dir != null && install_dir.query_exists())
			{
				yield umount_overlays();
				FSUtils.rm(install_dir.get_path(), "", "-rf");
				update_status();
				if((install_dir == null || !install_dir.query_exists()) && (executable == null || !executable.query_exists()))
				{
					install_dir = null;
					executable = null;
					save();
					update_status();
				}
			}
		}

		public class Installer: Runnable.DownloadableInstaller
		{
			private File? installers_dir;

			public string dl_name;
			public string? dl_id;
			public Runnable.DownloadableInstaller.Part part;

			public override string name { owned get { return dl_name; } }

			public Installer(HumbleGame game, string machine_name, string? download_identifier, Platform platform, Json.Object download)
			{
				id = machine_name;
				this.platform = platform;
				dl_id = download_identifier;
				dl_name = download.has_member("name") ? download.get_string_member("name") : "";
				var url_obj = download.has_member("url") ? download.get_object_member("url") : null;
				var url = url_obj != null && url_obj.has_member("web") ? url_obj.get_string_member("web") : "";
				full_size = download.has_member("file_size") ? download.get_int_member("file_size") : 0;

				installers_dir = FSUtils.file(FSUtils.Paths.Collection.Humble.expand_installers(game.name, platform)) ?? game.installers_dir;

				if(installers_dir == null) return;

				var remote = File.new_for_uri(url);
				var local = installers_dir.get_child("humble_" + game.id + "_" + id);

				string? hash = null;
				ChecksumType hash_type = ChecksumType.MD5;

				if(download.has_member("md5"))
				{
					hash = download.get_string_member("md5");
					hash_type = ChecksumType.MD5;
				}
				else if(download.has_member("sha1"))
				{
					hash = download.get_string_member("sha1");
					hash_type = ChecksumType.SHA1;
				}
				else if(download.has_member("sha256"))
				{
					hash = download.get_string_member("sha256");
					hash_type = ChecksumType.SHA256;
				}

				part = new Runnable.DownloadableInstaller.Part(id, url, full_size, remote, local, hash, hash_type);
				parts.add(part);
			}

			public bool is_url_update_required()
			{
				if(part.url == null || part.url.length == 0 || part.url.has_prefix("humble-trove-unsigned://")) return true;
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

				var new_url = Trove.sign_url(id, dl_id, ((Humble) game.source).user_token);

				if(GameHub.Application.log_verbose)
				{
					debug("[HumbleGame.Installer.update_url] Old URL: '%s'; (%s)", part.url, game.full_id);
					debug("[HumbleGame.Installer.update_url] New URL: '%s'; (%s)", new_url, game.full_id);
				}

				if(new_url != null) part.url = new_url;

				return new_url;
			}
		}
	}
}
