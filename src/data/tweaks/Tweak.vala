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
using GameHub.Data.Compat;
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
		public string? icon_name { get; protected set; default = null; }

		public ApplicabilityOptions? applicability_options { get; protected set; default = null; }
		public Requirements? requirements { get; protected set; default = null; }

		public ArrayList<Option>? options { get; protected set; default = null; }
		public bool has_options { get { return options != null && options.size > 0; } }

		public HashMap<string, string?>? env { get; protected set; default = null; }
		public string? command { get; protected set; default = null; }
		public File? file { get; protected set; default = null; }

		public Tweak(string id, string? name, string? description, string? group, string? url, string? icon_name, ApplicabilityOptions? applicability_options, Requirements? requirements, ArrayList<Option>? options, HashMap<string, string?>? env, string? command, File? file)
		{
			Object(id: id, name: name, description: description, group: group, url: url, icon_name: icon_name, applicability_options: applicability_options, requirements: requirements, options: options, env: env, command: command, file: file);
		}

		public Tweak.from_json_object(Json.Object obj, File? file, string? default_id=null)
		{
			string id = default_id ?? "tweak";
			string? name = null;
			string? description = null;
			string? group = null;
			string? url = null;
			string? icon_name = null;
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
			if(obj.has_member("icon")) icon_name = obj.get_string_member("icon");

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

			Object(id: id, name: name, description: description, group: group, url: url, icon_name: icon_name, applicability_options: applicability_options, requirements: requirements, options: options, env: env, command: command, file: file);
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

		public Option? get_option(string id)
		{
			if(!has_options) return null;
			foreach(var option in options)
			{
				if(option.id == id) return option;
			}
			return null;
		}

		public string icon
		{
			owned get
			{
				if(icon_name != null)
				{
					return icon_name;
				}
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
						/*foreach(var tool in CompatTools)
						{
							if(tool.id == tool_id || tool.id.has_prefix(@"$(tool_id)_"))
							{
								icon = tool.icon;
								break;
							}
						}*/
					}
				}
				return icon;
			}
		}

		private static HashMap<string, Tweak>? cached_tweaks = null;
		public static HashMap<string, Tweak> load_tweaks()
		{
			if(cached_tweaks != null && cached_tweaks.size > 0)
			{
				return cached_tweaks;
			}

			cached_tweaks = new HashMap<string, Tweak>();

			foreach(var data_dir in FS.get_data_dirs("tweaks"))
			{
				var dir_tweaks = load_tweaks_recursive(data_dir);
				if(dir_tweaks != null && dir_tweaks.size > 0)
				{
					foreach(var tweak in dir_tweaks)
					{
						cached_tweaks.set(tweak.id, tweak);
					}
				}
			}

			return cached_tweaks;
		}

		private static ArrayList<Tweak>? load_tweaks_recursive(File directory)
		{
			var tweaks = new ArrayList<Tweak>();
			try
			{
				FileInfo? finfo = null;
				var enumerator = directory.enumerate_children("standard::*", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
				while((finfo = enumerator.next_file()) != null)
				{
					var fname = finfo.get_name();
					var file = directory.get_child(fname);
					if(finfo.get_file_type() == FileType.DIRECTORY)
					{
						var subdir_tweaks = load_tweaks_recursive(file);
						if(subdir_tweaks != null && subdir_tweaks.size > 0)
						{
							tweaks.add_all(subdir_tweaks);
						}
					}
					else if(fname.down().has_suffix(".json"))
					{
						var file_tweaks = load_from_file(file);
						if(file_tweaks != null && file_tweaks.size > 0)
						{
							tweaks.add_all(file_tweaks);
						}
					}
				}
			}
			catch(Error e)
			{
				warning("[Tweak.load_tweaks_recursive] Error while loading tweaks from '%s': %s", directory.get_path(), e.message);
			}
			return tweaks;
		}

		public delegate bool TweakFilterPredicate(Tweak tweak);
		public static HashMap<string?, HashMap<string, Tweak>>? load_tweaks_grouped(TweakFilterPredicate? filter = null)
		{
			var tweaks = load_tweaks();
			if(tweaks == null || tweaks.size == 0) return null;

			var groups = new HashMap<string?, HashMap<string, Tweak>>();
			foreach(var tweak in tweaks.entries)
			{
				if(filter != null && !filter(tweak.value)) continue;
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
			if(icon_name != null) obj.set_string_member("icon", icon_name);

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

			if(has_options)
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
	}
}
