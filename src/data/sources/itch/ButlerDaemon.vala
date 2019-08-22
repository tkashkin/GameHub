using GameHub.Utils;

namespace GameHub.Data.Sources.Itch
{
    public class ButlerDaemon
    {
        private bool have_credentials = false;
        private string address;
        private string secret;
        private DataInputStream stdout_stream;

        public ButlerDaemon()
        {
            string[] argv = {
                "butler",
                "daemon",
                "--json",
                "--transport", "tcp",
                "--dbpath", FSUtils.Paths.Cache.Home + "/butler.db",
                null
            };
            int stdout_fd;

            try {
                Process.spawn_async_with_pipes(
                    null,  // pwd
                    argv,
                    Environ.get(),
                    SpawnFlags.SEARCH_PATH,
                    null,  // setup function
                    null,  // pid
                    null,  // standard_input
                    out stdout_fd,
                    null); // standard_error

                stdout_stream = new DataInputStream(new UnixInputStream(stdout_fd, false));

            } catch (GLib.SpawnError e) {
                print ("SpawnError: %s\n", e.message);
            }
        }

        public async void get_credentials(out string address, out string secret)
        {
            while(!have_credentials) {
                string line = yield stdout_stream.read_line_async();

                Json.Node json_node = Parser.parse_json(line);
                if (json_node.get_node_type() == Json.NodeType.OBJECT) {
                    Json.Object json_object = json_node.get_object();

                    if(json_object.get_string_member("type") == "butlerd/listen-notification") {
                        address = ((!)json_object.get_object_member("tcp")).get_string_member("address");
                        secret = json_object.get_string_member("secret");
                        have_credentials = true;
                        return;
                    }
                }
            }
        }
    }
}
