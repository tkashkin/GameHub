using Gee;
using GameHub.Utils;
using LevelDB;

namespace GameHub.Data.Sources.Steam
{
	private class SteamCollectionDatabase
	{
		private string db_path = FSUtils.Paths.Steam.Home + "/" + FSUtils.Paths.Steam.LevelDB;
		private string steamid3;
		private LevelDB.Database db;
		private LevelDB.Options db_options = new LevelDB.Options();
		private LevelDB.ReadOptions db_read_options = new LevelDB.ReadOptions();
		private LevelDB.WriteOptions db_write_options = new LevelDB.WriteOptions();
		private ByteArray key_prefix = new ByteArray();
		private ByteArray namespaces_prefix = new ByteArray();
		private HashMap<ByteArray, Json.Node> namespace_collections = new HashMap<ByteArray, Json.Node>();
		private LinkedList<ByteArray> namespaces = new LinkedList<ByteArray>();

		public SteamCollectionDatabase(string communityid, out string? error)
		{
			steamid3 = Steam.communityid_to_steamid3(uint64.parse(communityid)).to_string();

			//  "_https://steamloopback.host\x0\x1U$(steamid3)-cloud-storage-namespace"
			key_prefix.append("_https://steamloopback.host".data);
			key_prefix.append({ 0, 1 });
			key_prefix.append(@"U$(steamid3)-cloud-storage-namespace".data);

			//  "_https://steamloopback.host\x0\x1U$(steamid3)-cloud-storage-namespaces"
			namespaces_prefix = new ByteArray.take(key_prefix.data);
			namespaces_prefix.append("s".data);

			db_options.set_create_if_missing(false);

			db = new LevelDB.Database(db_options, db_path, out error);
			if(error != null) return;
		}

		// Initially read the database and convert values we care about into json
		public void read(out string? error)
		{
			// 0x01[[1,"413"], ...]
			var namespaces_raw_json = db.get(db_read_options, namespaces_prefix.data, out error);
			if(error != null) return;

			var namespaces_json = Parser.parse_json(((string) prepare_bytes(namespaces_raw_json).data));
			if(namespaces_json == null || namespaces_json.get_node_type() != Json.NodeType.ARRAY) return;

			namespaces_json.get_array().foreach_element((array, index, node) =>
			{
				// [1,"413"]
				if(node == null || node.get_node_type() != Json.NodeType.ARRAY) return;
				if(node.get_array().get_length() < 1) return;

				//  "_https://steamloopback.host\x0\x1U$(steamid3)-cloud-storage-namespace-1"
				var namespace_key = new ByteArray.take(key_prefix.data);
				namespace_key.append(@"-$(node.get_array().get_int_element(0))".data);
				if(!namespaces.add(namespace_key)) return;
			});

			bool abort = false;
			namespaces.foreach((namespace_key) =>
			{
				string? e;

				var namespace_value = db.get(db_read_options, namespace_key.data, out e);
				if(namespace_value == null || e != null)
				{
					warning(@"[Sources.Steam.SteamCollectionsDatabase.Read] Error reading namespace: `%s`: `%s`", (string) prepare_bytes(namespace_key.data).data, e);
					return false;
				}

				//  debug_bytes(namespace_value);
				var namespace_json = unserialize_collections((string) prepare_bytes(namespace_value).data);
				if(namespace_json == null)
				{
					abort = true;
					return false;
				}

				namespace_collections.set(namespace_key, namespace_json);
				return true;
			});

			if(abort)
			{
				error = "Error parsing json";
				return;
			}
		}

		//  Example:
		//  [
		//  	"user-collections.gh-gamehub",
		//  	{
		//  		"key": "user-collections.gh-gamehub",
		//  		"timestamp": 1587322550,
		//  		"value": {
		//  			"id": "gh-gamehub",
		//  			"name": "gamehub",
		//  			"added": [
		//  			],
		//  			"removed":[
		//  			]
		//  		},
		//  		"conflictResolutionMethod": "custom",
		//  		"strMethodId": "union-collections"
		//  	}
		//  ]
		private Json.Array? @get(string id)
		{
			foreach(var collection_set in namespace_collections.values)
			{
				var collections = collection_set.get_array().get_elements();

				foreach(var collection in collections)
				{
					if(collection.get_array().get_string_element(0) == id)
					{
						return collection.get_array();
					}
				}
			}
			return null;
		}

		//  This returns a json object associated to an id which is included in the "value" member.
		//  Example:
		//  {
		//  	"id" : "gh-gamehub",
		//  	"name" : "gamehub",
		//  	"added" : [
		//  	],
		//  	"removed" : [
		//  	]
		//  }
		public Json.Object? get_collection(string id)
		{
			var collection = @get(@"user-collections.$(id)");

			if(collection != null && !collection.get_object_element(1).has_member("is_deleted") && collection.get_object_element(1).has_member("value") && collection.get_object_element(1).get_member("value").get_node_type() == Json.NodeType.OBJECT)
			{
				return collection.get_object_element(1).get_object_member("value");
			}
			return null;
		}

		public GLib.List<unowned Json.Object> get_collections_with_game(int64 appid)
		{
			var filtered_collections = new GLib.List<unowned Json.Object>();

			foreach(var collection_set in namespace_collections.values)
			{
				var collections = collection_set.get_array().get_elements();
				foreach(var collection in collections)
				{
					if(collection.get_array().get_element(1).get_node_type() == Json.NodeType.OBJECT)
					{
						if(collection.get_array().get_object_element(1).has_member("value") && collection.get_array().get_object_element(1).get_member("value").get_node_type() == Json.NodeType.OBJECT)
						{
							if(collection.get_array().get_object_element(1).get_object_member("value").has_member("added") && collection.get_array().get_object_element(1).get_object_member("value").get_member("added").get_node_type() == Json.NodeType.ARRAY)
							{
								collection.get_array().get_object_element(1).get_object_member("value").get_array_member("added").foreach_element((array, index, node) =>
								{
									if(node.get_int() == appid) filtered_collections.append(collection.get_array().get_object_element(1).get_object_member("value"));
								});
							}
						}
					}
				}
			}
			return filtered_collections.copy();
		}

		// add or update a collection
		public void set_collection(string id, Json.Object value)
		{
			Json.Object? object = null;
			var array = @get(@"user-collections.$(id)");
			if(array == null)
			{
				array = new Json.Array();
				array.add_string_element(@"user-collections.$(id)");
			}

			if(array.get_length() > 1)
			{
				object = array.get_object_element(1);
			}

			if(object == null || object.has_member("is_deleted"))
			{
				object = new Json.Object();
				object.set_string_member("key", @"user-collections.$(id)");
				object.set_string_member("conflictResolutionMethod", "custom");
				object.set_string_member("strMethodId", "union-collections");
				array.add_object_element(object);
			}

			object.set_int_member("timestamp", new DateTime.now_utc().to_unix());
			object.set_object_member("value", value);

			// Update collection if already present
			foreach(var collection_set in namespace_collections.values)
			{
				var collections = collection_set.get_array().get_elements();
				foreach(var collection in collections)
				{
					if(collection.get_array().get_string_element(0) == @"user-collections.$(id)")
					{
						collection.get_array().remove_element(1);
						collection.get_array().add_object_element(object);
						return;
					}
				}
			}

			// collection is new, add it to the last namespace
			var collections = namespace_collections.get(namespaces.last());
			collections.get_array().add_array_element(array);
			namespace_collections.set(namespaces.last(), collections);
		}

		// First byte is 0x01 which causes trouble converting into a string, strip it
		// Last byte isn't always zero so make sure we can get a string by terminating with zero by ourself
		private ByteArray prepare_bytes(uint8[] raw_bytes)
		{
			var bytes = new ByteArray.take(raw_bytes[1:raw_bytes.length]);
			bytes.append({ 0 });
			return bytes;
		}

		private Json.Node? unserialize_collections(string raw_iso)
		{
			string? raw_json;
			try
			{
				// string has 'e4' for 'ä' so the character set can be Cp1252, ISO 8859-1 or ISO 8859-15
				// according to some random website ISO 8859-1 is often used for html ¯\_(ツ)_/¯
				raw_json = convert(raw_iso, -1, "UTF-8", "ISO 8859-1");
			} catch (Error e) {return null;}

			var root = Parser.parse_json(raw_json);
			if(root == null || root.get_node_type() != Json.NodeType.ARRAY) return null;

			root.get_array().foreach_element((array, index, node) =>
			{
				if(node == null || node.get_node_type() != Json.NodeType.ARRAY) return;

				var object = node.get_array().get_object_element(1);
				if(object == null) return;

				if(object.has_member("value") && object.get_member("value").get_value_type() == Type.STRING)
				{
					debug("test2");
					if(Parser.parse_json((string) object.get_string_member("value")).get_node_type() == Json.NodeType.OBJECT)
					{
						object.set_member("value", Parser.parse_json((string) object.get_string_member("value")));
					}
				}
			});

			return root;
		}

		private string? serialize_collections(Json.Node root)
		{
			if(root.get_node_type() != Json.NodeType.ARRAY) return null;
			string? raw_json;
			var generator = new Json.Generator();

			root.get_array().foreach_element((array, index, node) =>
			{
				if(node.get_node_type() != Json.NodeType.ARRAY) return;
				if(node.get_array().get_object_element(1).has_member("value") && node.get_array().get_object_element(1).get_member("value").get_node_type() == Json.NodeType.OBJECT)
				{
					var object = node.get_array().get_object_element(1).get_object_member("value");
					if(object == null) return;
					var new_object = new Json.Node(Json.NodeType.OBJECT);
					new_object.init_object(object);
					generator.set_root(new_object);
					node.get_array().get_object_element(1).remove_member("value");
					node.get_array().get_object_element(1).set_string_member("value", generator.to_data(null));
				}
			});
			generator.set_root(root);
			raw_json = generator.to_data(null);

			try
			{
				var raw_iso = convert(raw_json, -1, "ISO 8859-1", "UTF-8");

				// We've stripped the first byte, add it back
				return @"\x1$(raw_iso)";
			} catch (Error e) {return null;}
		}

		public void save(out string? error)
		{
			var write_batch = new LevelDB.WriteBatch();

			namespaces.foreach((k) =>
			{
				var raw_string = serialize_collections(namespace_collections.get(k)).data;
				if(raw_string == null) return false;

				debug(@"[Sources.Steam.SteamCollectionsDatabase.Save]\n$(serialize_collections(namespace_collections.get(k), false))");
				write_batch.put(k.data, raw_string);
				return true;
			});

			try
			{
				if(!FSUtils.copy(FSUtils.file(db_path), FSUtils.file(db_path + "~"), FileCopyFlags.OVERWRITE))
				{
					error = "Failed creating backup";
					return;
				}
			}
			catch (Error e)
			{
				error = e.message;
				return;
			}

			write_batch.write(db, db_write_options, out error);
			if(error != null) return;
		}

		private void debug_bytes(int8[] bytes)
		{
			// View raw bytes for debugging purposes
			string tmp = "";
			for(int i = 0; i < bytes.length; i++)
			{
				tmp = tmp + " %2x".printf(bytes[i]);
			}
			debug(tmp);
		}
	}
}
