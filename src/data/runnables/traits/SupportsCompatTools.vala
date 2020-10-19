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

using GameHub.Data;

using GameHub.Data.Compat;
using GameHub.Data.Runnables;
using GameHub.Data.Runnables.Tasks.Install;

using GameHub.Utils;

namespace GameHub.Data.Runnables.Traits
{
	public interface SupportsCompatTools: Runnable, HasExecutableFile
	{
		public abstract string? compat_tool { get; set; }
		public abstract string? compat_tool_settings { get; set; }

		public virtual async void run_with_compat(bool is_opened_from_menu=false)
		{
			if(can_be_launched(true))
			{
				/*var dlg = new UI.Dialogs.CompatRunDialog(this, is_opened_from_menu);
				dlg.destroy.connect(() => {
					Idle.add(run_with_compat.callback);
				});
				yield;*/
			}
		}

		public virtual bool supports_compat_tool(CompatToolTraits.Run tool)
		{
			return tool.can_run(this);
		}

		public bool supports_compat_tools
		{
			get
			{
				foreach(var tool in Compat.compat_tools)
				{
					if(tool is CompatToolTraits.Run && supports_compat_tool((CompatToolTraits.Run) tool)) return true;
				}
				return false;
			}
		}

		public bool needs_compat
		{
			get { return (!is_native && supports_compat_tools) || is_executable_not_native; }
		}

		public bool force_compat
		{
			get { return get_compat_option_bool("force_compat") == true; }
			set { set_compat_option_bool("force_compat", value); notify_property("use-compat"); }
		}

		public bool use_compat
		{
			get { return force_compat || needs_compat; }
		}

		protected void dbinit_compat(Sqlite.Statement s)
		{
			compat_tool = DB.Tables.Games.COMPAT_TOOL.get(s);
			compat_tool_settings = DB.Tables.Games.COMPAT_TOOL_SETTINGS.get(s);
		}

		public Json.Node? get_compat_settings(CompatTool tool)
		{
			if(compat_tool_settings != null && compat_tool_settings.length > 0)
			{
				var root = Parser.parse_json(compat_tool_settings);
				if(root != null && root.get_node_type() == Json.NodeType.OBJECT)
				{
					var obj = root.get_object();
					if(obj.has_member(tool.full_id))
					{
						return obj.get_member(tool.full_id);
					}
				}
			}
			return null;
		}

		public void set_compat_settings(CompatTool tool, Json.Node? settings)
		{
			var root_object = new Json.Object();
			if(compat_tool_settings != null && compat_tool_settings.length > 0)
			{
				var root = Parser.parse_json(compat_tool_settings);
				if(root != null && root.get_node_type() == Json.NodeType.OBJECT)
				{
					root_object = root.get_object();
				}
			}
			if(settings == null && root_object.has_member(tool.full_id))
			{
				root_object.remove_member(tool.full_id);
			}
			else
			{
				root_object.set_member(tool.full_id, settings);
			}
			var root_node = new Json.Node(Json.NodeType.OBJECT);
			root_node.set_object(root_object);
			compat_tool_settings = Json.to_string(root_node, false);
			save();
		}

		public bool? get_compat_option_bool(string key)
		{
			if(compat_tool_settings != null && compat_tool_settings.length > 0)
			{
				var root = Parser.parse_json(compat_tool_settings);
				if(root != null && root.get_node_type() == Json.NodeType.OBJECT)
				{
					var obj = root.get_object();
					if(obj.has_member(key)) return obj.get_boolean_member(key);
				}
			}
			return null;
		}

		public void set_compat_option_bool(string key, bool? value)
		{
			var root_object = new Json.Object();
			if(compat_tool_settings != null && compat_tool_settings.length > 0)
			{
				var root = Parser.parse_json(compat_tool_settings);
				if(root != null && root.get_node_type() == Json.NodeType.OBJECT)
				{
					root_object = root.get_object();
				}
			}
			if(value != null)
			{
				root_object.set_boolean_member(key, value);
			}
			else
			{
				root_object.remove_member(key);
			}
			var root_node = new Json.Node(Json.NodeType.OBJECT);
			root_node.set_object(root_object);
			compat_tool_settings = Json.to_string(root_node, false);
			save();
		}

		public ArrayList<CompatTool> get_supported_compat_tools()
		{
			var tools = new ArrayList<CompatTool>();
			/*foreach(var tool in CompatTools)
			{
				if(tool.installed && tool.can_run(this))
				{
					tools.add(tool);
				}
			}*/
			return tools;
		}

		public ArrayList<CompatTool> get_supported_compat_tools_for_installation(InstallTask task)
		{
			var tools = new ArrayList<CompatTool>();
			/*foreach(var tool in CompatTools)
			{
				if(tool.installed && tool.can_install(this, task))
				{
					tools.add(tool);
				}
			}*/
			return tools;
		}
	}
}
