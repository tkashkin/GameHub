/*
This file is part of GameHub.
Copyright(C) 2018-2019 Anatoliy Kashkin

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

/* Based on Granite.Services.Settings */

namespace GameHub.Settings
{
	public abstract class SettingsSchema: Object
	{
		bool saving_key;
		[Signal(no_recurse = true, run = "first", action = true, no_hooks = true, detailed = true)]
		public signal void changed();

		public GLib.Settings schema { get; construct; }

		protected SettingsSchema(string schema)
		{
			Object(schema: new GLib.Settings(schema));
		}

		construct
		{
			debug("Loading settings from schema '%s'", schema.schema_id);

			var obj_class = (ObjectClass) get_type().class_ref();
			var properties = obj_class.list_properties();
			foreach(var prop in properties)
				load_key(prop.name);

			start_monitor();
		}

		~SettingsSchema()
		{
			stop_monitor();
		}

		private void stop_monitor()
		{
			schema.changed.disconnect(load_key);
		}

		private void start_monitor()
		{
			schema.changed.connect(load_key);
		}

		void handle_notify(Object sender, ParamSpec property)
		{
			notify.disconnect(handle_notify);
			call_verify(property.name);
			notify.connect(handle_notify);
			save_key(property.name);
		}

		void handle_verify_notify(Object sender, ParamSpec property)
		{
			warning("Key '%s' failed verification in schema '%s', changing value", property.name, schema.schema_id);
		}

		private void call_verify(string key)
		{
			notify.connect(handle_verify_notify);
			verify(key);
			changed[key]();
			notify.disconnect(handle_verify_notify);
		}

		protected virtual void verify(string key){}

		private void load_key(string key)
		{
			if(key == "schema") return;

			var obj_class = (ObjectClass) get_type().class_ref();
			var prop = obj_class.find_property(key);

			if(prop == null)
				return;

			notify.disconnect(handle_notify);

			var type = prop.value_type;
			var val = Value(type);
			this.get_property(prop.name, ref val);

			if(val.type() == prop.value_type)
			{
				if(type == typeof(int))
					set_property(prop.name, schema.get_int(key));
				else if(type == typeof(uint))
					set_property(prop.name, schema.get_uint(key));
				else if(type == typeof(double))
					set_property(prop.name, schema.get_double(key));
				else if(type == typeof(string))
					set_property(prop.name, schema.get_string(key));
				else if(type == typeof(string[]))
					set_property(prop.name, schema.get_strv(key));
				else if(type == typeof(bool))
					set_property(prop.name, schema.get_boolean(key));
				else if(type == typeof(int64))
					set_property(prop.name, schema.get_value(key).get_int64());
				else if(type == typeof(uint64))
					set_property(prop.name, schema.get_value(key).get_uint64());
				else if(type.is_enum())
					set_property(prop.name, schema.get_enum(key));
			}
			else
			{
				debug("Unsupported settings type '%s' for key '%s' in schema '%s'", type.name(), key, schema.schema_id);
				notify.connect(handle_notify);
				return;
			}

			call_verify(key);
			notify.connect(handle_notify);
		}

		void save_key(string key)
		{
			if(key == "schema" || saving_key) return;

			var obj_class = (ObjectClass) get_type().class_ref();
			var prop = obj_class.find_property(key);

			if(prop == null) return;

			bool success = true;

			saving_key = true;
			notify.disconnect(handle_notify);

			var type = prop.value_type;
			var val = Value(type);
			this.get_property(prop.name, ref val);

			if(val.type() == prop.value_type)
			{
				if(type == typeof(int))
				{
					if(val.get_int() != schema.get_int(key))
					{
						success = schema.set_int(key, val.get_int());
					}
				}
				else if(type == typeof(uint))
				{
					if(val.get_uint() != schema.get_uint(key))
					{
						success = schema.set_uint(key, val.get_uint());
					}
				}
				else if(type == typeof(int64))
				{
					if(val.get_int64() != schema.get_value(key).get_int64())
					{
						success = schema.set_value(key, new Variant.int64(val.get_int64()));
					}
				}
				else if(type == typeof(uint64))
				{
					if(val.get_uint64() != schema.get_value(key).get_uint64())
					{
						success = schema.set_value(key, new Variant.uint64(val.get_uint64()));
					}
				}
				else if(type == typeof(double))
				{
					if(val.get_double() != schema.get_double(key))
					{
						success = schema.set_double(key, val.get_double());
					}
				}
				else if(type == typeof(string))
				{
					if(val.get_string() != schema.get_string(key))
					{
						success = schema.set_string(key, val.get_string());
					}
				}
				else if(type == typeof(string[]))
				{
					string[] strings = null;
					this.get(key, &strings);
					if(strings != schema.get_strv(key))
					{
						success = schema.set_strv(key, strings);
					}
				}
				else if(type == typeof(bool))
				{
					if(val.get_boolean() != schema.get_boolean(key))
					{
						success = schema.set_boolean(key, val.get_boolean());
					}
				}
				else if(type.is_enum())
				{
					if(val.get_enum() != schema.get_enum(key))
					{
						success = schema.set_enum(key, val.get_enum());
					}
				}
			}
			else debug("Unsupported settings type '%s' for key '%s' in schema '%s'", type.name(), key, schema.schema_id);

			if(!success) warning("Key '%s' could not be written to.", key);

			notify.connect(handle_notify);
			saving_key = false;
		}
	}
}
