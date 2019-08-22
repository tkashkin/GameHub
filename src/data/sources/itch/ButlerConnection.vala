using Json;
using Gee;

namespace GameHub.Data.Sources.Itch
{
    public class ButlerConnection
    {
        private ButlerJsonrpcClient client;

        public ButlerConnection(string address)
        {
            print("%s\n", address);
            SocketClient socket_client = new SocketClient();
            SocketConnection socket_connection = socket_client.connect_to_host(address, 0, null);
            client = new ButlerJsonrpcClient(socket_connection);
        }

        public async bool authenticate(string secret)
        {
            Json.Object result = yield client.call("Meta.Authenticate", build_json_object(builder => {
                builder.set_member_name("secret").add_string_value(secret);
            }));
            return result.get_boolean_member("ok");
        }

        public async bool login_with_api_key(string api_key, out string user_name, out int user_id)
        {
            Json.Object result = yield client.call("Profile.LoginWithAPIKey", build_json_object(builder => {
                builder.set_member_name("apiKey").add_string_value(api_key);
            }));

            Json.Object user = result.get_object_member("profile").get_object_member("user");
            user_name = user.get_string_member("username");
            user_id = (int)user.get_int_member("id");

            return true;
        }

        public async ArrayList<Json.Node> get_owned_keys(int profile_id, bool fresh)
        {
            Json.Object result = yield client.call("Fetch.ProfileOwnedKeys", build_json_object(json_builder => {
                json_builder
                    .set_member_name("profileId").add_int_value(profile_id)
                    .set_member_name("fresh").add_boolean_value(fresh);
            }));

            ArrayList<Json.Node> items = new ArrayList<Json.Node>();
            result.get_array_member("items").foreach_element((array, index, node) => {
                items.add(node.get_object().get_member("game"));
            });
            // next page

            return items;
        }
    }
}