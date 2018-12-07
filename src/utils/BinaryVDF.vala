/*
This file is part of GameHub.
Copyright (C) 2018 Anatoliy Kashkin

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

using GLib;
using Gee;
using Soup;

namespace GameHub.Utils
{
	public class BinaryVDF
	{
		public File? file;

		public Node? root_node;

		public BinaryVDF(File? file)
		{
			this.file = file;
			read();
		}

		public Node? read()
		{
			if(file == null || !file.query_exists()) return null;

			root_node = null;

			try
			{
				var stream = new DataInputStream(file.read());
				stream.set_byte_order(DataStreamByteOrder.LITTLE_ENDIAN);

				stream.seek(0, SeekType.END);
				var size = stream.tell();
				stream.seek(0, SeekType.SET);

				while(stream.tell() < size)
				{
					var node = Node.read(stream);
					if(root_node == null)
					{
						root_node = node;
					}
				}

				stream.close();
			}
			catch(Error e)
			{
				warning("[BinaryVDF] Error reading `%s`: %s", file.get_path(), e.message);
			}

			return root_node;
		}

		public static void write(File? file, Node? node)
		{
			if(file == null || node == null) return;

			try
			{
				var stream = new DataOutputStream(file.replace(null, true, FileCreateFlags.NONE));
				stream.set_byte_order(DataStreamByteOrder.LITTLE_ENDIAN);

				node.write(stream);
				
				stream.put_byte(ListNode.END);

				stream.flush();
				stream.close();
			}
			catch(Error e)
			{
				warning("[BinaryVDF] Error writing `%s`: %s", file.get_path(), e.message);
			}
		}

		public abstract class Node
		{
			private static ArrayQueue<ListNode>? OpenedLists = null;

			public string key;

			public static Node? read(DataInputStream stream) throws Error
			{
				uint8 type = stream.read_byte();

				if(!(type in new uint8[]{ ListNode.START, ListNode.END, StringNode.START, IntNode.START }))
				{
					return null;
				}

				if(type == ListNode.END)
				{
					if(OpenedLists != null)
					{
						return OpenedLists.poll_head();
					}
					return null;
				}

				string key = stream.read_upto("\0", 1, null);
				stream.read_byte();

				switch(type)
				{
					case ListNode.START:
						if(OpenedLists == null)
						{
							OpenedLists = new ArrayQueue<ListNode>();
						}
						var list = new ListNode(key, stream);
						add_node(list);
						OpenedLists.offer_head(list);
						return list;

					case StringNode.START:
						var str = new StringNode(key, stream);
						add_node(str);
						return str;

					case IntNode.START:
						var i = new IntNode(key, stream);
						add_node(i);
						return i;
				}
				return null;
			}

			private static void add_node(Node node)
			{
				if(OpenedLists != null)
				{
					var list = OpenedLists.peek_head();
					if(list != null)
					{
						list.add_node(node);
					}
				}
			}

			public abstract void write(DataOutputStream stream) throws Error;

			protected void print_indent(int indent=0)
			{
				for(int i = 0; i < indent; i++)
				{
					print("  ");
				}
			}

			public abstract void show(int indent=0);
		}

		public class ListNode: Node
		{
			public const uint8 START = 0x00;
			public const uint8 END   = 0x08;

			public HashMap<string, Node> nodes = new HashMap<string, Node>();

			public ListNode(string key, DataInputStream stream) throws Error
			{
				this.key = key;
			}

			public ListNode.node(string key)
			{
				this.key = key;
			}

			public void add_node(Node node)
			{
				nodes.set(node.key, node);
			}

			public override void show(int indent=0)
			{
				print_indent(indent);
				print("|- [%s]\n", key);
				foreach(var node in nodes.values)
				{
					node.show(indent + 1);
				}
			}

			public override void write(DataOutputStream stream) throws Error
			{
				stream.put_byte(ListNode.START);
				stream.put_string(key);
				stream.put_byte(0);

				foreach(var node in nodes.values)
				{
					node.write(stream);
				}

				stream.put_byte(ListNode.END);
			}
		}

		public class StringNode: Node
		{
			public const uint8 START = 0x01;

			public string value;

			public StringNode(string key, DataInputStream stream) throws Error
			{
				this.key = key;
				this.value = stream.read_upto("\0", 1, null);
				stream.read_byte();
			}

			public StringNode.node(string key, string value)
			{
				this.key = key;
				this.value = value;
			}

			public override void show(int indent=0)
			{
				print_indent(indent);
				print("|- %s: %s\n", key, value);
			}

			public override void write(DataOutputStream stream) throws Error
			{
				stream.put_byte(StringNode.START);
				stream.put_string(key);
				stream.put_byte(0);
				stream.put_string(value);
				stream.put_byte(0);
			}
		}

		public class IntNode: Node
		{
			public const uint8 START = 0x02;

			public int32 value;

			public IntNode(string key, DataInputStream stream) throws Error
			{
				this.key = key;
				this.value = stream.read_int32();
			}

			public IntNode.node(string key, int32 value)
			{
				this.key = key;
				this.value = value;
			}

			public override void show(int indent=0)
			{
				print_indent(indent);
				print("|- %s: %d\n", key, value);
			}

			public override void write(DataOutputStream stream) throws Error
			{
				stream.put_byte(IntNode.START);
				stream.put_string(key);
				stream.put_byte(0);
				stream.put_int32(value);
			}
		}
	}
}
