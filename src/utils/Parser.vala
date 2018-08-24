using GLib;
using Gee;
using Soup;

namespace GameHub.Utils
{
	public class Parser
	{
		public static string load_file(string path, string file="")
		{
			var f = FSUtils.file(path, file);
			if(!f.query_exists()) return "";
			string data;
			try
			{
				FileUtils.get_contents(f.get_path(), out data);
			}
			catch(Error e)
			{
				warning(e.message);
			}
			return data;
		}
		
		private static Message prepare_message(string url, string method="GET", string? auth = null, HashMap<string, string>? headers = null)
		{
			var message = new Message(method, url);
			
			if(auth != null)
			{
				message.request_headers.append("Authorization", "Bearer " + auth);
			}
			
			if(headers != null)
			{
				foreach(var header in headers.entries)
				{
					message.request_headers.append(header.key, header.value);
				}
			}
			
			return message;
		}
		
		public static string load_remote_file(string url, string method="GET", string? auth = null, HashMap<string, string>? headers = null)
		{
			var session = new Session();
			var message = prepare_message(url, method, auth, headers);
			
			var status = session.send_message(message);
			if (status == 200) return (string) message.response_body.data;
			return "";
		}
		
		public static async string load_remote_file_async(string url, string method="GET", string? auth = null, HashMap<string, string>? headers = null)
		{
			var result = "";
			var session = new Session();
			var message = prepare_message(url, method, auth, headers);
			
			session.queue_message(message, (s, m) => {
				if(m.status_code == 200) result = (string) m.response_body.data;
				Idle.add(load_remote_file_async.callback);
			});
			yield;
			return result;
		}
		
		public static Json.Node parse_json(string json)
		{
			try
			{
				var parser = new Json.Parser();
				parser.load_from_data(json);
				return parser.get_root();
			}
			catch(GLib.Error e)
			{
				warning(e.message);
			}
			return new Json.Node(Json.NodeType.NULL);
		}
		
		public static Json.Node parse_vdf(string vdf)
		{
			return parse_json(vdf_to_json(vdf));
		}
		
		public static Json.Node parse_json_file(string path, string file="")
		{
			return parse_json(load_file(path, file));
		}
		
		public static Json.Node parse_vdf_file(string path, string file="")
		{
			return parse_vdf(load_file(path, file));
		}
		
		public static Json.Node parse_remote_json_file(string url, string method="GET", string? auth = null, HashMap<string, string>? headers = null)
		{
			return parse_json(load_remote_file(url, method, auth, headers));
		}
		
		public static Json.Node parse_remote_vdf_file(string url, string method="GET", string? auth = null, HashMap<string, string>? headers = null)
		{
			return parse_vdf(load_remote_file(url, method, auth, headers));
		}
		
		public static async Json.Node parse_remote_json_file_async(string url, string method="GET", string? auth = null, HashMap<string, string>? headers = null)
		{
			return parse_json(yield load_remote_file_async(url, method, auth, headers));
		}
		
		public static async Json.Node parse_remote_vdf_file_async(string url, string method="GET", string? auth = null, HashMap<string, string>? headers = null)
		{
			return parse_vdf(yield load_remote_file_async(url, method, auth, headers));
		}
		
		public static Json.Object? json_object(Json.Node? root, string[] keys)
		{
			if(root == null || root.get_node_type() != Json.NodeType.OBJECT) return null;
			Json.Object? obj = root.get_object();
			
			foreach(var key in keys)
			{
				if(obj != null && obj.has_member(key))
				{
					var member = obj.get_member(key);
					if(member != null && member.get_node_type() == Json.NodeType.OBJECT)
					{
						obj = member.get_object();
					}
					else obj = null;
				}
				else obj = null;
				
				if(obj == null) break;
			}
			
			return obj;
		}
		
		private static string vdf_to_json(string vdf_data)
		{
			var json = vdf_data;
			
			try
			{
				var nl_commas = new Regex("(\"|\\})(\\s*?\\r?\\n\\s*?\")");
				var semicolons = new Regex("\"(\\s*?\\r?\\n?\\s*?(?:\"|\\{))");
			
				json = nl_commas.replace(json, json.length, 0, "\\g<1>,\\g<2>");
				json = semicolons.replace(json, json.length, 0, "\":\\g<1>");
			}
			catch(Error e)
			{
				warning(e.message);
			}
			
			return "{" + json + "}";
		}
	}
}
