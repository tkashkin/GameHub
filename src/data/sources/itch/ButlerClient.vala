/*
This file is part of GameHub.
Copyright (C) 2018-2019 Anatoliy Kashkin
Copyright (C) 2019 Yaohan Chen

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

namespace GameHub.Data.Sources.Itch
{
	/**
	 * JSON-RPC 2.0 client compatible with butler daemon
	 * We have to make our own because jsonrpc-glib-1.0 prefixes messages
	 * with Content-Length headers, while butler daemon expects one message
	 * per line, deliminated by LF
	 */
	public class ButlerClient
	{
		private SocketConnection socket_connection;
		private int message_id = 0;
		private Sender sender;
		private Receiver receiver;

		public ButlerClient(SocketConnection socket_connection)
		{
			this.socket_connection = socket_connection;
			sender = new Sender(socket_connection.output_stream);
			receiver = new Receiver(socket_connection.input_stream);
		}

		public async Json.Object? call(string method, Json.Node? params=null, out Json.Object? error = null)
		{
			message_id++;
			sender.send(message_id, method, params);
			return (yield receiver.get_reply(message_id, out error));
		}

		private class Sender
		{
			private DataOutputStream stream;

			public Sender(OutputStream output_stream)
			{
				this.stream = new DataOutputStream(output_stream);
			}

			public void send(int message_id, string method, Json.Node? params=null)
			{
				var request = Parser.json(j => j
					.set_member_name("jsonrpc").add_string_value("2.0")
					.set_member_name("id").add_int_value(message_id)
					.set_member_name("method").add_string_value(method)
					.set_member_name("params").add_value(params ?? Parser.json())
				);

				try
				{
					var json = Json.to_string(request, false);
					stream.put_string(json + "\n");

					if(Application.log_verbose)
					{
						debug("[ButlerClient: req %d] %s", message_id, json);
					}
				}
				catch(Error e)
				{
					warning("[ButlerClient: req %d] Error while sending request: %s", message_id, e.message);
				}
			}
		}

		private class Receiver
		{
			private DataInputStream stream;
			private HashMap<int, Response?> responses;

			public Receiver(InputStream input_stream)
			{
				stream = new DataInputStream(input_stream);
				stream.set_newline_type(DataStreamNewlineType.LF);
				responses = new HashMap<int, Response?>();
				Utils.thread("ItchButlerClientReceiver", () => {
					handle_messages.begin();
				}, false);
			}

			private async void handle_messages()
			{
				while(true)
				{
					try
					{
						var json = yield stream.read_line_async();
						var root = Parser.parse_json(json);
						if(root == null || root.get_node_type() != Json.NodeType.OBJECT) continue;

						var obj = root.get_object();
						if(obj == null) continue;

						const int NO_ID = -1;
						var error_info = obj.has_member("error") ? (Json.Object?) obj.get_object_member("error") : null;
						var message_id = obj.has_member("id") ? (int) obj.get_int_member("id") : NO_ID;
						var result = obj.has_member("result") ? (Json.Object?) obj.get_object_member("result") : null;
						var params = obj.has_member("params") ? (Json.Object?) obj.get_object_member("params") : null;
						var method = obj.has_member("method") ? (string?) obj.get_string_member("method") : null;

						if(error_info != null && message_id != NO_ID) {
							// failure response
							responses.set(message_id, {error_info, false});
							warning("[ButlerClient: err %d] %s", message_id, json);
						} else if(result != null && message_id != NO_ID) {
							// success response
							responses.set(message_id, {result, true});
							if(Application.log_verbose)
							{
								debug("[ButlerClient: res %d] %s", message_id, json);
							}
						} else if(message_id != NO_ID) {
							// server request
							warning("[ButlerClient: srv %d] %s", message_id, json);
							// TODO handle server call
						} else if(params != null && method != null) {
							// notification
							info("[ButlerClient: ntf] %s", json);
							// TODO handle notification
						} else {
							warning("[ButlerClient: ???] %s", json);
						}

					}
					catch(Error e)
					{
						warning("[ButlerClient] Error while handling messages: %s", e.message);
					}
				}
			}

			public async Json.Object? get_reply(int message_id, out Json.Object? error = null)
			{
				while(!responses.has_key(message_id))
				{
					yield Utils.sleep_async(100);
				}
				Response response;
				responses.unset(message_id, out response);

				if(response.successful) {
					return response.content;
				} else {
					error = response.content;
					return null;
				}
			}

			struct Response
			{
				Json.Object content;
				bool successful;
			}
		}
	}
}
