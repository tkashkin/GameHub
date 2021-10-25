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
using GameHub.Data.Compat;
using GameHub.Data.Runnables;

namespace GameHub.Data.Tweaks
{
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
						if(compat_tool_id == id || compat_tool_id.has_prefix(@"$(id)_") || compat_tool_id.has_prefix(@"$(id):"))
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
