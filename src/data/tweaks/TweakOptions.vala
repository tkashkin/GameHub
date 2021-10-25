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

using GameHub.Utils;
using GameHub.Data.Runnables;

namespace GameHub.Data.Tweaks
{
	public class TweakOptions: Object
	{
		public Tweak tweak { get; set; }
		public State state { get; set; default = State.GLOBAL; }
		public ArrayList<OptionProperties>? properties { get; protected set; default = null; }
		public bool has_properties { get { return properties != null && properties.size > 0; } }

		public TweakOptions(Tweak tweak, State state = State.GLOBAL, ArrayList<OptionProperties>? properties = null)
		{
			Object(tweak: tweak, state: state, properties: properties);
		}

		public TweakOptions.from_json(Tweak tweak, Json.Node? json)
		{
			State state = State.GLOBAL;
			ArrayList<OptionProperties>? properties = null;

			if(json != null && json.get_node_type() == Json.NodeType.OBJECT)
			{
				var obj = json.get_object();

				if(obj.has_member("state")) state = State.from_string(obj.get_string_member("state"));

				if(obj.has_member("options"))
				{
					properties = new ArrayList<OptionProperties>();
					obj.get_object_member("options").foreach_member((obj, id, node) => {
						var option = tweak.get_option(id);
						if(option != null)
						{
							properties.add(new OptionProperties.from_json(option, node));
						}
					});
				}
			}

			Object(tweak: tweak, state: state, properties: properties);
		}

		public TweakOptions copy()
		{
			return new TweakOptions.from_json(tweak, to_json());
		}

		public OptionProperties? get_properties_for_id(string option_id)
		{
			if(!has_properties) return null;
			foreach(var opt_props in properties)
			{
				if(opt_props.option.id == option_id) return opt_props;
			}
			return null;
		}

		public void set_properties_for_id(string option_id, OptionProperties? opt_props)
		{
			var old_props = get_properties_for_id(option_id);
			if(old_props != null)
			{
				properties.remove(old_props);
			}
			if(opt_props != null)
			{
				if(properties == null)
				{
					properties = new ArrayList<OptionProperties>();
				}
				properties.add(opt_props);
			}
		}

		public OptionProperties? get_properties_for_option(Option option)
		{
			return get_properties_for_id(option.id);
		}

		public void set_properties_for_option(Option option, OptionProperties? opt_props)
		{
			set_properties_for_id(option.id, opt_props);
		}

		public OptionProperties get_or_create_properties(Option option)
		{
			var props = get_properties_for_option(option);
			if(props == null)
			{
				props = new OptionProperties(option, option.presets != null && option.presets.size > 0 ? option.presets.first() : null);
			}
			return props;
		}

		public string expand(string value)
		{
			var result = value;
			if(has_properties)
			{
				foreach(var option_props in properties)
				{
					result = result.replace("${option:%s}".printf(option_props.option.id), option_props.value);
				}
			}
			if(tweak.has_options)
			{
				foreach(var option in tweak.options)
				{
					result = result.replace("${option:%s}".printf(option.id), option.default_value);
				}
			}
			return result;
		}

		public Json.Node? to_json()
		{
			var node = new Json.Node(Json.NodeType.OBJECT);
			var obj = new Json.Object();

			obj.set_string_member("state", state.to_string());

			if(has_properties)
			{
				var options = new Json.Object();
				foreach(var opt_props in properties)
				{
					options.set_member(opt_props.option.id, opt_props.to_json());
				}
				obj.set_object_member("options", options);
			}

			node.set_object(obj);
			return node;
		}

		public class OptionProperties: Object
		{
			public Option option { get; set; }
			public Option.Preset? preset { get; set; default = null; }
			public string[]? selected_values { get; set; default = null; }
			public string? string_value { get; set; default = null; }

			public OptionProperties(Option option, Option.Preset? preset = null, string[]? selected_values = null, string? string_value = null)
			{
				Object(option: option, preset: preset, selected_values: selected_values, string_value: string_value);
			}

			public OptionProperties.from_json(Option option, Json.Node? json)
			{
				Option.Preset? preset = null;
				string[]? selected_values = null;
				string? string_value = null;

				if(json != null && json.get_node_type() == Json.NodeType.OBJECT)
				{
					var obj = json.get_object();

					if(option.presets != null && option.presets.size > 0 && obj.has_member("preset"))
					{
						preset = option.get_preset(obj.get_string_member("preset"));
					}

					if(option.option_type == Option.Type.LIST && option.values != null && option.values.size > 0 && obj.has_member("values"))
					{
						selected_values = {};
						var value_nodes = obj.get_array_member("values").get_elements();
						foreach(var node in value_nodes)
						{
							if(node.get_node_type() == Json.NodeType.VALUE)
							{
								selected_values += node.get_string();
							}
						}
					}
					else if(option.option_type == Option.Type.STRING && obj.has_member("value"))
					{
						string_value = obj.get_string_member("value");
					}
				}

				Object(option: option, preset: preset, selected_values: selected_values, string_value: string_value);
			}

			public string? value
			{
				owned get
				{
					if(preset != null)
					{
						return preset.value;
					}
					else
					{
						switch(option.option_type)
						{
							case Option.Type.LIST:
								if(selected_values != null)
								{
									return string.joinv(option.list_separator, selected_values);
								}
								break;

							case Option.Type.STRING:
								if(string_value != null)
								{
									return option.string_value.replace("${value}", string_value).replace("$value", string_value);
								}
								break;
						}
					}
					return null;
				}
			}

			public Json.Node to_json()
			{
				var node = new Json.Node(Json.NodeType.OBJECT);
				var obj = new Json.Object();

				if(preset != null) obj.set_string_member("preset", preset.id);

				if(option.option_type == Option.Type.LIST && option.values != null && option.values.size > 0 && selected_values != null)
				{
					var values = new Json.Array();
					foreach(var value in selected_values)
					{
						values.add_string_element(value);
					}
					obj.set_array_member("values", values);
				}
				else if(option.option_type == Option.Type.STRING && string_value != null)
				{
					obj.set_string_member("value", string_value);
				}

				node.set_object(obj);
				return node;
			}
		}

		public enum State
		{
			ENABLED, DISABLED, GLOBAL;

			public string to_string()
			{
				switch(this)
				{
					case ENABLED:  return "enabled";
					case DISABLED: return "disabled";
					case GLOBAL:   return "global";
				}
				assert_not_reached();
			}

			public static State from_string(string state)
			{
				switch(state)
				{
					case "enabled":  return ENABLED;
					case "disabled": return DISABLED;
					case "global":   return GLOBAL;
				}
				assert_not_reached();
			}
		}
	}
}
