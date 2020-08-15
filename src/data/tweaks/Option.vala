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

		public Preset? get_preset(string id)
		{
			if(presets == null || presets.size == 0) return null;
			foreach(var preset in presets)
			{
				if(preset.id == id) return preset;
			}
			return null;
		}

		public string default_value
		{
			get
			{
				if(presets != null && presets.size >= 1) return presets.first().value;
				return "";
			}
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
