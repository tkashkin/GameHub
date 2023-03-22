/*
This file is part of GameHub.
Copyright (C) 2018-2019 Anatoliy Kashkin

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
		public DataInputStream? stream;

		public ListNode? root_node;

		public BinaryVDF(File? file)
		{
			this.file = file;
		}

		public virtual ListNode? read()
		{
			if(file == null || !file.query_exists()) return null;
			root_node = null;

			try
			{
				stream = new DataInputStream(file.read());
				stream.set_byte_order(DataStreamByteOrder.LITTLE_ENDIAN);

				root_node = Node.read(stream);

				stream.close();
				stream = null;
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
			public string? key;

			public static ListNode? read(DataInputStream stream, string? list_key=null) throws Error
			{
				var list = new ListNode(list_key, stream);
				while(true)
				{
					var type = stream.read_byte();
					if(type == ListNode.END) break;

					string key = stream.read_upto("\0", 1, null);
					stream.read_byte();

					switch(type)
					{
						case ListNode.START:
							list.add_node(read(stream, key));
							break;

						case StringNode.START:
							list.add_node(new BinaryVDF.StringNode(key, stream));
							break;

						case IntNode.START:
							list.add_node(new BinaryVDF.IntNode(key, stream));
							break;

						default:
							throw new VDFError.UNKNOWN_NODE_TYPE("Unknown node type: %#04x (at %s)", type, stream.tell().to_string());
					}
				}
				return list;
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

			public ListNode(string? key, DataInputStream stream) throws Error
			{
				this.key = key;
			}

			public ListNode.node(string? key)
			{
				this.key = key;
			}

			public void add_node(Node node)
			{
				nodes.set(node.key, node);
			}

			public Node? get(string key)
			{
				return nodes.get(key);
			}

			public Node? get_nested(string[] keys, Node? def=null)
			{
				ListNode? list = this;
				Node? node = null;
				foreach(var key in keys)
				{
					node = list.get(key);
					if(node != null && node is ListNode)
					{
						list = (ListNode) node;
					}
					else
					{
						return node ?? def;
					}
				}
				return node ?? def;
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

			public StringNode(string? key, DataInputStream stream) throws Error
			{
				this.key = key;
				this.value = stream.read_upto("\0", 1, null);
				stream.read_byte();
			}

			public StringNode.node(string? key, string value)
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

			public IntNode(string? key, DataInputStream stream) throws Error
			{
				this.key = key;
				this.value = stream.read_int32();
			}

			public IntNode.node(string? key, int32 value)
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

	public class AppInfoVDF: BinaryVDF
	{
		public const string ROOT = "apps";

		private const uint16 MAGIC = 0x5644;

		public AppInfoVDF(File? file)
		{
			base(file);
		}

		public override BinaryVDF.ListNode? read()
		{
			if(file == null || !file.query_exists()) return null;

			var apps = new BinaryVDF.ListNode.node(ROOT);

			try
			{
				stream = new DataInputStream(file.read());
				stream.set_byte_order(DataStreamByteOrder.LITTLE_ENDIAN);

				stream.seek(0, SeekType.END);
				var size = stream.tell();
				stream.seek(0, SeekType.SET);

				read_header();

				while(stream.tell() < size)
				{
					var appid = stream.read_uint32();
					if(appid == 0) break;

					stream.seek(64, SeekType.CUR);

					var app = BinaryVDF.Node.read(stream, appid.to_string());
					if(app != null)
					{
						apps.add_node(app);
					}
				}

				stream.close();
			}
			catch(Error e)
			{
				warning("[AppInfoVDF] Error reading `%s`: %s", file.get_path(), e.message);
			}
			return apps;
		}

		private void read_header() throws Error
		{
			stream.read_byte();
			uint16 magic = stream.read_int16();
			if(magic != MAGIC)
			{
				throw new AppInfoError.UNSUPPORTED_FILE_TYPE("Unsupported file type: %#06x", magic);
			}
			stream.seek(5, SeekType.CUR);
		}
	}

	public class PackageInfoVDF: BinaryVDF
	{
		public const string ROOT = "packages";

		private const uint16 MAGIC = 0x5655;
		private const uint8[] BYTES_PACKAGEID = { 0x00, 0x02, 0x70, 0x61, 0x63, 0x6B, 0x61, 0x67, 0x65, 0x69, 0x64, 0x00 };
		private const uint8[] BYTES_APPIDS    = { 0x08, 0x00, 0x61, 0x70, 0x70, 0x69, 0x64, 0x73, 0x00 };

		public PackageInfoVDF(File? file)
		{
			base(file);
		}

		public override BinaryVDF.ListNode? read()
		{
			if(file == null || !file.query_exists()) return null;

			var packages = new BinaryVDF.ListNode.node(ROOT);

			try
			{
				stream = new DataInputStream(file.read());
				stream.set_byte_order(DataStreamByteOrder.LITTLE_ENDIAN);

				stream.seek(0, SeekType.END);
				var size = stream.tell();
				stream.seek(0, SeekType.SET);

				read_header();

				while(stream.tell() < size)
				{
					seek_to(BYTES_PACKAGEID, size);
					if(stream.tell() >= size) break;

					var pkgid = stream.read_uint32();

					seek_to(BYTES_APPIDS, size);
					if(stream.tell() >= size) break;

					string[] appids = {};

					while(stream.read_byte() == 0x02)
					{
						while(stream.read_byte() != 0x00);
						appids += stream.read_uint32().to_string();
					}

					packages.add_node(new PackageNode(pkgid.to_string(), appids));
				}

				stream.close();
			}
			catch(Error e)
			{
				warning("[PackageInfoVDF] Error reading `%s`: %s", file.get_path(), e.message);
			}
			return packages;
		}

		private void read_header() throws Error
		{
			stream.read_byte();
			uint16 magic = stream.read_int16();
			if(magic != MAGIC)
			{
				throw new PackageInfoError.UNSUPPORTED_FILE_TYPE("Unsupported file type: %#06x", magic);
			}
			stream.seek(1, SeekType.CUR);
		}

		private void seek_to(uint8[] bytes, int64 size) throws Error
		{
			int i = 0;

			while(i < bytes.length && stream.tell() < size)
			{
				uint8 b = stream.read_byte();
				if(b == bytes[i])
				{
					i++;
				}
				else if(i != 0)
				{
					i = 0;
					if(b == bytes[i])
					{
						i++;
					}
				}
			}
		}

		public class PackageNode: BinaryVDF.Node
		{
			public string id;
			public string[] appids;

			public PackageNode(string pkgid, string[] appids)
			{
				this.key = this.id = pkgid;
				this.appids = appids;
			}

			public override void show(int indent=0)
			{
				print_indent(indent);
				print("|- [Package: %s] %s\n", id, string.joinv(", ", appids));
			}

			public override void write(DataOutputStream stream) throws Error
			{
				throw new PackageInfoError.WRITING_IS_NOT_IMPLEMENTED("Writing is not implemented");
			}
		}
	}

	public errordomain VDFError { UNKNOWN_NODE_TYPE }
	public errordomain AppInfoError { UNSUPPORTED_FILE_TYPE }
	public errordomain PackageInfoError { UNSUPPORTED_FILE_TYPE, WRITING_IS_NOT_IMPLEMENTED }
}
