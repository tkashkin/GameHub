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
	public class TweakSet: Object
	{
		public bool is_global { get; construct; default = false; }
		public ArrayList<TweakOptions>? tweaks { get; set; default = null; }

		public signal void changed();

		public TweakSet.from_json(bool is_global, Json.Node? json)
		{
			ArrayList<TweakOptions> tweaks = null;

			if(json != null && json.get_node_type() == Json.NodeType.OBJECT)
			{
				var all_tweaks = Tweak.load_tweaks();
				tweaks = new ArrayList<TweakOptions>();

				json.get_object().foreach_member((obj, tweak_id, node) => {
					foreach(var tweak in all_tweaks.values)
					{
						if(tweak.id == tweak_id)
						{
							tweaks.add(new TweakOptions.from_json(tweak, node));
						}
					}
				});
			}

			Object(is_global: is_global, tweaks: tweaks);
		}

		public TweakOptions? get_options_for_id(string tweak_id)
		{
			if(tweaks == null || tweaks.size == 0) return null;
			foreach(var tweak_options in tweaks)
			{
				if(tweak_options.tweak.id == tweak_id) return tweak_options;
			}
			return null;
		}

		public void set_options_for_id(string tweak_id, TweakOptions? tweak_options)
		{
			var old_opts = get_options_for_id(tweak_id);
			if(old_opts != null)
			{
				tweaks.remove(old_opts);
			}
			if(tweak_options != null)
			{
				if(tweaks == null)
				{
					tweaks = new ArrayList<TweakOptions>();
				}
				tweaks.add(tweak_options);
			}
			changed();
		}

		public TweakOptions? get_options_for_tweak(Tweak tweak)
		{
			return get_options_for_id(tweak.id);
		}

		public void set_options_for_tweak(Tweak tweak, TweakOptions? tweak_options)
		{
			set_options_for_id(tweak.id, tweak_options);
		}

		public TweakOptions get_or_create_options(Tweak tweak)
		{
			return get_options_for_tweak(tweak) ?? new TweakOptions(tweak);
		}

		public TweakOptions get_or_create_global_options(Tweak tweak)
		{
			if(is_global)
			{
				return get_or_create_options(tweak);
			}
			return GameHub.Settings.Tweaks.global_tweakset.get_or_create_global_options(tweak);
		}

		public TweakOptions get_options_or_copy_global(Tweak tweak)
		{
			var local = get_options_for_tweak(tweak);
			if(local != null && (!tweak.has_options || local.has_properties)) return local;
			var global = get_or_create_global_options(tweak).copy();
			set_options_for_tweak(tweak, global);
			return global;
		}

		public TweakOptions get_options_or_use_global(Tweak tweak)
		{
			if(is_global)
			{
				return get_or_create_options(tweak);
			}
			var local = get_options_for_tweak(tweak);
			if(local != null && (!tweak.has_options || local.has_properties)) return local;
			return get_or_create_global_options(tweak);
		}

		public bool is_enabled(string tweak_id)
		{
			var opts = get_options_for_id(tweak_id);
			if(is_global)
			{
				return opts != null && opts.state == TweakOptions.State.ENABLED;
			}
			if(opts == null || opts.state == TweakOptions.State.GLOBAL)
			{
				return GameHub.Settings.Tweaks.global_tweakset.is_enabled(tweak_id);
			}
			return opts.state == TweakOptions.State.ENABLED;
		}

		public void reset()
		{
			tweaks = null;
			changed();
		}

		public Json.Node? to_json()
		{
			var node = new Json.Node(Json.NodeType.OBJECT);
			var obj = new Json.Object();

			if(tweaks != null && tweaks.size > 0)
			{
				foreach(var tweak_options in tweaks)
				{
					obj.set_member(tweak_options.tweak.id, tweak_options.to_json());
				}
			}

			node.set_object(obj);
			return node;
		}
	}
}
