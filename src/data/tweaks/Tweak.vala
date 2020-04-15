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

using GameHub.Utils;
using GameHub.Data.Runnables;

namespace GameHub.Data.Tweaks
{
	public class Tweak: Object
	{
		public string id { get; protected set; }
		public string? name { get; protected set; default = null; }
		public string? description { get; protected set; default = null; }
		public string? url { get; protected set; default = null; }

		public ApplicabilityOptions? applicability_options { get; protected set; default = null; }

		public HashMap<string, string?>? env { get; protected set; default = null; }
		public string? command { get; protected set; default = null; }
		public File? file { get; protected set; default = null; }

		public Tweak(string id, string? name, string? description, string? url, ApplicabilityOptions? applicability_options, HashMap<string, string?>? env, string? command, File? file)
		{
			Object(id: id, name: name, description: description, url: url, applicability_options: applicability_options, env: env, command: command, file: file);
		}

		public Tweak.from_json_object(Json.Object obj, File? file, string? default_id=null)
		{
			string id = default_id ?? "tweak";
			string? name = null;
			string? description = null;
			string? url = null;
			ApplicabilityOptions? applicability_options = null;
			HashMap<string, string?>? env = null;
			string? command = null;

			if(obj.has_member("id")) id = obj.get_string_member("id");
			if(obj.has_member("name")) name = obj.get_string_member("name");
			if(obj.has_member("description")) description = obj.get_string_member("description");
			if(obj.has_member("url")) url = obj.get_string_member("url");

			if(obj.has_member("applicable_to"))
				applicability_options = new ApplicabilityOptions.from_json(obj.get_member("applicable_to"));

			if(obj.has_member("env"))
			{
				env = new HashMap<string, string?>();
				var env_object = obj.get_object_member("env");
				foreach(var env_var in env_object.get_members())
				{
					var env_value = env_object.get_member(env_var);
					if(env_value.get_node_type() == Json.NodeType.VALUE)
					{
						env.set(env_var, env_value.get_string());
					}
					else
					{
						env.set(env_var, null);
					}
				}
			}

			if(obj.has_member("command")) command = obj.get_string_member("command");

			Object(id: id, name: name, description: description, url: url, applicability_options: applicability_options, env: env, command: command, file: file);
		}

		public static ArrayList<Tweak> load_from_file(File file)
		{
			var loaded_tweaks = new ArrayList<Tweak>();
			string id = file.get_basename().replace(".json", "");

			var node = Parser.parse_json_file(file.get_path());
			switch(node.get_node_type())
			{
				case Json.NodeType.OBJECT:
					loaded_tweaks.add(new Tweak.from_json_object(node.get_object(), file, id));
					break;

				case Json.NodeType.ARRAY:
					int i = 0;
					foreach(var tweak_node in node.get_array().get_elements())
					{
						if(tweak_node.get_node_type() == Json.NodeType.OBJECT)
						{
							loaded_tweaks.add(new Tweak.from_json_object(tweak_node.get_object(), file, @"$(id)[$(i++)]"));
						}
					}
					break;
			}

			return loaded_tweaks;
		}

		public bool is_applicable_to(Traits.Game.SupportsTweaks game, CompatTool? compat_tool=null)
		{
			if(applicability_options == null) return true;
			return applicability_options.is_applicable_to(game, compat_tool);
		}

		public bool is_enabled(Traits.Game.SupportsTweaks? game=null)
		{
			if(game == null || game.tweaks == null)
			{
				return id in Settings.Tweaks.instance.global;
			}
			else
			{
				return id in game.tweaks;
			}
		}

		public void set_enabled(bool enabled, Traits.Game.SupportsTweaks? game=null)
		{
			if(game == null)
			{
				var global = Settings.Tweaks.instance.global;
				if(!enabled && id in global)
				{
					string[] new_global = {};
					foreach(var t in global)
					{
						if(t != id) new_global += t;
					}
					Settings.Tweaks.instance.global = new_global;
				}
				else if(enabled && !(id in global))
				{
					global += id;
					Settings.Tweaks.instance.global = global;
				}
			}
			else
			{
				var game_tweaks = game.tweaks ?? Settings.Tweaks.instance.global;
				if(!enabled && id in game_tweaks)
				{
					string[] new_game_tweaks = {};
					foreach(var t in game_tweaks)
					{
						if(t != id) new_game_tweaks += t;
					}
					game.tweaks = new_game_tweaks;
					game.save();
				}
				else if(enabled && !(id in game_tweaks))
				{
					game_tweaks += id;
					game.tweaks = game_tweaks;
					game.save();
				}
			}
		}

		public string icon
		{
			owned get
			{
				var icon = "system-run-symbolic";
				if(applicability_options != null)
				{
					if(applicability_options.platforms != null && applicability_options.platforms.size > 0)
					{
						icon = applicability_options.platforms.first().icon();
					}

					if(applicability_options.compat_tool_ids != null && applicability_options.compat_tool_ids.size > 0)
					{
						var tool_id = applicability_options.compat_tool_ids.first();
						foreach(var tool in CompatTools)
						{
							if(tool.id == tool_id || tool.id.has_prefix(@"$(tool_id)_"))
							{
								icon = tool.icon;
								break;
							}
						}
					}
				}
				return icon;
			}
		}

		private static HashMap<string, Tweak>? tweaks = null;
		public static HashMap<string, Tweak> load_tweaks(bool refresh=false)
		{
			if(tweaks != null && tweaks.size > 0 && !refresh)
			{
				return tweaks;
			}

			tweaks = new HashMap<string, Tweak>();

			foreach(var data_dir in FS.get_data_dirs("tweaks"))
			{
				if(GameHub.Application.log_verbose)
				{
					debug("[Tweak.load_tweaks] Directory: '%s'", data_dir.get_path());
				}

				try
				{
					FileInfo? finfo = null;
					var enumerator = data_dir.enumerate_children("standard::*", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
					while((finfo = enumerator.next_file()) != null)
					{
						var fname = finfo.get_name();
						if(fname.down().has_suffix(".json"))
						{
							var file = data_dir.get_child(fname);
							var loaded_tweaks = load_from_file(file);

							if(GameHub.Application.log_verbose)
							{
								debug("[Tweak.load_tweaks] File: '%s'; %d tweak(s):", file.get_path(), loaded_tweaks.size);
							}

							foreach(var tweak in loaded_tweaks)
							{
								tweaks.set(tweak.id, tweak);

								if(GameHub.Application.log_verbose)
								{
									debug("[Tweak.load_tweaks] %s", Json.to_string(new Json.Node(Json.NodeType.OBJECT).init_object(tweak.to_json()), false));
								}
							}
						}
					}
				}
				catch(Error e)
				{
					warning("[Tweak.load_tweaks] %s", e.message);
				}
			}

			return tweaks;
		}

		public Json.Object to_json()
		{
			var obj = new Json.Object();

			obj.set_string_member("id", id);
			if(name != null) obj.set_string_member("name", name);
			if(description != null) obj.set_string_member("description", description);
			if(url != null) obj.set_string_member("url", url);

			if(applicability_options != null)
			{
				var options = applicability_options.to_json();
				if(options != null)	obj.set_member("applicable_to", options);
			}

			if(env != null && env.size > 0)
			{
				var env_obj = new Json.Object();
				foreach(var env_var in env.entries)
				{
					if(env_var.value != null)
					{
						env_obj.set_string_member(env_var.key, env_var.value);
					}
					else
					{
						env_obj.set_null_member(env_var.key);
					}
				}
				obj.set_object_member("env", env_obj);
			}

			if(command != null) obj.set_string_member("command", command);

			return obj;
		}

		public class ApplicabilityOptions: Object
		{
			public ArrayList<Platform>? platforms { get; protected set; default = null; }
			public ArrayList<string>? compat_tool_ids { get; protected set; default = null; }

			public ApplicabilityOptions(ArrayList<Platform>? platforms, ArrayList<string>? compat_tool_ids)
			{
				Object(platforms: platforms, compat_tool_ids: compat_tool_ids);
			}

			public ApplicabilityOptions.from_json(Json.Node? json)
			{
				ArrayList<Platform>? platforms = null;
				ArrayList<string>? compat_tool_ids = null;

				if(json != null && json.get_node_type() == Json.NodeType.OBJECT)
				{
					var obj = json.get_object();

					if(obj.has_member("platforms"))
					{
						var platforms_array = obj.get_array_member("platforms");
						if(platforms_array.get_length() > 0)
						{
							platforms = new ArrayList<Platform>();
							foreach(var platform_node in platforms_array.get_elements())
							{
								if(platform_node.get_node_type() == Json.NodeType.VALUE)
								{
									var platform_id = platform_node.get_string();
									if(platform_id != null)
									{
										foreach(var p in Platform.PLATFORMS)
										{
											if(platform_id == p.id() && !(p in platforms))
											{
												platforms.add(p);
												break;
											}
										}
									}
								}
							}
						}
					}

					if(obj.has_member("compat"))
					{
						var tools_array = obj.get_array_member("compat");
						if(tools_array.get_length() > 0)
						{
							compat_tool_ids = new ArrayList<string>();
							foreach(var tool_node in tools_array.get_elements())
							{
								if(tool_node.get_node_type() == Json.NodeType.VALUE)
								{
									var tool_id = tool_node.get_string();
									if(tool_id != null && !(tool_id in compat_tool_ids))
									{
										compat_tool_ids.add(tool_id);
									}
								}
							}
						}
					}
				}

				Object(platforms: platforms, compat_tool_ids: compat_tool_ids);
			}

			public bool is_applicable_to(Traits.Game.SupportsTweaks game, CompatTool? compat_tool=null)
			{
				if(platforms != null)
				{
					var has_platform = false;
					foreach(var platform in platforms)
					{
						if(platform in game.platforms)
						{
							has_platform = true;
							break;
						}
					}
					if(!has_platform) return false;
				}

				string? compat_tool_id = null;
				if(compat_tool != null)
				{
					compat_tool_id = compat_tool.id;
				}
				else
				{
					game.cast<Traits.SupportsCompatTools>(game => {
						if(game.use_compat)
						{
							compat_tool_id = game.compat_tool;
						}
					});
				}

				if(compat_tool_ids != null)
				{
					var has_tool = false;
					if(compat_tool_id != null)
					{
						foreach(var id in compat_tool_ids)
						{
							if(compat_tool_id == id || compat_tool_id.has_prefix(@"$(id)_"))
							{
								has_tool = true;
								break;
							}
						}
					}
					if(!has_tool) return false;
				}

				return true;
			}

			public Json.Node? to_json()
			{
				if((platforms == null || platforms.size == 0) && (compat_tool_ids == null || compat_tool_ids.size == 0))
				{
					return null;
				}

				var node = new Json.Node(Json.NodeType.OBJECT);
				var obj = new Json.Object();

				if(platforms != null && platforms.size > 0)
				{
					var platforms_array = new Json.Array.sized(platforms.size);
					foreach(var platform in platforms)
					{
						platforms_array.add_string_element(platform.id());
					}
					obj.set_array_member("platforms", platforms_array);
				}

				if(compat_tool_ids != null && compat_tool_ids.size > 0)
				{
					var tools_array = new Json.Array.sized(compat_tool_ids.size);
					foreach(var tool_id in compat_tool_ids)
					{
						tools_array.add_string_element(tool_id);
					}
					obj.set_array_member("compat", tools_array);
				}

				node.set_object(obj);
				return node;
			}
		}
	}
}
