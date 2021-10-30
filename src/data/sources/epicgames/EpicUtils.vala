using GameHub.Utils;

namespace GameHub.Data.Sources.EpicGames
{
	/** Converts a byte sequence into a lower case hex representation
	 */
	private static string bytes_to_hex(Bytes bytes) { return uint8_to_hex(bytes.get_data()); }

	/** Converts a byte sequence into a lower case hex representation
	 */
	private static string uint8_to_hex(uint8[] bytes)
	{
		var builder = new StringBuilder();

		foreach(var byte in bytes)
		{
			builder.append_printf("%02x", byte);
		}

		return builder.str;
	}

	/** Converts a number into a byte stream from which the value can be read
	 * in the correct endian.
	 *
	 * The JSON manifest use a rather strange format for storing numbers.
	 * It's essentially %03d for each char concatenated to a string.
	 * …instead of just putting the fucking number in the JSON…
	 * Also it's still little endian.
	 */
	private static DataInputStream number_string_to_byte_stream(string str)
	requires(str.length % 3 == 0)
	{
		var bytes = new ByteArray();

		for(var i = 0; i < str.length; i += 3)
		{
			int segment = 0;
			str.substring(i, 3).scanf("%03hu", out segment);
			bytes.append({ (uint8) segment });
		}

		var stream = new DataInputStream(new MemoryInputStream.from_data(bytes.steal()));
		stream.set_byte_order(DataStreamByteOrder.LITTLE_ENDIAN);

		return stream;
	}

	/** Converts a upper case hex string into a byte stream from which the value can be read
	 * in the correct endian.
	 */
	private static DataInputStream hex_string_to_byte_stream(string str)
	requires(str.length % 2 == 0)
	{
		var bytes = new ByteArray();

		for(var i = 0; i < str.length; i += 2)
		{
			int segment = 0;
			str.substring(i, 2).scanf("%02X", out segment);
			bytes.append({ (uint8) segment });
		}

		var stream = new DataInputStream(new MemoryInputStream.from_data(bytes.steal()));
		stream.set_byte_order(DataStreamByteOrder.LITTLE_ENDIAN);

		return stream;
	}

	/** Reads a upper case hex string into a uint32[4].
	 */
	private static uint32[] guid_from_hex_string(string str)
	requires(str.length == 32)
	{
		uint32[] result = new uint32[4];
		var      stream = hex_string_to_byte_stream(str);
		stream.set_byte_order(DataStreamByteOrder.BIG_ENDIAN);

		for(var i = 0; i < 4; i++)
		{
			try
			{
				result[i] = stream.read_uint32();
			}
			catch (Error e)
			{
				debug("error: %s", e.message);
			}
		}

		return result;
	}

	/** Converts a uint32 array to upper case hex string
	 */
	//   TODO: care about little endian?
	private static string guid_to_string(uint32[] guid)
	{
		var builder = new StringBuilder();

		foreach(var id in guid)
		{
			builder.append_printf("%08X", id);
		}

		return builder.str;
	}

	/** Converts a uint32 array to lower case hex string with dashes
	 */
	private static string guid_to_readable_string(uint32[] guid)
	{
		var builder = new StringBuilder();

		foreach(var id in guid)
		{
			builder.append_printf("%08x-", id);
		}

		//  strip last "-"
		return builder.str.substring(0, builder.str.length - 1);
	}

	private static uint32 guid_to_number(uint32[] guid) { return guid[3] + (guid[2] << 32) + (guid[1] << 64) + (guid[0] << 96); }

	private static string uppercase_first_character(string str)
	{
		//  Uppercase first character
		var     builder = new StringBuilder(str);
		var     i       = 0;
		unichar c;

		str.get_next_char(ref i, out c);
		builder.overwrite(0, c.to_string().up());

		//  debug("[Sources.EpicGames.Utils.uppercase] %s → %s", str, builder.str);
		return builder.str;
	}

	private static void write(string path, string name, uint8[] bytes)
	{
		var file = FS.file(path, name);

		try
		{
			FS.mkdir(path);
			FileUtils.set_data(file.get_path(), bytes);
		}
		catch (Error e)
		{
			warning("[Sources.EpicGames.write] Error writing `%s`: %s", file.get_path(), e.message);
		}
	}
}
