using GLib;
using Gee;
using Soup;

namespace GameHub.Utils
{
	public class Parser
	{
		private static string load_file(string path, string file="")
		{
			var full_path = FSUtils.expand(path, file);
			string data;
			try
			{
				FileUtils.get_contents(full_path, out data);
			}
			catch(Error e)
			{
				error(e.message);
			}
			return data;
		}
		
		private static string load_remote_file(string url, string method="GET", string? auth = null)
		{
			var session = new Session();
			var message = new Message(method, url);
			
			if(auth != null)
			{
				var h = @"Bearer $(auth)";
				print("Authorization: %s\n", h);
				message.request_headers.append("Authorization", h);
			}
			
			var status = session.send_message(message);
			if (status == 200) return (string) message.response_body.data;
			return "";
		}
		
		private static async string load_remote_file_async(string url, string method="GET", string? auth = null)
		{
			var result = "";
			var session = new Session();
			var message = new Message(method, url);
			
			if(auth != null)
			{
				message.request_headers.append("Authorization", "Bearer " + auth);
			}
			
			session.queue_message(message, (s, m) => {
				if(m.status_code == 200) result = (string) m.response_body.data;
				Idle.add(load_remote_file_async.callback);
			});
			yield;
			return result;
		}
		
		public static Json.Object parse_json(string json)
		{
			try
			{
				var parser = new Json.Parser();
				parser.load_from_data(json);
				return parser.get_root().get_object();
			}
			catch(GLib.Error e)
			{
				error(e.message);
			}
			return new Json.Object();
		}
		
		public static Json.Object parse_vdf(string vdf)
		{
			return parse_json(vdf_to_json(vdf));
		}
		
		public static Json.Object parse_json_file(string path, string file="")
		{
			return parse_json(load_file(path, file));
		}
		
		public static Json.Object parse_vdf_file(string path, string file="")
		{
			return parse_vdf(load_file(path, file));
		}
		
		public static Json.Object parse_remote_json_file(string url, string method="GET", string? auth = null)
		{
			return parse_json(load_remote_file(url, method, auth));
		}
		
		public static Json.Object parse_remote_vdf_file(string url, string method="GET", string? auth = null)
		{
			return parse_vdf(load_remote_file(url, method, auth));
		}
		
		public static async Json.Object parse_remote_json_file_async(string url, string method="GET", string? auth = null)
		{
			return parse_json(yield load_remote_file_async(url, method, auth));
		}
		
		public static async Json.Object parse_remote_vdf_file_async(string url, string method="GET", string? auth = null)
		{
			return parse_vdf(yield load_remote_file_async(url, method, auth));
		}
		
		public static Json.Object? json_object(Json.Object root, string[] keys)
		{
			Json.Object? obj = root;
			
			foreach(var key in keys)
			{
				if(obj != null && obj.has_member(key)) obj = obj.get_object_member(key);
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
				error(e.message);
			}
			
			return "{" + json + "}";
		}
	}
}
