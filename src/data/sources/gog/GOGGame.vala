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

namespace GameHub.Data.Sources.GOG
{
	public class GOGGame: Game, TweakableGame
	{
		public string[]? tweaks { get; set; default = null; }

		public ArrayList<Runnable.Installer>? installers { get; protected set; default = new ArrayList<Runnable.Installer>(); }
		public ArrayList<BonusContent>? bonus_content { get; protected set; default = new ArrayList<BonusContent>(); }
		public ArrayList<DLC>? dlc { get; protected set; default = new ArrayList<DLC>(); }

		public File? bonus_content_dir { get; protected set; default = null; }

		public bool has_updates { get; set; default = false; }

		public override File? default_install_dir
		{
			owned get
			{
				return FSUtils.file(FSUtils.Paths.GOG.Games, escaped_name);
			}
		}

		private bool game_info_updating = false;
		private bool game_info_updated = false;

		public GOGGame.default(){}

		public GOGGame(GOG src, Json.Node json_node)
		{
			source = src;

			var json_obj = json_node.get_object();

			id = json_obj.get_int_member("id").to_string();
			name = json_obj.get_string_member("title");
			icon = "";

			if(json_obj.has_member("image"))
			{
				image = "https:" + json_obj.get_string_member("image") + "_392.jpg";
			}

			info = Json.to_string(json_node, false);

			var worksOn = json_obj != null && json_obj.has_member("worksOn") ? json_obj.get_object_member("worksOn") : null;
			if(worksOn != null && worksOn.get_boolean_member("Linux")) platforms.add(Platform.LINUX);
			if(worksOn != null && worksOn.get_boolean_member("Windows")) platforms.add(Platform.WINDOWS);
			if(worksOn != null && worksOn.get_boolean_member("Mac")) platforms.add(Platform.MACOS);

			var tags_json = !json_obj.has_member("tags") ? null : json_obj.get_array_member("tags");
			if(tags_json != null)
			{
				foreach(var tag_json in tags_json.get_elements())
				{
					var tid = source.id + ":" + tag_json.get_string();
					foreach(var t in Tables.Tags.TAGS)
					{
						if(tid == t.id)
						{
							if(!tags.contains(t)) tags.add(t);
							break;
						}
					}
				}
			}

			has_updates = json_obj.has_member("updates") && json_obj.get_int_member("updates") > 0;

			install_dir = null;
			executable_path = "$game_dir/start.sh";
			work_dir_path = "$game_dir";

			mount_overlays.begin();
			update_status();
		}

		public GOGGame.from_db(GOG src, Sqlite.Statement s)
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

			var tweaks_string = Tables.Games.TWEAKS.get(s);
			if(tweaks_string != null)
			{
				tweaks = tweaks_string.split(",");
			}

			mount_overlays.begin();
			update_status();
		}

		public override async void update_game_info() throws Utils.RunError
		{
			if(game_info_updating) return;
			game_info_updating = true;

			yield mount_overlays();
			update_status();

			if(info_detailed == null || info_detailed.length == 0)
			{
				var lang = Intl.setlocale(LocaleCategory.ALL, null).down().substring(0, 2);
				var url = @"https://api.gog.com/products/$(id)?expand=downloads,description,expanded_dlcs" + (lang != null && lang.length > 0 ? "&locale=" + lang : "");

				while(true)
				{
					uint status = 0;
					var json = (yield Parser.load_remote_file_async(url, "GET", ((GOG) source).user_token, null, null, out status));

					if(status == Soup.Status.OK && json != null && json.length > 0)
					{
						info_detailed = json;
						break;
					}
					else if(status == Soup.Status.UNAUTHORIZED)
					{
						yield ((GOG) source).refresh_token();
					}
					else break;
				}
			}

			var root = Parser.parse_json(info_detailed);

			var images = Parser.json_object(root, {"images"});
			var desc = Parser.json_object(root, {"description"});
			var links = Parser.json_object(root, {"links"});

			if(image == null || image == "")
			{
				var i = Parser.parse_json(info).get_object();
				image = "https:" + i.get_string_member("image") + "_392.jpg";
			}

			if((icon == null || icon == "") && (images != null && images.has_member("icon")))
			{
				icon = images.get_string_member("icon");
				if(icon != null) icon = "https:" + icon;
				else icon = image;
			}

			is_installable = root != null && root.get_node_type() == Json.NodeType.OBJECT
				&& root.get_object().has_member("is_installable") && root.get_object().get_boolean_member("is_installable");

			if(desc != null)
			{
				description = desc.get_string_member("full");
				var cool = desc.get_string_member("whats_cool_about_it");
				if(cool != null && cool.length > 0)
				{
					description += "<ul>";
					var cool_parts = cool.split("\n");
					foreach(var part in cool_parts)
					{
						part = part.strip();
						if(part.length > 0)
						{
							description += "<li>" + part + "</li>";
						}
					}
					description += "</ul>";
				}
			}

			if(links != null)
			{
				store_page = links.get_string_member("product_card");
			}

			var downloads = Parser.json_object(root, {"downloads"});

			var installers_json = downloads == null || !downloads.has_member("installers") ? null : downloads.get_array_member("installers");
			if(installers_json != null && installers.size == 0)
			{
				foreach(var installer_json in installers_json.get_elements())
				{
					var installer = new Installer(this, installer_json.get_object());
					installers.add(installer);
				}
			}

			if(installers.size == 0)
			{
				is_installable = false;
			}

			var bonuses_json = downloads == null || !downloads.has_member("bonus_content") ? null : downloads.get_array_member("bonus_content");
			if(bonuses_json != null && bonus_content.size == 0)
			{
				Json.Object? bonus_map = null;

				if(bonus_content_dir != null && bonus_content_dir.query_exists())
				{
					var map_file = bonus_content_dir.get_child(BonusContent.FILEMAP_NAME);
					if(map_file != null && map_file.query_exists())
					{
						var map_root_node = Parser.parse_json_file(map_file.get_path());
						bonus_map = map_root_node != null && map_root_node.get_node_type() == Json.NodeType.OBJECT ? map_root_node.get_object() : null;
					}
				}

				foreach(var bonus_json in bonuses_json.get_elements())
				{
					bonus_content.add(new BonusContent(this, bonus_json.get_object(), bonus_map));
				}
			}

			var dlcs_json = root == null || root.get_node_type() != Json.NodeType.OBJECT || !root.get_object().has_member("expanded_dlcs") ? null : root.get_object().get_array_member("expanded_dlcs");
			if(dlcs_json != null && dlc.size == 0)
			{
				foreach(var dlc_json in dlcs_json.get_elements())
				{
					var d = new GOGGame.DLC(this, dlc_json);
					dlc.add(d);
					yield d.update_downloads_info();
				}
			}

			root = Parser.parse_json(info);

			var tags_json = root == null || root.get_node_type() != Json.NodeType.OBJECT || !root.get_object().has_member("tags") ? null : root.get_object().get_array_member("tags");

			if(tags_json != null)
			{
				foreach(var tag_json in tags_json.get_elements())
				{
					var tid = source.id + ":" + tag_json.get_string();
					foreach(var t in Tables.Tags.TAGS)
					{
						if(tid == t.id)
						{
							if(!tags.contains(t)) tags.add(t);
							break;
						}
					}
				}
			}

			save();

			update_status();

			game_info_updated = true;
			game_info_updating = false;
		}

		public override async void install(Runnable.Installer.InstallMode install_mode=Runnable.Installer.InstallMode.INTERACTIVE) throws Utils.RunError
		{
			yield update_game_info();
			if(installers == null || installers.size < 1) return;
			new GameHub.UI.Dialogs.InstallDialog(this, installers, install_mode, install.callback);
			yield;
		}

		public override async void uninstall() throws Utils.RunError
		{
			if(install_dir != null && install_dir.query_exists())
			{
				string? uninstaller = null;
				try
				{
					FileInfo? finfo = null;
					var enumerator = yield install_dir.enumerate_children_async("standard::*", FileQueryInfoFlags.NONE);
					while((finfo = enumerator.next_file()) != null)
					{
						if(finfo.get_name().has_prefix("uninstall-"))
						{
							uninstaller = finfo.get_name();
							break;
						}
					}
				}
				catch(Error e){}

				yield umount_overlays();

				if(uninstaller != null)
				{
					uninstaller = FSUtils.expand(install_dir.get_path(), uninstaller);
					debug("[GOGGame] Running uninstaller '%s'...", uninstaller);
					yield Utils.run({uninstaller, "--noprompt", "--force"}).override_runtime(true).run_sync_thread();
				}
				else
				{
					FSUtils.rm(install_dir.get_path(), "", "-rf");
				}
				update_status();
			}
			if((install_dir == null || !install_dir.query_exists()) && (executable == null || !executable.query_exists()))
			{
				install_dir = null;
				executable = null;
				save();
				update_status();
			}
		}

		public override void update_status()
		{
			if(status.state == Game.State.DOWNLOADING && status.download.status.state != Downloader.Download.State.CANCELLED) return;

			var state = Game.State.UNINSTALLED;

			var gameinfo = get_file("gameinfo", false);
			var goggame = get_file(@"goggame-$(id).info");
			var gh_marker = get_file(@".gamehub_$(id)");

			var files = new ArrayList<File>();

			files.add(goggame);
			files.add(gh_marker);

			if(!(this is DLC))
			{
				files.add(executable);
				files.add(gameinfo);
			}

			foreach(var file in files)
			{
				if(file != null && file.query_exists())
				{
					state = Game.State.INSTALLED;
					break;
				}
			}

			status = new Game.Status(state, this);
			if(state == Game.State.INSTALLED)
			{
				remove_tag(Tables.Tags.BUILTIN_UNINSTALLED);
				add_tag(Tables.Tags.BUILTIN_INSTALLED);
			}
			else
			{
				add_tag(Tables.Tags.BUILTIN_UNINSTALLED);
				remove_tag(Tables.Tags.BUILTIN_INSTALLED);
			}

			if(gameinfo != null && gameinfo.query_exists())
			{
				try
				{
					string info;
					FileUtils.get_contents(gameinfo.get_path(), out info);
					var lines = info.split("\n");
					if(lines.length >= 2)
					{
						version = lines[1];
					}
				}
				catch(Error e)
				{
					warning("[GOGGame.update_status] Error while reading gameinfo: %s", e.message);
				}
			}
			else
			{
				update_version();
			}

			actions.clear();
			if(goggame != null && goggame.query_exists())
			{
				var goggame_node = Parser.parse_json_file(goggame.get_path());
				if(goggame_node != null && goggame_node.get_node_type() == Json.NodeType.OBJECT)
				{
					var goggame_obj = goggame_node.get_object();
					var tasks = goggame_obj.has_member("playTasks") ? goggame_obj.get_array_member("playTasks") : null;
					if(tasks != null)
					{
						foreach(var task_node in tasks.get_elements())
						{
							if(task_node == null || task_node.get_node_type() != Json.NodeType.OBJECT) continue;
							var action = new RunnableAction(this, task_node.get_object());
							if(!action.is_hidden)
							{
								actions.add(action);
							}
						}
					}
				}
			}

			string g = name;
			string? d = null;
			if(this is DLC)
			{
				g = (this as DLC).game.name;
				d = name;
			}
			installers_dir = FSUtils.file(FSUtils.Paths.Collection.GOG.expand_installers(g, d));
			bonus_content_dir = FSUtils.file(FSUtils.Paths.Collection.GOG.expand_bonus(g, d));
		}

		private bool loading_achievements = false;
		public override async ArrayList<Game.Achievement>? load_achievements()
		{
			if(achievements != null || loading_achievements || source == null || ((GOG) source).user_id == null)
			{
				return achievements;
			}

			loading_achievements = true;

			Json.Node? root = null;
			Json.Object? root_obj = null;

			while(true)
			{
				var url = "https://gameplay.gog.com/clients/%s/users/%s/achievements".printf(id, ((GOG) source).user_id);
				uint status = 0;

				root = (yield Parser.parse_remote_json_file_async(url, "GET", ((GOG) source).user_token, null, null, out status));
				root_obj = root != null && root.get_node_type() == Json.NodeType.OBJECT ? root.get_object() : null;

				if(status == Soup.Status.UNAUTHORIZED)
				{
					yield ((GOG) source).refresh_token();
				}
				else break;
			}

			if(root_obj == null || !root_obj.has_member("items"))
			{
				loading_achievements = false;
				return null;
			}

			var achievements_array = root_obj.get_array_member("items");

			var _achievements = new ArrayList<Game.Achievement>();

			foreach(var a_node in achievements_array.get_elements())
			{
				var a_obj = a_node != null && a_node.get_node_type() == Json.NodeType.OBJECT
					? a_node.get_object() : null;

				if(a_obj == null || !a_obj.has_member("achievement_key")) continue;

				var a_id                  = a_obj.get_string_member("achievement_key");
				var a_name                = a_obj.has_member("name") ? a_obj.get_string_member("name") : a_id;
				var a_desc                = a_obj.has_member("description") ? a_obj.get_string_member("description") : "";
				var a_image_unlocked      = a_obj.has_member("image_url_unlocked") ? a_obj.get_string_member("image_url_unlocked") : null;
				var a_image_locked        = a_obj.has_member("image_url_locked") ? a_obj.get_string_member("image_url_locked") : null;
				string? a_unlock_date = null;

				if(a_obj.has_member("date_unlocked"))
				{
					var date = a_obj.get_member("date_unlocked");
					if(date.get_node_type() == Json.NodeType.VALUE)
					{
						a_unlock_date = date.get_string();
					}
				}

				bool a_unlocked           = a_unlock_date != null;
				float a_global_percentage = a_obj.has_member("rarity") ? (float) a_obj.get_double_member("rarity") : 0;

				_achievements.add(new Achievement(a_id, a_name, a_desc, a_image_locked, a_image_unlocked,
				                                  a_unlocked, a_unlock_date, a_global_percentage));
			}

			_achievements.sort((first, second) => {
				var a1 = first as Achievement;
				var a2 = second as Achievement;

				if(a1.unlock_date != null || a2.unlock_date != null)
				{
					return (a2.unlock_date ?? new DateTime.from_unix_utc(0)).compare(a1.unlock_date ?? new DateTime.from_unix_utc(0));
				}

				if(a1.global_percentage < a2.global_percentage) return 1;
				if(a1.global_percentage > a2.global_percentage) return -1;
				return 0;
			});

			achievements = _achievements;
			loading_achievements = false;
			return achievements;
		}

		public class Achievement: Game.Achievement
		{
			public Achievement(string id, string name, string desc, string? image_locked, string? image_unlocked,
			                   bool unlocked, string? unlock_date, float global_percentage)
			{
				this.id = id;
				this.name = name;
				this.description = desc;
				this.image_locked = image_locked;
				this.image_unlocked = image_unlocked;
				this.unlocked = unlocked;
				this.global_percentage = global_percentage;

				#if GLIB_2_56
				if(unlock_date != null)
				{
					this.unlock_date = new DateTime.from_iso8601(unlock_date, new TimeZone.utc());
					this.unlock_time = Utils.get_relative_datetime(this.unlock_date);
				}
				#endif
			}
		}

		public class Installer: Runnable.DownloadableInstaller
		{
			private GOGGame game;
			private Json.Object json;
			private bool fetched = false;
			private File? installers_dir;

			public string lang;
			public string lang_full;

			public override string name { owned get { return lang_full + (version != null ? ": " + version : ""); } }

			public Installer(GOGGame game, Json.Object json)
			{
				this.game = game;
				this.json = json;

				id = json.get_string_member("id");
				lang = json.get_string_member("language");
				lang_full = json.get_string_member("language_full");

				var os = json.get_string_member("os");
				platform = Platform.CURRENT;
				foreach(var p in Platform.PLATFORMS)
				{
					if(os == p.id())
					{
						platform = p;
						break;
					}
				}

				string g = game.name;
				string? d = null;
				if(game is DLC)
				{
					g = (game as DLC).game.name;
					d = game.name;
				}
				installers_dir = FSUtils.file(FSUtils.Paths.Collection.GOG.expand_installers(g, d, platform)) ?? game.installers_dir;

				full_size = json.get_int_member("total_size");
				version = json.get_string_member("version");
			}

			public override async void fetch_parts()
			{
				if(fetched || installers_dir == null || !json.has_member("files") || json.get_member("files").get_node_type() != Json.NodeType.ARRAY) return;

				int loading_count = 0;

				foreach(var file_node in json.get_array_member("files").get_elements())
				{
					var file = file_node != null && file_node.get_node_type() == Json.NodeType.OBJECT ? file_node.get_object() : null;
					if(file != null)
					{
						var id = file.get_string_member("id");
						var size = file.get_int_member("size");
						var downlink_url = file.get_string_member("downlink");

						Utils.thread("GOGGame.Installer.fetch_part", () => {
							loading_count++;

							var root_node = Parser.parse_remote_json_file(downlink_url, "GET", ((GOG) game.source).user_token);
							if(root_node != null && root_node.get_node_type() == Json.NodeType.OBJECT)
							{
								var root = root_node.get_object();
								if(root != null && root.has_member("downlink"))
								{
									var url = root.get_string_member("downlink");
									var checksum_url = root.get_string_member("checksum");
									var remote = File.new_for_uri(url);

									string? local_filename = null;

									string? hash = null;
									var hash_type = ChecksumType.MD5;

									var checksum_root = Parser.parse_remote_xml_file(checksum_url, "GET", ((GOG) game.source).user_token);
									if(checksum_root != null)
									{
										var checksum_file_node = checksum_root->get_root_element();
										if(checksum_file_node != null)
										{
											hash = checksum_file_node->get_prop("md5");
											local_filename = checksum_file_node->get_prop("name");
										}

										delete checksum_root;
									}

									if(local_filename == null && "/namespaces/website/download?path=" in url)
									{
										var remote_path_encoded = url.split("/namespaces/website/download?path=")[1].split("&")[0];
										var remote_path = Uri.unescape_string(remote_path_encoded);
										local_filename = File.new_for_path(remote_path).get_basename();
									}

									var local = installers_dir.get_child(local_filename ?? "gog_" + game.id + "_" + this.id + "_" + id);

									parts.add(new Runnable.DownloadableInstaller.Part(id, url, size, remote, local, hash, hash_type));
								}
							}

							loading_count--;
							if(loading_count == 0)
							{
								Idle.add(fetch_parts.callback);
							}
						});
					}
				}

				yield;
				fetched = true;
			}
		}

		public class RunnableAction: Runnable.RunnableAction
		{
			public RunnableAction(GOGGame game, Json.Object json)
			{
				runnable = game;
				is_primary = json.has_member("isPrimary") && json.get_boolean_member("isPrimary");
				is_hidden = json.has_member("isHidden") && json.get_boolean_member("isHidden");
				name = json.has_member("name") ? json.get_string_member("name") : game.name;

				var type = json.has_member("type") ? json.get_string_member("type") : "filetask";

				if(type.down() == "filetask")
				{
					file = find_file(json.get_string_member("path"));
					if(file != null && file.query_exists())
					{
						if(file.get_basename().down().has_suffix(".exe"))
						{
							workdir = find_file(json.has_member("workingDir") ? json.get_string_member("workingDir") : "");
							args = json.has_member("arguments") ? json.get_string_member("arguments").replace("\\", "/").strip() : null;
							compat_tools = { typeof(GameHub.Data.Compat.Wine) };
						}
						else
						{
							uri = file.get_uri();
							file = null;
						}
					}
				}
				else if(type.down() == "urltask")
				{
					uri = json.has_member("link") ? json.get_string_member("link") : null;
				}
			}

			private File? find_file(string path)
			{
				if(runnable.install_dir == null || !runnable.install_dir.query_exists()) return null;
				var dir = (runnable is Game && ((Game) runnable).overlays_enabled)
					? runnable.install_dir.get_child(FSUtils.GAMEHUB_DIR).get_child("_overlay").get_child("merged")
					: runnable.install_dir;
				if(dir == null || !dir.query_exists()) return null;
				var p = path.replace("//", "/").replace("\\", "/").strip();
				if(p.length == 0) return dir;
				return FSUtils.find_case_insensitive(dir, p);
			}
		}

		public class BonusContent
		{
			public const string FILEMAP_NAME = ".bonusmap.json";

			public GOGGame game;

			public string id;
			public string name;
			public string type;
			public int64 count;
			public string file;
			public int64 size;

			public string filename;

			protected BonusContent.Status _status = new BonusContent.Status();
			public signal void status_change(BonusContent.Status status);

			public BonusContent.Status status
			{
				get { return _status; }
				set { _status = value; status_change(_status); }
			}

			public Downloader.DownloadInfo dl_info;

			public File? downloaded_file;

			public string text { owned get { return count > 1 ? @"$(count) $(name)" : name; } }

			public string icon
			{
				get
				{
					switch(type)
					{
						case "wallpapers":
						case "images":
						case "avatars":
						case "artworks":
							return "folder-pictures-symbolic";

						case "audio":
						case "soundtrack":
							return "folder-music-symbolic";

						case "video":
							return "folder-videos-symbolic";

						default: return "folder-documents-symbolic";
					}
				}
			}

			public BonusContent(GOGGame game, Json.Object json, Json.Object? bonus_map=null)
			{
				this.game = game;
				id = json.get_int_member("id").to_string();
				name = json.get_string_member("name");
				type = json.get_string_member("type");
				count = json.get_int_member("count");
				file = json.get_array_member("files").get_object_element(0).get_string_member("downlink");
				size = json.get_int_member("total_size");
				dl_info = new Downloader.DownloadInfo(text, game.name, game.icon, null, null, icon);

				filename = @"gog_$(game.id)_bonus_$(id)";
				if(bonus_map != null && bonus_map.has_member(id))
				{
					filename = bonus_map.get_string_member(id);
					downloaded_file = game.bonus_content_dir.get_child(filename);
					status = new BonusContent.Status(downloaded_file != null && downloaded_file.query_exists() ? BonusContent.State.DOWNLOADED : BonusContent.State.NOT_DOWNLOADED);
				}
			}

			public async File? download()
			{
				if(game.bonus_content_dir == null) return null;

				Json.Node? root_node = null;

				while(true)
				{
					uint status = 0;

					root_node = yield Parser.parse_remote_json_file_async(file, "GET", ((GOG) game.source).user_token, null, null, out status);

					if(status == Soup.Status.UNAUTHORIZED)
					{
						yield ((GOG) game.source).refresh_token();
					}
					else break;
				}

				if(root_node == null || root_node.get_node_type() != Json.NodeType.OBJECT) return null;
				var root = root_node.get_object();
				if(root == null || !root.has_member("downlink")) return null;

				var url = root.get_string_member("downlink");
				var checksum_url = root.get_string_member("checksum");
				var remote = File.new_for_uri(url);

				if(filename == @"gog_$(game.id)_bonus_$(id)" && "/namespaces/website/download?path=" in url)
				{
					var remote_path_encoded = url.split("/namespaces/website/download?path=")[1].split("&")[0];
					var remote_path = Uri.unescape_string(remote_path_encoded);
					filename = File.new_for_path(remote_path).get_basename();
				}

				warning("[filename] %s", filename);

				FSUtils.mkdir(FSUtils.Paths.GOG.Games);
				FSUtils.mkdir(game.bonus_content_dir.get_path());

				var local = game.bonus_content_dir.get_child(filename);

				status = new BonusContent.Status(BonusContent.State.DOWNLOADING, null);
				var ds_id = Downloader.download_manager().file_download_started.connect(dl => {
					if(dl.remote != remote) return;
					status = new BonusContent.Status(BonusContent.State.DOWNLOADING, dl);
					dl.status_change.connect(s => {
						status_change(status);
					});
				});

				var start_date = new DateTime.now_local();

				try
				{
					downloaded_file = yield Downloader.download_file(remote, local, dl_info, true, false);
				}
				catch(Error e){}

				Downloader.download_manager().disconnect(ds_id);

				save_filename();

				status = new BonusContent.Status(downloaded_file != null && downloaded_file.query_exists() ? BonusContent.State.DOWNLOADED : BonusContent.State.NOT_DOWNLOADED);

				var elapsed = new DateTime.now_local().difference(start_date);

				if(elapsed <= 10 * TimeSpan.SECOND)
				{
					try
					{
						open();
					}
					catch(Utils.RunError _)
					{
						// Not very important – ignore this problem here
					}
				}

				return downloaded_file;
			}

			public void open() throws Utils.RunError
			{
				if(downloaded_file != null && downloaded_file.query_exists())
				{
					Utils.open_uri(downloaded_file.get_uri());
				}
			}

			private void save_filename()
			{
				if(game.bonus_content_dir == null || downloaded_file == null || !downloaded_file.query_exists()) return;

				filename = downloaded_file.get_basename();

				var file = game.bonus_content_dir.get_child(BonusContent.FILEMAP_NAME);

				Json.Node? root_node = null;
				Json.Object? root = null;

				if(file != null && file.query_exists())
				{
					root_node = Parser.parse_json_file(file.get_path());
				}

				if(root_node == null || root_node.get_node_type() != Json.NodeType.OBJECT)
				{
					root_node = new Json.Node(Json.NodeType.OBJECT);
					root = new Json.Object();
				}
				else
				{
					root = root_node.get_object();
				}

				root.set_string_member(id, filename);
				root_node.set_object(root);

				var json = Json.to_string(root_node, true);

				try
				{
					FileUtils.set_contents(file.get_path(), json);
				}
				catch(Error e)
				{
					warning("[GOGGame.BonusContent.save_filename] %s", e.message);
				}
			}

			public class Status
			{
				public BonusContent.State state;

				public Downloader.Download? download;

				public Status(BonusContent.State state=BonusContent.State.NOT_DOWNLOADED, Downloader.Download? download=null)
				{
					this.state = state;
					this.download = download;
				}
			}

			public enum State
			{
				NOT_DOWNLOADED, DOWNLOADING, DOWNLOADED;
			}
		}

		public class DLC: GOGGame
		{
			public GOGGame game;

			public override File? default_install_dir
			{
				owned get
				{
					return game.default_install_dir;
				}
			}

			public DLC(GOGGame game, Json.Node json_node)
			{
				base(game.source as GOG, json_node);

				icon = game.icon;
				image = game.image;

				install_dir = game.install_dir;
				work_dir = game.work_dir;
				executable = game.executable;

				platforms = game.platforms;

				this.game = game;
				update_status();
			}

			// hack to parse installers/downloads fast, but allow next updates to fetch less important data
			public async void update_downloads_info()
			{
				info_detailed = info;
				try
				{
					yield update_game_info();
				}
				catch(Utils.RunError _)
				{
					// Ignore as there are no immediate problems caused by this failing here
				}
				info_detailed = null;
			}

			public override void update_status()
			{
				if(game == null) return;

				base.update_status();
			}

			public override async void install(Runnable.Installer.InstallMode install_mode=Runnable.Installer.InstallMode.INTERACTIVE) throws Utils.RunError
			{
				if(game.install_dir == null || !game.install_dir.query_exists()) return;

				yield game.umount_overlays();
				game.enable_overlays();
				var overlay = new Game.Overlay(game, "dlc_" + id, _("DLC: %s").printf(name), true);

				yield game.mount_overlays(overlay.directory);

				install_dir = game.install_dir.get_child(FSUtils.GAMEHUB_DIR).get_child("_overlay").get_child("merged");

				yield base.install(install_mode);

				yield game.umount_overlays();

				game.overlays.add(overlay);
				game.save_overlays();
				yield game.mount_overlays();
			}
		}
	}
}
