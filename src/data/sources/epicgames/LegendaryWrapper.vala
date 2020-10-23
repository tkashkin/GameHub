using Gee;
using GameHub.Utils;

namespace GameHub.Data.Sources.EpicGames
{
	public struct LegendaryGame {
		string name;
		string id;
		string version;
	}

	public class LegendaryWrapper
	{
		private Regex regex = /\s?\*\s?(.+)\(App\sname:\s([a-zA-Z0-9]+)\s.\s[Vv]ersion:\s([^)]*)\)/;
		private Regex authValidationRegex = /credentials are still valid/;
		private Regex authSuccessRegex = /Successfully logged in as "([^"]+)/;
		private Regex sidExtractionRegex = /sid":"([^"]+)/;
		private Regex fileUserRegex = /displayName":\s"([^"]+)/;

		private FSUtils.Paths.Settings paths = FSUtils.Paths.Settings.instance;
		private Settings.Auth.EpicGames settings = Settings.Auth.EpicGames.instance;

		public LegendaryWrapper()
		{
		}

		public ArrayList<LegendaryGame?> getGames() {
			var result = new ArrayList<LegendaryGame?>();

			string? line = null;
			MatchInfo info;
			var output = new DataInputStream(new Subprocess.newv ({paths.legendary_command, "list-games"}, STDOUT_PIPE).get_stdout_pipe ());

			while ((line = output.read_line()) != null) {
				if (regex.match (line, 0, out info)) {
					LegendaryGame? g = {info.fetch (1),  info.fetch (2),  info.fetch (3)};
					result.add(g);
				}
			}
			return result;
		}

		public string get_image(string id)
		{
			string res = "";
			var file = File.new_for_path(Environment.get_home_dir () + "/.config/legendary/metadata/"+id+".json");

			if (file.query_exists ()) {
				var dis = new DataInputStream (file.read ());
				string line;
	
				while ((line = dis.read_line (null)) != null) {
					res += line;
				}
				var parser = new Json.Parser ();
				parser.load_from_data (res);
				var root_object = parser.get_root().get_object();
	
				var metadata = root_object.get_object_member ("metadata");
				var keyImages = metadata.get_array_member ("keyImages");
				var img = keyImages.get_object_element (0).get_string_member ("url");
				return img;
			}
			return "";
		}

		public void install(string id)
		{
			// FIXME: It can be done much better
			var process = new Subprocess.newv ({paths.legendary_command, "download", id}, STDOUT_PIPE | STDIN_PIPE);
			var input = new DataOutputStream(process.get_stdin_pipe ());
			var output = new DataInputStream(process.get_stdout_pipe ());
			string? line = null;
			input.put_string("y\n");
			while ((line = output.read_line()) != null) {
				debug("[EpicGames] %s", line);
			}
			refresh_installed = true;
		}

		public bool is_authenticated() {
			var savedSid = settings.sid;
			if (savedSid == "") savedSid = "test";
			debug("[LegendaryWrapper] Saved sid: %s", savedSid);

			string? output = null;
			string? error = null;
			new Subprocess.newv ({paths.legendary_command, "auth", "--sid", savedSid}, STDOUT_PIPE | STDERR_PIPE).communicate_utf8(null, null, out output, out error);

			if (output.contains("ERROR")) return false;
			else if(output.contains("Stored credentials are still valid")) return true;
			else if (error.contains("ERROR")) return false;
			else if(error.contains("Stored credentials are still valid")) return true;

			return false;
		}

		public string? get_username() {
			File userfile = File.new_for_path(GLib.Environment.get_home_dir () + "/.config/legendary/user.json");
			if (userfile.query_exists ()) {
				debug("[LegendaryWrapper] File user.json exists");
				var dis = new DataInputStream (userfile.read ());
				string line;
	
				MatchInfo match;
				while ((line = dis.read_line (null)) != null)
					if(fileUserRegex.match (line, 0, out match)) return match.fetch (1);

				return null;
			}else return null;
		}

		public async string? auth()
		{
			
			if(is_authenticated()) {
				var username = get_username();
				if (username != null) return username;
				
			}

			//Do auth process
			string url = "https://www.epicgames.com/id/login?redirectUrl=https://www.epicgames.com/id/api/redirect";
			var wnd = new GameHub.UI.Windows.WebAuthWindow(EpicGames.instance.name, url, "https://www.epicgames.com/id/api/redirect");

			
			string? username = null;
			wnd.pageLoaded.connect(page => {
				MatchInfo info;
				sidExtractionRegex.match(page, 0, out info);
				var sid = info.fetch(1);

				//Legendary auth with sid
				var output = new DataInputStream(new Subprocess.newv ({paths.legendary_command, "auth", "--sid", sid}, STDOUT_PIPE).get_stdout_pipe ());
				string? line = null;
				while ((line = output.read_line()) != null) {
					if(authSuccessRegex.match(line, 0, out info)) {
						username = info.fetch(1);
						settings.sid = sid;
						debug("[EpicGames] Successfully logged in as %s", username);

						Idle.add(auth.callback);
						break;
					}
				}
			});

			wnd.canceled.connect(() => Idle.add(auth.callback));

			wnd.set_size_request(550, 680);
			wnd.show_all();
			wnd.present();

			yield;
			return username;
		}

		public void uninstall(string id)
		{
			// FIXME: It can be done much better
			var process = new Subprocess.newv ({paths.legendary_command, "uninstall", id}, STDOUT_PIPE | STDIN_PIPE);
			var input = new DataOutputStream(process.get_stdin_pipe ());
			var output = new DataInputStream(process.get_stdout_pipe ());
			string? line = null;
			input.put_string("y\n");
			while ((line = output.read_line()) != null) {
				debug("[EpicGames] %s", line);
			}
			refresh_installed = true;
		}

		public void run(string id) {
			// FIXME: not good idea
			new Subprocess.newv ({paths.legendary_command, "launch", id}, STDOUT_PIPE);
		}

		private bool refresh_installed = true;
		private ArrayList<string> _installed = new ArrayList<string>();

		public bool is_installed(string id)
		{
			if(refresh_installed) {
				build_installed_list();
				refresh_installed = false;
			}
			return _installed.contains(id);
		}


		private void build_installed_list()
		{
			var installed_output = new DataInputStream(new Subprocess.newv ({paths.legendary_command, "list-installed"}, STDOUT_PIPE).get_stdout_pipe ());
			_installed.clear();
			string? line = null;
			MatchInfo info;
			while ((line = installed_output.read_line()) != null) {
				if (regex.match (line, 0, out info)) {
					_installed.add(info.fetch(2));
				}
			}
		}
		
	}
}