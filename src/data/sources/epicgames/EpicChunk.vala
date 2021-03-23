using Gee;
using GameHub.Utils;

namespace GameHub.Data.Sources.EpicGames
{
	/**
	Chunks are 1 MiB of data which contains one or more parts of files
	 */
	private class Chunk
	{
		private const int64 header_magic = 0xB1FE3AA2;

		private Bytes  sha_hash          { get; default = new Bytes(null); }
		private uint8  stored_as         { get; default = 0; }
		private uint32 hash_type         { get; default = 0; } //  0x1 = rolling hash, 0x2 = sha hash, 0x3 = both
		private uint32 header_version    { get; default = 3; }
		private uint32 header_size       { get; default = 0; }
		private uint32 compressed_size   { get; default = 0; }
		private uint32 uncompressed_size { get; default = 1024 * 1024; }
		private uint64 hash              { get; default = 0; }

		private         uint32[] guid { get; default = new uint32[4]; }
		private string? _guid_str = null;
		private         uint32? _guid_num = null;

		private Bytes? raw_bytes = null;
		private Bytes? _data = null;

		internal Bytes data
		{
			get
			{
				if(_data == null)
				{
					if(compressed)
					{
						if(log_chunk) debug("[Sources.EpicGames.Chunk] chunk is compressed, uncompressing…");

						if(log_chunk) debug("[Sources.EpicGames.Chunk] compressed chunk size: %s", raw_bytes.length.to_string());

						try
						{
							var uncompressed_stream = new MemoryOutputStream.resizable();
							var zlib                = new ZlibDecompressor(ZlibCompressorFormat.ZLIB);
							var byte_stream         = new MemoryInputStream.from_bytes(raw_bytes);
							var converter_stream    = new ConverterOutputStream(uncompressed_stream, zlib);

							converter_stream.splice(byte_stream, OutputStreamSpliceFlags.NONE);

							uncompressed_stream.close();
							_data = uncompressed_stream.steal_as_bytes();
						}
						catch (Error e)
						{
							debug("[EpicChunk.data] error: %s", e.message);
						}
					}
					else
					{
						_data = raw_bytes;
					}

					raw_bytes = null;

					if(log_chunk) debug("[Sources.EpicGames.Chunk] uncompressed chunk size: %s", _data.length.to_string());
				}

				return _data;
			}

			//  set
			//  {
			//  	assert(value.length <= 1024 * 1024);

			//  	//  data is now uncompressed
			//  	if(compressed)
			//  	{
			//  		_stored_as ^= 0x1;
			//  	}

			//  	//  pad data to 1 MiB
			//  	_data = value;
			//  	if(value.length < 1024 * 1024)
			//  	{
			//  		var tmp = value.get_data();
			//  		tmp.resize(1024 * 1024 - value.length);
			//  		_data = new Bytes(tmp);
			//  	}

			//  	//  FIXME: recalculate hashes
			//  	//  _hash = get_hash(_data);
			//  	//  _sha_hash = sha(_data);
			//  	_hash_type = 0x3;
			//  }
		}

		internal string guid_str
		{
			get
			{
				if(_guid_str == null)
				{
					_guid_str = guid_to_readable_string(guid);
				}

				return _guid_str;
			}
		}

		internal uint32 guid_num
		{
			get
			{
				if(_guid_num == null)
				{
					_guid_num = guid_to_number(guid);
				}

				return _guid_num;
			}
		}

		internal bool compressed { get { return _stored_as == 1; } }

		internal Chunk.from_byte_stream(DataInputStream stream)
		{
			stream.set_byte_order(DataStreamByteOrder.LITTLE_ENDIAN);
			var head_start = stream.tell();

			try
			{
				var magic = stream.read_uint32();
				assert(magic == header_magic);

				_header_version  = stream.read_uint32();
				_header_size     = stream.read_uint32();
				_compressed_size = stream.read_uint32();

				for(var j = 0; j < 4; j++)
				{
					guid[j] = stream.read_uint32();
				}

				_hash      = stream.read_uint64();
				_stored_as = stream.read_byte();

				if(header_version >= 2)
				{
					_sha_hash  = stream.read_bytes(20);
					_hash_type = stream.read_byte();
				}

				if(header_version >= 3)
				{
					_uncompressed_size = stream.read_uint32();
				}

				assert(stream.tell() - head_start == header_size);

				raw_bytes = stream.read_bytes(compressed_size);
			}
			catch (Error e)
			{
				debug("error: %s", e.message);
			}

			if(log_chunk) debug(to_string());
		}

		//  TODO: public write() {}

		//  TODO: public static get_hash() {}
		//  https://github.com/derrod/legendary/blob/a2280edea8f7f8da9a080fd3fb2bafcabf9ee33d/legendary/utils/rolling_hash.py#L18

		internal string to_string()
		{
			return "<Chunk (guid=%s, stored_as=%s, hash_type=%s, header_version=%s, compressed_size=%s, uncompressed_size=%s)>".printf(
				guid_str,
				stored_as.to_string(),
				hash_type.to_string(),
				header_version.to_string(),
				compressed_size.to_string(),
				uncompressed_size.to_string());
		}
	}
}
