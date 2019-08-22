using Gee;
using GameHub.Utils;

namespace GameHub.Data.Sources.Itch
{
    /**
     * JSON-RPC 2.0 client compatible with butler daemon
     * We have to make our own because jsonrpc-glib-1.0 prefixes messages
     * with Content-Length headers, while butler daemon expects one message
     * per line, deliminated by LF 
     */
    public class ButlerJsonrpcClient
    {
        private SocketConnection socket_connection;
        private int message_id = 0;
        private Sender sender;
        private Receiver receiver;

        public ButlerJsonrpcClient(SocketConnection socket_connection)
        {
            this.socket_connection = socket_connection;
            sender = new Sender(socket_connection.output_stream);
            receiver = new Receiver(socket_connection.input_stream);
        }

        public async Json.Object call(string method, Json.Node params = build_json_object())
        {
            message_id++;

            print("butler: <-- %i\n", message_id);
            sender.send(message_id, method, params);

            Json.Object result = yield receiver.get_reply(message_id);
            print("butler: --> %i\n", message_id);

            return result;
        }

        class Sender
        {
            private DataOutputStream data_output_stream;

            public Sender(OutputStream output_stream)
            {
                data_output_stream = new DataOutputStream(output_stream);
            }

            public void send(int message_id, string method, Json.Node params)
            {
                Json.Node request = build_json_object(builder => {
                    builder
                        .set_member_name("jsonrpc").add_string_value("2.0")
                        .set_member_name("id").add_int_value(message_id)
                        .set_member_name("method").add_string_value(method)
                        .set_member_name("params").add_value(params);
                });
                
                Json.Generator generator = new Json.Generator();
                generator.set_root(request);
                string json = generator.to_data(null);

                print("butler: <-- %s\n", json);
                data_output_stream.put_string(json + "\n");
            }
        }

        class Receiver
        {
            private DataInputStream data_input_stream;
            private HashMap<int, Json.Object> messages;

            public Receiver(InputStream input_stream)
            {
                data_input_stream = new DataInputStream(input_stream);
                data_input_stream.set_newline_type(DataStreamNewlineType.LF);
                messages = new HashMap<int, Json.Object>();
                handle_messages.begin();
            }

            async void handle_messages()
            {
                while(true) {
                    size_t length;
                    string json = yield data_input_stream.read_line_async();
                    print("butler: --> %s\n", json);

                    Json.Parser parser = new Json.Parser();
                    parser.load_from_data(json);

                    Json.Node node = parser.get_root();
                    Json.Object object = node.get_object();

                    int message_id = (int)object.get_int_member("id");
                    Json.Object result = object.get_object_member("result");
                    messages.set(message_id, result);
                }
            }

            public async Json.Object get_reply(int message_id)
            {
                while(!messages.has_key(message_id)) {
                    yield sleep_async(1);
                }
                Json.Object message;
                messages.unset(message_id, out message);
                return message;
            }
        }
    }
}