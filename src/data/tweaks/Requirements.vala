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

			#if OS_LINUX
			if(kernel_modules != null && kernel_modules.size > 0)
			{
				var has_kmod = false;
				foreach(var kmod in kernel_modules)
				{
					if(OS.is_kernel_module_loaded(kmod))
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
			#endif

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
}
