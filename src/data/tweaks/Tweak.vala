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
		public string? group { get; protected set; default = null; }
		public string? url { get; protected set; default = null; }

		public ApplicabilityOptions? applicability_options { get; protected set; default = null; }
		public Requirements? requirements { get; protected set; default = null; }

		public ArrayList<Option>? options { get; protected set; default = null; }

		public HashMap<string, string?>? env { get; protected set; default = null; }
		public string? command { get; protected set; default = null; }
		public File? file { get; protected set; default = null; }

		public Tweak(string id, string? name, string? description, string? group, string? url, ApplicabilityOptions? applicability_options, Requirements? requirements, ArrayList<Option>? options, HashMap<string, string?>? env, string? command, File? file)
		{
			Object(id: id, name: name, description: description, group: group, url: url, applicability_options: applicability_options, requirements: requirements, options: options, env: env, command: command, file: file);
		}

		public Tweak.from_json_object(Json.Object obj, File? file, string? default_id=null)
		{
			string id = default_id ?? "tweak";
			string? name = null;
			string? description = null;
			string? group = null;
			string? url = null;
			ApplicabilityOptions? applicability_options = null;
			Requirements? requirements = null;
			ArrayList<Option>? options = null;
			HashMap<string, string?>? env = null;
			string? command = null;

			if(obj.has_member("id")) id = obj.get_string_member("id");
			if(obj.has_member("name")) name = obj.get_string_member("name");
			if(obj.has_member("description")) description = obj.get_string_member("description");
			if(obj.has_member("group")) group = obj.get_string_member("group");
			if(obj.has_member("url")) url = obj.get_string_member("url");

			if(obj.has_member("applicable_to"))
			{
				applicability_options = new ApplicabilityOptions.from_json(obj.get_member("applicable_to"));
			}

			if(obj.has_member("requires"))
			{
				requirements = new Requirements.from_json(obj.get_member("requires"));
			}

			if(obj.has_member("options"))
			{
				options = new ArrayList<Option>();
				var options_object = obj.get_object_member("options");
				foreach(var option_id in options_object.get_members())
				{
					options.add(new Option.from_json(option_id, options_object.get_member(option_id)));
				}
			}

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

			if(obj.has_member("command"))
			{
				command = obj.get_string_member("command");
			}

			Object(id: id, name: name, description: description, group: group, url: url, applicability_options: applicability_options, requirements: requirements, options: options, env: env, command: command, file: file);
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

		public Requirements? get_unavailable_requirements()
		{
			if(requirements == null) return null;
			return requirements.get_unavailable();
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
				var icon = "gh-settings-cogs-symbolic";
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

		public static HashMap<string?, HashMap<string, Tweak>>? load_tweaks_grouped(bool refresh=false)
		{
			var tweaks = load_tweaks(refresh);
			if(tweaks == null || tweaks.size == 0) return null;

			var groups = new HashMap<string?, HashMap<string, Tweak>>();
			foreach(var tweak in tweaks.entries)
			{
				if(!groups.has_key(tweak.value.group))
				{
					groups[tweak.value.group] = new HashMap<string, Tweak>();
				}
				groups[tweak.value.group][tweak.value.id] = tweak.value;
			}

			return groups;
		}

		public Json.Object to_json()
		{
			var obj = new Json.Object();

			obj.set_string_member("id", id);
			if(name != null) obj.set_string_member("name", name);
			if(description != null) obj.set_string_member("description", description);
			if(group != null) obj.set_string_member("group", group);
			if(url != null) obj.set_string_member("url", url);

			if(applicability_options != null)
			{
				var options = applicability_options.to_json();
				if(options != null) obj.set_member("applicable_to", options);
			}

			if(requirements != null)
			{
				var reqs = requirements.to_json();
				if(reqs != null) obj.set_member("requires", reqs);
			}

			if(options != null && options.size > 0)
			{
				var options_obj = new Json.Object();
				foreach(var option in options)
				{
					options_obj.set_member(option.id, option.to_json());
				}
				obj.set_object_member("options", options_obj);
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

		public class Requirements: Object
		{
			public ArrayList<string>? executables { get; protected set; default = null; }
			public ArrayList<string>? kernel_modules { get; protected set; default = null; }

			public Requirements(ArrayList<string>? executables, ArrayList<string>? kernel_modules)
			{
				Object(executables: executables, kernel_modules: kernel_modules);
			}

			public Requirements.from_json(Json.Node? json)
			{
				ArrayList<string>? executables = null;
				ArrayList<string>? kernel_modules = null;

				if(json != null && json.get_node_type() == Json.NodeType.OBJECT)
				{
					var obj = json.get_object();

					if(obj.has_member("executables"))
					{
						var executables_array = obj.get_array_member("executables");
						if(executables_array.get_length() > 0)
						{
							executables = new ArrayList<string>();
							foreach(var executable_node in executables_array.get_elements())
							{
								if(executable_node.get_node_type() == Json.NodeType.VALUE)
								{
									var executable = executable_node.get_string();
									if(executable != null)
									{
										executables.add(executable);
									}
								}
							}
						}
					}

					if(obj.has_member("kernel_modules"))
					{
						var kmods_array = obj.get_array_member("kernel_modules");
						if(kmods_array.get_length() > 0)
						{
							kernel_modules = new ArrayList<string>();
							foreach(var kmod_node in kmods_array.get_elements())
							{
								if(kmod_node.get_node_type() == Json.NodeType.VALUE)
								{
									var kmod = kmod_node.get_string();
									if(kmod != null)
									{
										kernel_modules.add(kmod);
									}
								}
							}
						}
					}
				}

				Object(executables: executables, kernel_modules: kernel_modules);
			}

			public Requirements? get_unavailable()
			{
				var reqs = new Requirements(null, null);

				if(executables != null && executables.size > 0)
				{
					var has_executable = false;
					foreach(var executable in executables)
					{
						var file = Utils.find_executable(executable);
						if(file != null && file.query_exists())
						{
							has_executable = true;
							break;
						}
					}
					if(!has_executable)
					{
						reqs.executables = executables;
					}
				}

				if(kernel_modules != null && kernel_modules.size > 0)
				{
					var has_kmod = false;
					foreach(var kmod in kernel_modules)
					{
						if(Utils.is_kernel_module_loaded(kmod))
						{
							has_kmod = true;
							break;
						}
					}
					if(!has_kmod)
					{
						reqs.kernel_modules = kernel_modules;
					}
				}

				return ((reqs.executables == null || reqs.executables.size == 0) && (reqs.kernel_modules == null || reqs.kernel_modules.size == 0)) ? null : reqs;
			}

			public Json.Node? to_json()
			{
				if((executables == null || executables.size == 0) && (kernel_modules == null || kernel_modules.size == 0))
				{
					return null;
				}

				var node = new Json.Node(Json.NodeType.OBJECT);
				var obj = new Json.Object();

				if(executables != null && executables.size > 0)
				{
					var executables_array = new Json.Array.sized(executables.size);
					foreach(var executable in executables)
					{
						executables_array.add_string_element(executable);
					}
					obj.set_array_member("executables", executables_array);
				}

				if(kernel_modules != null && kernel_modules.size > 0)
				{
					var kmods_array = new Json.Array.sized(kernel_modules.size);
					foreach(var kmod in kernel_modules)
					{
						kmods_array.add_string_element(kmod);
					}
					obj.set_array_member("kernel_modules", kmods_array);
				}

				node.set_object(obj);
				return node;
			}
		}

		public class Option: Object
		{
			public string id { get; protected set; }
			public string? name { get; protected set; default = null; }
			public string? description { get; protected set; default = null; }

			public Type option_type { get; protected set; default = Type.LIST; }
			public string list_separator { get; protected set; default = DEFAULT_LIST_SEPARATOR; }
			public string? string_value { get; protected set; default = null; }

			public HashMap<string, string>? values { get; protected set; default = null; }
			public ArrayList<Preset>? presets { get; protected set; default = null; }

			public Option.from_json(string id, Json.Node? json)
			{
				string? name = null;
				string? description = null;

				Type option_type = Type.LIST;
				string list_separator = DEFAULT_LIST_SEPARATOR;
				string? string_value = null;

				HashMap<string, string>? values = null;
				ArrayList<Preset>? presets = null;

				if(json != null && json.get_node_type() == Json.NodeType.OBJECT)
				{
					var obj = json.get_object();

					if(obj.has_member("name")) name = obj.get_string_member("name");
					if(obj.has_member("description")) description = obj.get_string_member("description");

					if(obj.has_member("type")) option_type = Type.from_string(obj.get_string_member("type"));
					if(obj.has_member("separator")) list_separator = obj.get_string_member("separator");
					if(obj.has_member("value")) string_value = obj.get_string_member("value");

					if(obj.has_member("values"))
					{
						values = new HashMap<string, string>();
						var values_obj = obj.get_object_member("values");
						foreach(var value in values_obj.get_members())
						{
							values.set(value, values_obj.get_string_member(value));
						}
					}

					if(obj.has_member("presets"))
					{
						presets = new ArrayList<Preset>();
						var presets_obj = obj.get_object_member("presets");
						foreach(var preset_id in presets_obj.get_members())
						{
							presets.add(new Preset.from_json(preset_id, presets_obj.get_member(preset_id)));
						}
					}
				}

				Object(id: id, name: name, description: description, option_type: option_type, list_separator: list_separator, string_value: string_value, values: values, presets: presets);
			}

			public Json.Node? to_json()
			{
				var node = new Json.Node(Json.NodeType.OBJECT);
				var obj = new Json.Object();

				obj.set_string_member("id", id);
				if(name != null) obj.set_string_member("name", name);
				if(description != null) obj.set_string_member("description", description);

				obj.set_string_member("type", option_type.to_string());
				if(list_separator != DEFAULT_LIST_SEPARATOR) obj.set_string_member("separator", list_separator);
				if(string_value != null) obj.set_string_member("value", string_value);

				if(values != null && values.size > 0)
				{
					var values_obj = new Json.Object();
					foreach(var value in values.entries)
					{
						values_obj.set_string_member(value.key, value.value);
					}
					obj.set_object_member("values", values_obj);
				}

				if(presets != null && presets.size > 0)
				{
					var presets_obj = new Json.Object();
					foreach(var preset in presets)
					{
						presets_obj.set_member(preset.id, preset.to_json());
					}
					obj.set_object_member("presets", presets_obj);
				}

				node.set_object(obj);
				return node;
			}

			public class Preset: Object
			{
				public string id { get; protected set; }
				public string value { get; protected set; }
				public string? name { get; protected set; }
				public string? description { get; protected set; }

				public Preset(string id, string value, string? name, string? description)
				{
					Object(id: id, value: value, name: name, description: description);
				}

				public Preset.from_json(string id, Json.Node? json)
				{
					string value = "";
					string? name = null;
					string? description = null;

					if(json != null && json.get_node_type() == Json.NodeType.OBJECT)
					{
						var obj = json.get_object();

						if(obj.has_member("value")) value = obj.get_string_member("value");
						if(obj.has_member("name")) name = obj.get_string_member("name");
						if(obj.has_member("description")) description = obj.get_string_member("description");
					}

					Object(id: id, value: value, name: name, description: description);
				}

				public Json.Node? to_json()
				{
					var node = new Json.Node(Json.NodeType.OBJECT);
					var obj = new Json.Object();

					obj.set_string_member("id", id);
					obj.set_string_member("value", value);
					if(name != null) obj.set_string_member("name", name);
					if(description != null) obj.set_string_member("description", description);

					node.set_object(obj);
					return node;
				}
			}

			public enum Type
			{
				LIST, STRING;

				public string to_string()
				{
					switch(this)
					{
						case LIST:   return "list";
						case STRING: return "string";
					}
					assert_not_reached();
				}

				public static Type from_string(string type)
				{
					switch(type)
					{
						case "list":   return LIST;
						case "string": return STRING;
					}
					assert_not_reached();
				}
			}

			private static string DEFAULT_LIST_SEPARATOR = ",";
		}
	}
}
