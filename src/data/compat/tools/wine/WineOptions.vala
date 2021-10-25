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

namespace GameHub.Data.Compat.Tools.Wine
{
	public class WineOptions: Object
	{
		public Prefix prefix { get; set; }
		public Desktop desktop { get; set; }
		public Libraries libraries { get; set; }

		public WineOptions()
		{
			Object();
		}

		public WineOptions.from_json(Json.Node? json)
		{
			Prefix? prefix = null;
			Desktop? desktop = null;
			Libraries? libraries = null;

			if(json != null && json.get_node_type() == Json.NodeType.OBJECT)
			{
				var obj = json.get_object();

				if(obj.has_member("prefix")) prefix = new Prefix.from_json(obj.get_member("prefix"));
				if(obj.has_member("desktop")) desktop = new Desktop.from_json(obj.get_member("desktop"));
				if(obj.has_member("libraries")) libraries = new Libraries.from_json(obj.get_member("libraries"));
			}

			Object(prefix: prefix ?? new Prefix(), desktop: desktop ?? new Desktop(), libraries: libraries ?? new Libraries());
		}

		public WineOptions copy()
		{
			return new WineOptions.from_json(to_json());
		}

		public Json.Node? to_json()
		{
			var node = new Json.Node(Json.NodeType.OBJECT);
			var obj = new Json.Object();

			obj.set_member("prefix", prefix.to_json());
			obj.set_member("desktop", desktop.to_json());
			obj.set_member("libraries", libraries.to_json());

			node.set_object(obj);
			return node;
		}

		public class Prefix: Object
		{
			public DefaultPath default_path { get; set; default = DefaultPath.SHARED; }
			public string custom_path { get; set; default = ""; }

			public string path
			{
				get
				{
					switch(default_path)
					{
						case DefaultPath.SHARED:   return "${compat_shared}/${tool_type}/${tool_id}";
						case DefaultPath.SEPARATE: return "${install_dir}/${compat}/${tool_type}/${tool_id}";
						case DefaultPath.CUSTOM:   return custom_path;
					}
					return "";
				}
			}

			public Prefix(DefaultPath default_path = DefaultPath.SHARED, string custom_path = "")
			{
				Object(default_path: default_path, custom_path: custom_path);
			}

			public Prefix.from_json(Json.Node? json)
			{
				DefaultPath default_path = DefaultPath.SHARED;
				string custom_path = "";

				if(json != null && json.get_node_type() == Json.NodeType.OBJECT)
				{
					var obj = json.get_object();

					if(obj.has_member("path")) default_path = DefaultPath.from_string(obj.get_string_member("path"));
					if(obj.has_member("custom")) custom_path = obj.get_string_member("custom");
				}

				Object(default_path: default_path, custom_path: custom_path);
			}

			public Json.Node? to_json()
			{
				var node = new Json.Node(Json.NodeType.OBJECT);
				var obj = new Json.Object();

				obj.set_string_member("path", default_path.to_string());
				if(custom_path.length > 0) obj.set_string_member("custom", custom_path);

				node.set_object(obj);
				return node;
			}

			public enum DefaultPath
			{
				SHARED, SEPARATE, CUSTOM;

				public string to_string()
				{
					switch(this)
					{
						case SHARED:   return "shared";
						case SEPARATE: return "separate";
						case CUSTOM:   return "custom";
					}
					assert_not_reached();
				}

				public static DefaultPath from_string(string path)
				{
					switch(path)
					{
						case "shared":   return SHARED;
						case "separate": return SEPARATE;
						case "custom":   return CUSTOM;
					}
					assert_not_reached();
				}
			}
		}

		public class Desktop: Object
		{
			public bool enabled { get; set; default = false; }
			public int width { get; set; default = 1920; }
			public int height { get; set; default = 1080; }

			public Desktop(bool enabled = false, int width = 1920, int height = 1080)
			{
				Object(enabled: enabled, width: width, height: height);
			}

			public Desktop.from_json(Json.Node? json)
			{
				bool enabled = false;
				int width = 1920;
				int height = 1080;

				if(json != null && json.get_node_type() == Json.NodeType.OBJECT)
				{
					var obj = json.get_object();

					if(obj.has_member("enabled")) enabled = obj.get_boolean_member("enabled");
					if(obj.has_member("width")) width = (int) obj.get_int_member("width");
					if(obj.has_member("height")) height = (int) obj.get_int_member("height");
				}

				Object(enabled: enabled, width: width, height: height);
			}

			public Json.Node? to_json()
			{
				var node = new Json.Node(Json.NodeType.OBJECT);
				var obj = new Json.Object();

				obj.set_boolean_member("enabled", enabled);
				obj.set_int_member("width", width);
				obj.set_int_member("height", height);

				node.set_object(obj);
				return node;
			}
		}

		public class Libraries: Object
		{
			public bool gecko { get; set; default = false; }
			public bool mono { get; set; default = false; }

			public Libraries(bool gecko = false, bool mono = false)
			{
				Object(gecko: gecko, mono: mono);
			}

			public Libraries.from_json(Json.Node? json)
			{
				bool gecko = false;
				bool mono = false;

				if(json != null && json.get_node_type() == Json.NodeType.OBJECT)
				{
					var obj = json.get_object();

					if(obj.has_member("gecko")) gecko = obj.get_boolean_member("gecko");
					if(obj.has_member("mono")) mono = obj.get_boolean_member("mono");
				}

				Object(gecko: gecko, mono: mono);
			}

			public Json.Node? to_json()
			{
				var node = new Json.Node(Json.NodeType.OBJECT);
				var obj = new Json.Object();

				obj.set_boolean_member("gecko", gecko);
				obj.set_boolean_member("mono", mono);

				node.set_object(obj);
				return node;
			}
		}
	}
}
