/*
This file is part of GameHub.
Copyright (C) Anatoliy Kashkin

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
using GameHub.Data.Runnables;
using GameHub.Data.Runnables.Tasks.Install;
using GameHub.Data.Tweaks;

using GameHub.Utils;
using GameHub.Utils.FS;

namespace GameHub.Data.Sources.Humble
{
	public class HumbleGame: Game,
		Traits.HasExecutableFile, Traits.SupportsCompatTools,
		Traits.Game.SupportsOverlays, Traits.Game.SupportsTweaks
	{
		// Traits.HasExecutableFile
		public override string? executable_path { owned get; set; }
		public override string? work_dir_path { owned get; set; }
		public override string? arguments { owned get; set; }
		public override string? environment { owned get; set; }

		// Traits.SupportsCompatTools
		public override string? compat_tool { get; set; }
		public override string? compat_tool_settings { get; set; }

		// Traits.Game.SupportsOverlays
		public override ArrayList<Traits.Game.SupportsOverlays.Overlay> overlays { get; set; default = new ArrayList<Traits.Game.SupportsOverlays.Overlay>(); }
		protected override FSOverlay? fs_overlay { get; set; }
		protected override string? fs_overlay_last_options { get; set; }

		// Traits.Game.SupportsTweaks
		public override TweakSet? tweaks { get; set; default = null; }

		public string order_id;

		private bool game_info_updating = false;
		private bool game_info_updated = false;

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
			executable_path = "${install_dir}/start.sh";
			work_dir_path = "${install_dir}";
			info_detailed = @"{\"order\":\"$(order_id)\"}";

			init_tweaks();

			mount_overlays.begin();
			update_status();
		}

		public HumbleGame.from_db(Humble src, Sqlite.Statement s)
		{
			source = src;

			dbinit(s);
			dbinit_executable(s);
			dbinit_compat(s);
			dbinit_tweaks(s);

			var json_node = Parser.parse_json(info_detailed);
			if(json_node != null && json_node.get_node_type() == Json.NodeType.OBJECT)
			{
				var json = json_node.get_object();
				if(json.has_member("order"))
				{
					order_id = json.get_string_member("order");
				}
			}

			mount_overlays.begin();
			update_status();
		}

		public override void update_status()
		{
			if(status.state == Game.State.DOWNLOADING && status.download.status.state != Downloader.Download.State.CANCELLED) return;

			var state = Game.State.UNINSTALLED;
			var files = new ArrayList<File>();
			files.add(get_file(@".gamehub_$(id)"));
			files.add(executable);

			foreach(var file in files)
			{
				if(file != null && file.query_exists())
				{
					state = Game.State.INSTALLED;
					break;
				}
			}

			status = new Game.Status(state, this);
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

			load_version();
		}

		public override async void update_game_info()
		{
			if(game_info_updating) return;
			game_info_updating = true;

			yield remount_overlays();
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

				var root_node = yield Parser.parse_remote_json_file_async(@"https://humblebundle.com/api/v1/order/$(order_id)?ajax=true", "GET", null, headers);
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

		public override async ArrayList<Tasks.Install.Installer>? load_installers()
		{
			if(installers != null && installers.size > 0) return installers;

			installers = new ArrayList<Runnables.Tasks.Install.Installer>();

			var product_node = Parser.parse_json(info);
			if(product_node == null || product_node.get_node_type() != Json.NodeType.OBJECT) return installers;

			var product = product_node.get_object();
			if(product == null) return installers;

			if(product.has_member("downloads"))
			{
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
									add_installer(id, dl_id, os, dls_node.get_object());
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
							add_installer(id, dl_id, os, dl);
						}
						break;
				}
			}

			is_installable = installers.size > 0;

			return installers;
		}

		private void add_installer(string id, string? dl_id, string os, Json.Object dl_struct)
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
			installers.add(new Installer(this, id, dl_id, platform, dl_struct));
		}

		private void update_installer_url(string old_url, string new_url)
		{
			var url_field = "\"%s\"";
			info = info.replace(url_field.printf(old_url), url_field.printf(new_url));
			save();
		}

		public override async void run(){ yield run_executable(); }

		public override async void uninstall()
		{
			if(install_dir != null && install_dir.query_exists())
			{
				yield umount_overlays();
				FS.rm(install_dir.get_path(), "", "-rf");
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

		public class Installer: Runnables.Tasks.Install.DownloadableInstaller
		{
			public HumbleGame game { get; construct set; }
			public Json.Object json { get; construct set; }
			public string? download_identifier { private get; construct set; }
			public DownloadableInstaller.Part? part { private get; construct set; }

			public Installer(HumbleGame game, string machine_name, string? download_identifier, Platform platform, Json.Object json)
			{
				Object(
					game: game,
					json: json,
					id: machine_name,
					download_identifier: download_identifier,
					name: json.has_member("name") ? json.get_string_member("name") : game.name,
					platform: platform,
					full_size: json.has_member("file_size") ? json.get_int_member("file_size") : 0,
					installers_dir: FS.file(Settings.Paths.Collection.Humble.expand_installers(game.name, platform))
				);
			}

			public override async void fetch_parts()
			{
				if(part != null || installers_dir == null) return;

				var url_obj = json.has_member("url") ? json.get_object_member("url") : null;
				var url = url_obj != null && url_obj.has_member("web") ? url_obj.get_string_member("web") : "";

				string? hash = null;
				ChecksumType hash_type = ChecksumType.MD5;

				if(json.has_member("md5"))
				{
					hash = json.get_string_member("md5");
					hash_type = ChecksumType.MD5;
				}
				else if(json.has_member("sha1"))
				{
					hash = json.get_string_member("sha1");
					hash_type = ChecksumType.SHA1;
				}
				else if(json.has_member("sha256"))
				{
					hash = json.get_string_member("sha256");
					hash_type = ChecksumType.SHA256;
				}

				var updated_url = yield update_url(url);

				var remote = File.new_for_uri(updated_url);
				var local = installers_dir.get_child(download_identifier ?? "humble_" + game.id + "_" + id);

				part = new Part(id, updated_url, full_size, remote, local, hash, hash_type);
				parts.add(part);
			}

			private bool is_url_update_required(string url)
			{
				if(url == null || url.length == 0 || url.has_prefix("humble-trove-unsigned://")) return true;
				if(!url.contains("&ttl=")) return false;
				var ttl_string = url.split("&ttl=")[1].split("&")[0];
				var ttl = new DateTime.from_unix_utc(int64.parse(ttl_string));
				var now = new DateTime.now_utc();
				var res = ttl.compare(now);
				return res != 1;
			}

			private async string? update_url(string? url)
			{
				if(!is_url_update_required(url)) return url;

				if(game.source is Trove)
				{
					var new_url = yield Trove.sign_url(id, download_identifier, ((Humble) game.source).user_token);

					if(GameHub.Application.log_verbose)
					{
						debug("[HumbleGame.Installer.update_url] Old URL: '%s'; (%s)", url, game.full_id);
						debug("[HumbleGame.Installer.update_url] New URL: '%s'; (%s)", new_url, game.full_id);
					}

					if(new_url != null)
					{
						game.update_installer_url(url, new_url);
						return new_url;
					}
					else
					{
						Utils.notify(
							_("%s: no available installers").printf(game.name),
							_("Cannot get Trove download URL.\nMake sure your subscription is active."),
							NotificationPriority.HIGH,
							n => {
								n.set_icon(new ThemedIcon("dialog-warning"));
								var cached_icon = ImageCache.local_file(game.icon, @"$(game.source.id)/$(game.id)/icons/");
								if(cached_icon != null && cached_icon.query_exists())
								{
									n.set_icon(new FileIcon(cached_icon));
								}
								return n;
							}
						);
					}
				}
				else
				{
					var token = ((Humble) game.source).user_token;
					var headers = new HashMap<string, string>();
					headers["Cookie"] = @"$(Humble.AUTH_COOKIE)=\"$(token)\";";
					var root_node = yield Parser.parse_remote_json_file_async(@"https://humblebundle.com/api/v1/order/$(game.order_id)?ajax=true", "GET", null, headers);
					if(root_node == null || root_node.get_node_type() != Json.NodeType.OBJECT) return url;
					var root = root_node.get_object();
					if(root == null) return url;
					var products = root.get_array_member("subproducts");
					if(products == null) return url;
					foreach(var product_node in products.get_elements())
					{
						var product = product_node.get_object();
						if(product == null) continue;

						if(product.get_string_member("machine_name") != game.id) continue;
						game.info = Json.to_string(product_node, false);
						game.save();

						if(product.has_member("downloads"))
						{
							var downloads_node = product.get_member("downloads");
							if(downloads_node.get_node_type() == Json.NodeType.ARRAY)
							{
								foreach(var dl_node in downloads_node.get_array().get_elements())
								{
									var dl = dl_node.get_object();
									var id = dl.get_string_member("machine_name");
									if(id == this.id)
									{
										if(dl.has_member("download_struct") && dl.get_member("download_struct").get_node_type() == Json.NodeType.ARRAY)
										{
											foreach(var dls_node in dl.get_array_member("download_struct").get_elements())
											{
												var new_url = dls_node.get_object().get_object_member("url").get_string_member("web");
												if(GameHub.Application.log_verbose)
												{
													debug("[HumbleGame.Installer.update_url] Old URL: '%s'; (%s)", url, game.full_id);
													debug("[HumbleGame.Installer.update_url] New URL: '%s'; (%s)", new_url, game.full_id);
												}
												return new_url;
											}
										}
									}
								}
							}
						}
						break;
					}
				}
				return url;
			}
		}
	}
}
