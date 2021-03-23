using Gee;

using GameHub.Utils;

namespace GameHub.Data.Sources.EpicGames
{
	internal class Manifest
	{
		private const uint32 header_magic = 0x44BEC00C;

		private Bytes  sha_hash          { get; default = new Bytes(null); }
		private uint8  stored_as         { get; default = 0; }
		private uint32 header_size       { get; default = 41; }
		private uint32 size_compressed   { get; default = 0; }
		private uint32 size_uncompressed { get; default = 0; }
		private uint32 version           { get; default = 18; }

		internal ChunkDataList? chunk_data_list { get; default = null; }
		//  TODO: CustomFields custom_fields;
		//  private Json.Node? custom_fields { get; default = null; }
		internal FileManifestList? file_manifest_list { get; default = null; }
		internal Meta?           meta                 { get; default = null; }

		internal bool compressed { get { return (stored_as & 0x1) != 0; } }

		internal Manifest.from_bytes(Bytes bytes)
		{
			read_byte_header(bytes);

			var body = bytes.slice(header_size, bytes.length);

			if(compressed)
			{
				if(log_manifest) debug("[Sources.EpicGames.Manifest.read_bytes] Data is compressed, uncompressing…");

				var zlib                = new ZlibDecompressor(ZlibCompressorFormat.ZLIB);
				var compressed_stream   = new MemoryInputStream.from_bytes(body);
				var uncompressed_stream = new MemoryOutputStream.resizable();
				var converter_stream    = new ConverterOutputStream(uncompressed_stream, zlib);

				try
				{
					converter_stream.splice(compressed_stream, OutputStreamSpliceFlags.NONE);
					uncompressed_stream.close();
				}
				catch (Error e)
				{
					debug("[Manifest.from_bytes]error: %s", e.message);
				}

				var data_uncompressed = uncompressed_stream.steal_as_bytes();
				assert(data_uncompressed.length == size_uncompressed);

				var decompressed_hash = Checksum.compute_for_bytes(ChecksumType.SHA1, data_uncompressed);

				if(log_manifest) debug("[Sources.EpicGames.Manifest.read_bytes] our hash: %s", decompressed_hash);

				assert(decompressed_hash == bytes_to_hex(sha_hash));
				body = data_uncompressed;
			}

			var stream = new DataInputStream(new MemoryInputStream.from_bytes(body));
			stream.set_byte_order(DataStreamByteOrder.LITTLE_ENDIAN);

			_meta               = new Meta.from_byte_stream(stream);
			_chunk_data_list    = new ChunkDataList.from_byte_stream(stream, meta.feature_level);
			_file_manifest_list = new FileManifestList.from_byte_stream(stream);
			//  TODO: custom_fields = new CustomFields(stream);

			var unhandled_data = new Bytes.from_bytes(body, (size_t) stream.tell(), bytes.length - (size_t) stream.tell());

			if(unhandled_data.length > 0)
			{
				debug(@"[Sources.EpicGames.Manifest.from_bytes] Did not read $(unhandled_data.length) remaining bytes in manifest!\n" +
				      "This may not be a problem.");
			}

			if(log_manifest) debug(to_string());
		}

		//  FIXME: json parsing is slow!
		internal Manifest.from_json(Json.Node json)
		{
			try
			{
				_version = number_string_to_byte_stream(json.get_object().get_string_member_with_default("ManifestFileVersion", "013000000000")).read_uint32();
			}
			catch (Error e) { debug("error: %s", e.message); }

			_meta               = new Meta.from_json(json);
			_chunk_data_list    = new ChunkDataList.from_json(json, version);
			_file_manifest_list = new FileManifestList.from_json(json);
			_stored_as          = 0; //  never compress
			//  custom_fields = new CustomFields();
			//  if(json.get_object().has_member("CustomFields"))
			//  {
			//  	//  TODO: custom_fields
			//  	//  custom_fields.dict = json_data.get_object().get_object_member("CustomFields");
			//  	//  debug("unhandled: %s", Json.to_string(json_data.get_object().get_member("CustomFields"), true));
			//  	_custom_fields = json.get_object().get_member("CustomFields");
			//  }

			//  TODO: unread keys
			if(log_manifest) debug(to_string());
		}

		private void read_byte_header(Bytes bytes)
		{
			var stream = new DataInputStream(new MemoryInputStream.from_bytes(bytes));
			stream.set_byte_order(DataStreamByteOrder.LITTLE_ENDIAN);

			try
			{
				var magic = stream.read_uint32();
				assert(magic == header_magic);

				_header_size       = stream.read_uint32();
				_size_uncompressed = stream.read_uint32();
				_size_compressed   = stream.read_uint32();
				_sha_hash          = stream.read_bytes(20);
				_stored_as         = stream.read_byte();
				_version           = stream.read_uint32();

				assert(stream.tell() == header_size);
			}
			catch (Error e)
			{
				debug("[Manifest.read_byte_header] error: %s", e.message);
			}
		}

		internal string to_string()
		{
			return "<Manifest (version=%s, stored_as=%s, size_compressed=%s, size_uncompressed=%s, metadata=\n%s\n, file_manifest_list=\n%s, chunk_data_list=\n%s, custom_fields=TODO)>".printf(
				version.to_string(),
				stored_as.to_string(),
				size_compressed.to_string(),
				size_uncompressed.to_string(),
				meta.to_string(),
				file_manifest_list.to_string(),
				chunk_data_list.to_string());
		}

		/**
		* Contains metadata about the game.
		*
		* @param feature_level Usually same as {@link manifest_version}, but can be different e.g. if JSON manifest has been converted to binary manifest.
		* @param is_file_data This was used for very old manifests that didn't use chunks at all
		* @param app_id 0 for most apps, generally not used
		* @param prereq_ids This is a list though I've never seen more than one entry
		 */
		internal class Meta
		{
			internal ArrayList<string> prereq_ids     { get; default = new ArrayList<string>(); }
			internal bool              is_file_data   { get; default = false; }
			internal string            app_name       { get; default = ""; }
			internal string            build_version  { get; default = ""; }
			internal string            launch_exe     { get; default = ""; }
			internal string            launch_command { get; default = ""; }
			internal string            prereq_name    { get; default = ""; }
			internal string            prereq_path    { get; default = ""; }
			internal string            prereq_args    { get; default = ""; }
			internal uint8             data_version   { get; default = 0; }
			internal uint32            app_id         { get; default = 0; }
			internal uint32            feature_level  { get; default = 18; }
			internal uint32            meta_size      { get; default = 0; }

			//  this build id is used for something called "delta file"
			internal string? _build_id = null;
			internal string  build_id
			{
				get
				{
					if(_build_id != null) return _build_id;

					//  https://github.com/derrod/legendary/blob/master/legendary/models/manifest.py#L196
					Checksum checksum = new Checksum(ChecksumType.SHA1);

					var variant = new Variant.uint32(app_id);
					variant.byteswap(); // FIXME: instead of hardcoded swapping try to set endian directly
					checksum.update(variant.get_data_as_bytes().get_data(),
					                variant.get_data_as_bytes().get_data().length);
					checksum.update(app_name.data, -1);
					checksum.update(build_version.data, -1);
					checksum.update(launch_exe.data, -1);
					checksum.update(launch_command.data, -1);

					uint8[] hash = new uint8[ChecksumType.SHA1.get_length()];
					size_t  size = ChecksumType.SHA1.get_length();
					checksum.get_digest(hash, ref size);

					try
					{
						_build_id = convert(Base64.encode(hash).replace("+", "-").replace("/", "_").replace("=", ""),
						                    -1,
						                    "ASCII",
						                    "UTF-8");
					}
					catch (Error e)
					{
						debug("build_id convert failed");
					}

					if(log_meta) debug(@"build_id: $build_id");

					return _build_id;
				}
			}

			internal Meta.from_json(Json.Node json_data)
			{
				var json_obj = json_data.get_object();

				try
				{
					_is_file_data   = json_obj.get_boolean_member_with_default("bIsFileData", false);
					_app_name       = json_obj.get_string_member_with_default("AppNameString", "");
					_build_version  = json_obj.get_string_member_with_default("BuildVersionString", "");
					_launch_exe     = json_obj.get_string_member_with_default("LaunchExeString", "");
					_launch_command = json_obj.get_string_member_with_default("LaunchCommand", "");
					_feature_level  = number_string_to_byte_stream(json_obj.get_string_member_with_default("ManifestFileVersion", "013000000000")).read_uint32();
					_app_id         = number_string_to_byte_stream(json_obj.get_string_member_with_default("AppID", "000000000000")).read_uint32();
				}
				catch (Error e) { debug("error: %s", e.message); }

				//  TODO: we don't care about this yet
				//  _prereq_name = json_obj.get_string_member_with_default("PrereqName", "");
				//  _prereq_path = json_obj.get_string_member_with_default("PrereqPath", "");
				//  _prereq_args = json_obj.get_string_member_with_default("PrereqArgs", "");
				//  if(json_obj.has_member("PrereqIds"))
				//  {
				//  	json_obj.get_array_member("PrereqIds").foreach_element(
				//  		(array, index, node) => {
				//  		prereq_ids.add(node.get_string());
				//  	});
				//  }

				if(log_meta) debug(to_string());
			}

			internal Meta.from_byte_stream(DataInputStream stream)
			{
				try
				{
					_meta_size    = stream.read_uint32();
					_data_version = stream.read_byte();

					//  Usually same as manifest version, but can be different
					//  e.g. if JSON manifest has been converted to binary manifest.
					_feature_level = stream.read_uint32();

					//  This was used for very old manifests that didn't use chunks at all
					_is_file_data = stream.read_byte() == 1;

					//  0 for most apps, generally not used
					_app_id = stream.read_uint32();

					_app_name       = read_fstring(stream);
					_build_version  = read_fstring(stream);
					_launch_exe     = read_fstring(stream);
					_launch_command = read_fstring(stream);

					//  This is a list though I've never seen more than one entry
					var entries = stream.read_uint32();

					for(var i = 0; i < entries; i++)
					{
						prereq_ids.add(read_fstring(stream));
					}

					_prereq_name = read_fstring(stream);
					_prereq_path = read_fstring(stream);
					_prereq_args = read_fstring(stream);

					//  apparently there's a newer version that actually stores *a* build id.
					if(data_version > 0)
					{
						_build_id = read_fstring(stream);
					}

					assert(stream.tell() == meta_size);
				}
				catch (Error e) {}

				if(log_meta) debug(to_string());
			}

			internal string to_string()
			{
				return "<Meta (data_version=%s, app_id=%s, feature_level=%s, meta_size=%s, app_name=%s, build_version=%s, launch_exe=%s, launch_command=%s, build_id=%s)>".printf(
					data_version.to_string(),
					app_id.to_string(),
					feature_level.to_string(),
					meta_size.to_string(),
					app_name,
					build_version,
					launch_exe,
					launch_command,
					build_id);
			}
		}

		/**
		* Contains all file information.
		*
		* @param count How many files the game ships with.
		* @param size Size all files sum up to.
		 */
		internal class FileManifestList
		{
			private HashMap<string, int>? path_map = null;

			internal ArrayList<FileManifest> elements { get; default = new ArrayList<FileManifest>(); }
			internal uint8                   version  { get; default = 0; }
			internal uint32                  count    { get; default = 0; }
			internal uint32                  size     { get; default = 0; }

			internal FileManifestList.from_byte_stream(DataInputStream stream)
			{
				var start = stream.tell();

				try
				{
					_size    = stream.read_uint32();
					_version = stream.read_byte();
					_count   = stream.read_uint32();
				}
				catch (Error e) {}

				for(var i = 0; i < count; i++)
				{
					elements.add(new FileManifest());
				}

				elements.foreach(file_manifest => {
					file_manifest.filename = read_fstring(stream);

					return true;
				});

				//  never seen this used in any of the manifests I checked but can't wait for something to break because of it
				elements.foreach(file_manifest => {
					file_manifest.symlink_target = read_fstring(stream);

					return true;
				});

				//  For files this is actually the SHA1 instead of whatever it is for chunks…
				elements.foreach(file_manifest => {
					try
					{
						file_manifest.hash = stream.read_bytes(20);
					}
					catch (Error e) {}

					return true;
				});

				//  Flags, the only one I've seen is for executables
				elements.foreach(file_manifest => {
					try
					{
						file_manifest.flags = stream.read_byte();
					}
					catch (Error e) {}

					return true;
				});

				//  install tags, no idea what they do, I've only seen them in the Fortnite manifest
				elements.foreach(file_manifest => {
					try
					{
						var _count = stream.read_uint32();

						for(var i = 0; i < _count; i++)
						{
							file_manifest.install_tags.add(read_fstring(stream));
						}
					}
					catch (Error r) {}

					return true;
				});

				//  Each file is made up of "Chunk Parts" that can be spread across the "chunk stream"
				elements.foreach(file_manifest => {
					try
					{
						var _count = stream.read_uint32();
						uint offset = 0;

						for(var i = 0; i < _count; i++)
						{
							var chunk_part = new FileManifest.ChunkPart.from_byte_stream(stream, offset);
							file_manifest.chunk_parts.add(chunk_part);
							offset += chunk_part.size;
						}
					}
					catch (Error e) {}

					return true;
				});

				//  we have to calculate the actual file size ourselves
				elements.foreach(file_manifest => {
					uint _size = 0;
					file_manifest.chunk_parts.foreach(chunk_part => {
						_size += chunk_part.size;

						return true;
					});

					file_manifest.file_size = _size;

					return true;
				});

				assert(stream.tell() - start == size);

				if(log_file_manifest_list) debug(to_string());
			}

			internal FileManifestList.from_json(Json.Node json_data)
			{
				var json_arr = json_data.get_object().get_array_member("FileManifestList");
				_count = json_arr.get_length();

				json_arr.foreach_element((array, index, node) => {
					var file_manifest = new FileManifest();

					var file_manifest_json = node.get_object();

					file_manifest.filename = file_manifest_json.get_string_member_with_default("Filename", "");

					try
					{
						var hash           = file_manifest_json.get_string_member("FileHash"); // 20 bytes as %03d number string
						file_manifest.hash = number_string_to_byte_stream(hash).read_bytes(20);
					}
					catch (Error e) { debug("error: %s", e.message); }

					file_manifest.flags |= (int) file_manifest_json.get_boolean_member_with_default("bIsReadOnly", false);
					file_manifest.flags |= (int) file_manifest_json.get_boolean_member_with_default("bIsCompressed", false) << 1;
					file_manifest.flags |= (int) file_manifest_json.get_boolean_member_with_default("bIsUnixExecutable", false) << 2;

					if(file_manifest_json.has_member("InstallTags"))
					{
						file_manifest_json.get_array_member("InstallTags").foreach_element((a, i, n) => {
							file_manifest.install_tags.add(n.get_string());
						});
					}

					var offset = 0;
					file_manifest_json.get_array_member("FileChunkParts").foreach_element((a, i, n) =>
					{
						var chunk_part           = new FileManifest.ChunkPart.from_json(n, offset);
						file_manifest.file_size += chunk_part.size;

						//  TODO: not read keys

						file_manifest.chunk_parts.add(chunk_part);
					});

					//  TODO: not read keys

					elements.add(file_manifest);
				});

				if(log_file_manifest_list) debug(to_string());
			}

			internal FileManifest? get_file_by_path(string path)
			{
				if(path_map == null)
				{
					path_map = new HashMap<string, int>();

					for(var i = 0; i < elements.size; i++)
					{
						path_map.set(elements.get(i).filename, i);
					}
				}

				if(!path_map.has_key(path))
				{
					debug(@"[Sources.EpicGames.FileManifestList.get_file_by_path] Invalid path: $path");

					return null;
				}

				return elements.get(path_map.get(path));
			}

			internal string to_string()
			{
				var result = "<FileManifestList (version=%s, size=%s, count=%s elements=\n".printf(
					version.to_string(),
					size.to_string(),
					count.to_string());

				foreach(var file_manifest in elements)
				{
					result = result + file_manifest.to_string() + "\n";
				}

				return result + ")>";
			}

			/**
			* Contains information about each individual file.
			*
			* Each file is made up out of a number of {@link ChunkPart}s.
			*
			* @param chunk_parts {@link ChunkPart}s that are used in this file.
			 */
			internal class FileManifest
			{
				internal ArrayList<ChunkPart> chunk_parts  { get; default = new ArrayList<ChunkPart>(); }
				internal ArrayList<string>    install_tags { get; default = new ArrayList<string>(); }
				internal bool                 compressed   { get { return (flags & 0x2) == 0x2; } }
				internal bool                 executable   { get { return (flags & 0x4) == 0x4; } }
				internal bool                 read_only    { get { return (flags & 0x1) == 0x1; } }
				internal Bytes                hash         { get; set; default = new Bytes(null); }
				internal Bytes                sha_hash     { get { return hash; } }
				internal uchar flags { get; set; default = 0; }
				internal uint32 file_size { get; set; default = 0; }
				internal string filename { get; set; default = ""; }
				internal string symlink_target { get; set; default = ""; }

				//  Because of the weird data structure we're setting everything in the FileManifestList
				internal FileManifest() {}

				internal string to_string()
				{
					var tag_string   = "";
					var chunk_string = "";

					foreach(var tag in install_tags)
					{
						tag_string = tag_string + tag;
					}

					foreach(var chunk in chunk_parts)
					{
						chunk_string = chunk_string + chunk.to_string() + "\n";
					}

					return "<FileManifest (filename=%s, symlink_target=%s, hash=%s, flags=%s, file_size=%s, install_tags=[%s], chunk_parts=[\n%s])>".printf(
						filename,
						symlink_target,
						bytes_to_hex(hash),
						flags.to_string(),
						file_size.to_string(),
						tag_string,
						chunk_string);
				}

				/**
				* ChunkPart contains simple information of Chunks used in the {@link FileManifest}.
				*
				* Each resulting file is build from x ChunkParts. This contains information
				* where each ChunkPart belongs to in the resulting file and where to find
				* it in the {@link Chunk}.
				*
				* @param file_offset Bytes this ChunkPart is shifted in the resulting file
				* @param offset Bytes this ChunkPart is shifted in the Chunk
				* @param size Size of this ChunkPart
				*/
				internal class ChunkPart
				{
					internal uint32 file_offset { get; default = 0; }
					internal uint32 offset      { get; default = 0; }
					internal uint32 size        { get; default = 0; }
					internal        uint32[] guid { get; default = new uint32[4]; }

					//  caches for things that are "expensive" to compute
					private string? _guid_str = null;
					private         uint32? _guid_num = null;

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

					private ChunkPart(uint32[] guid        = new uint32[4],
					                  uint32   offset      = 0,
					                  uint32   size        = 0,
					                  uint32   file_offset = 0)
					{
						_guid        = guid;
						_offset      = offset;
						_size        = size;
						_file_offset = file_offset;
					}

					internal ChunkPart.from_byte_stream(DataInputStream stream, uint32 offset)
					{
						var start = stream.tell();

						try
						{
							var size = stream.read_uint32();

							for(var j = 0; j < 4; j++)
							{
								_guid[j] = stream.read_uint32();
							}

							_offset      = stream.read_uint32();
							_size        = stream.read_uint32();
							_file_offset = offset;

							var diff = stream.tell() - start - size;

							if(diff > 0)
							{
								warning(@"[Sources.EpicGames.Manifest.ChunkPart.from_byte_stream] Did not read $diff bytes from chunk part!");
								stream.seek(diff, SeekType.SET);
							}
						}
						catch (Error e)
						{
							debug("[ChunkPart.from_byte_stream] error: %s", e.message);
						}

						if(log_chunk_part) debug(to_string());
					}

					internal ChunkPart.from_json(Json.Node json, uint32 offset)
					{
						assert(json.get_node_type() == Json.NodeType.OBJECT);

						uint32 chunk_offset = 0;
						uint32 chunk_size   = 0;
						try
						{
							chunk_offset = number_string_to_byte_stream(json.get_object().get_string_member("Offset")).read_uint32();
							chunk_size   = number_string_to_byte_stream(json.get_object().get_string_member("Size")).read_uint32();
						}
						catch (Error e) { debug("error: %s", e.message); }

						this(guid_from_hex_string(json.get_object().get_string_member("Guid")),
						     chunk_offset,
						     chunk_size,
						     offset
						);

						if(log_chunk_part) debug(to_string());
					}

					internal string to_string() { return @"<ChunkPart (guid=$guid_str, offset=$offset, size=$size, file_offset=$file_offset)>"; }
				}
			}
		}

		/**
		* Contains information about all available {@link Chunk}s.
		*
		* One {@link Chunk} can contain data for a file part, one file or even multiple files.
		*
		* @see ChunkPart
		 */
		internal class ChunkDataList
		{
			private uint8 version { get; }
			private uint32               manifest_version { get; }
			private uint32               size             { get; }
			private uint32               count            { get; }
			Json.Object                  chunk_filesize_list; // FIXME:
			Json.Object                  chunk_hash_list; // FIXME:
			Json.Object                  chunk_sha_list; // FIXME:
			Json.Object                  data_group_list; // FIXME:
			private HashMap<uint32, int> guid_int_map { get; default = new HashMap<uint32, int>(); }
			private HashMap<string, int> guid_str_map { get; default = new HashMap<string, int>(); }

			internal ArrayList<ChunkInfo> elements { get; default = new ArrayList<ChunkInfo>(); }

			internal ChunkDataList.from_byte_stream(DataInputStream stream, uint32 manifest_version = 18)
			{
				var start = stream.tell();
				_manifest_version = manifest_version;

				try
				{
					_size    = stream.read_uint32();
					_version = stream.read_byte();
					_count   = stream.read_uint32();

					//  the way this data is stored is rather odd, maybe there's a nicer way to write this…
					for(var i = 0; i < count; i++)
					{
						elements.add(new ChunkInfo(manifest_version));
					}

					//  guid, doesn't seem to be a standard like UUID but is fairly straightfoward, 4 bytes, 128 bit.
					elements.foreach(chunk => {
						for(var i = 0; i < 4; i++)
						{
							try
							{
								chunk.guid[i] = stream.read_uint32();
							}
							catch (Error e) { debug("error: %s", e.message); }
						}

						return true;
					});

					//  hash is a 64 bit integer, no idea how it's calculated but we don't need to know that.
					elements.foreach(chunk => {
						try
						{
							chunk.hash = stream.read_uint64();
						}
						catch (Error e) { debug("error: %s", e.message); }

						return true;
					});

					elements.foreach(chunk => {
						try
						{
							chunk.sha_hash = stream.read_bytes(20);
						}
						catch (Error e) { debug("error: %s", e.message); }

						return true;
					});

					//  group number, seems to be part of the download path
					elements.foreach(chunk => {
						try
						{
							chunk.group_num = stream.read_byte();
						}
						catch (Error e) { debug("error: %s", e.message); }

						return true;
					});

					//  window size is the uncompressed size
					elements.foreach(chunk => {
						try
						{
							chunk.window_size = stream.read_uint32();
						}
						catch (Error e) { debug("error: %s", e.message); }

						return true;
					});

					//  file size is the compressed size that will need to be downloaded
					elements.foreach(chunk => {
						try
						{
							chunk.file_size = stream.read_int64();
						}
						catch (Error e) { debug("error: %s", e.message); }

						return true;
					});

					assert(stream.tell() - start == size);
				}
				catch (Error e) {}

				if(log_chunk_data_list) debug(to_string());
			}

			internal ChunkDataList.from_json(Json.Node json_data, uint32 manifest_version = 13)
			{
				var json_obj = json_data.get_object();

				_manifest_version   = manifest_version;
				_count              = json_obj.get_object_member("ChunkFilesizeList").get_size();
				chunk_filesize_list = json_obj.get_object_member("ChunkFilesizeList");
				chunk_hash_list     = json_obj.get_object_member("ChunkHashList");
				chunk_sha_list      = json_obj.get_object_member("ChunkShaList");
				data_group_list     = json_obj.get_object_member("DataGroupList");

				chunk_filesize_list.get_members().foreach(guid =>
				{
					var chunk_info = new ChunkInfo(manifest_version);
					chunk_info.guid = guid_from_hex_string(guid);
					chunk_info.window_size = 1024 * 1024;

					try
					{
						chunk_info.file_size = number_string_to_byte_stream(chunk_hash_list.get_string_member(guid)).read_int64();
						chunk_info.hash = number_string_to_byte_stream(chunk_hash_list.get_string_member(guid)).read_uint64();
						chunk_info.group_num = number_string_to_byte_stream(data_group_list.get_string_member(guid)).read_byte();

						var stream = hex_string_to_byte_stream(chunk_sha_list.get_string_member(guid));
						stream.set_byte_order(DataStreamByteOrder.BIG_ENDIAN);
						chunk_info.sha_hash = stream.read_bytes(20);
					}
					catch (Error e) { debug("error: %s", e.message); }

					elements.add(chunk_info);
				});

				if(log_chunk_data_list) debug(to_string());
			}

			/**
			* Get chunk by GUID number, creates index of chunks on first call
			*
			* Integer GUIDs are usually faster and require less memory, use those when possible.
			*/
			internal ChunkInfo? get_chunk_by_number(uint32 guid)
			{
				if(_guid_int_map.is_empty)
				{
					for(var i = 0; i < _elements.size; i++)
					{
						_guid_int_map.set(_elements.get(i).guid_num, i);
					}
				}

				if(_guid_int_map.has_key(guid))
				{
					return _elements[_guid_int_map.get(guid)];
				}

				debug("[Sources.EpicManifest.ChunkDataList.get_chunk_by_number] Invalid guid!");
				assert_not_reached();
			}

			/**
			* Get chunk by GUID string, creates index of chunks on first call
			*
			* Integer GUIDs are usually faster and require less memory, use those when possible.
			*/
			internal ChunkInfo? get_chunk_by_string(string guid)
			{
				if(_guid_str_map.is_empty)
				{
					for(var i = 0; i < _elements.size; i++)
					{
						_guid_str_map.set(_elements.get(i).guid_str, i);
					}
				}

				if(_guid_str_map.has_key(guid))
				{
					return _elements[_guid_str_map.get(guid)];
				}

				debug("[Sources.EpicManifest.ChunkDataList.get_chunk_by_string] Invalid guid!");
				assert_not_reached();
			}

			internal string to_string()
			{
				var result = "<ChunkDataList (version=%s, manifest_version=%s, size=%s, count=%s, elements=\n".printf(
					version.to_string(),
					manifest_version.to_string(),
					size.to_string(),
					count.to_string());

				foreach(var element in elements)
				{
					result = result + element.to_string() + "\n";
				}

				return result + ")>";
			}

			/**
			* Contains information about one {@link Chunk}.
			*
			* One {@link Chunk} can contain one or multiple {@link ChunkPart}s.
			*
			* @param file_size is the compressed size that gets downloaded
			* @param group_num is part of the download path
			* @param guid doesn't seem to be a standard like UUID but is fairly straightfoward, 4 bytes, 128 bit
			* @param hash is a 64 bit integer, no idea how it's calculated
			* @param window_size is the uncompressed size
			 */
			internal class ChunkInfo
			{
				internal Bytes  sha_hash         { get; set; default = new Bytes(null); }
				internal int64  file_size        { get; set; default = 0; }
				internal        uint32[] guid    { get; set; default = new uint32[4]; }
				internal uint32 manifest_version { get; set; }
				internal uint32 window_size      { get; set; default = 0; }
				internal uint64 hash             { get; set; default = 0; }

				//  caches for things that are "expensive" to compute
				private ulong?  _group_num = null;
				private string? _guid_str = null;
				private         uint32? _guid_num = null;

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

				internal ulong group_num
				{
					get
					{
						if(_group_num == null)
						{
							var bytes = new ByteArray();

							foreach(var id in guid)
							{
								var variant = new Variant.uint32(id);
								variant.byteswap(); // FIXME: instead of hardcoded swapping try to set endian directly
								bytes.append(variant.get_data_as_bytes().get_data());
							}

							_group_num = (ZLib.Utility.crc32(0, bytes.data) & 0xffffffff) % 100;
						}

						return _group_num;
					}
					set
					{
						_group_num = value;
					}
				}

				internal string path
				{
					owned get
					{
						return "%s/%02lu/%016llX_%s.chunk".printf(get_chunk_dir(),
						                                          group_num,
						                                          hash,
						                                          guid_to_string(guid));
					}
				}

				//  Because of the weird data structure everything is set in ChunkDataList
				internal ChunkInfo(uint manifest_version = 18)
				{
					_manifest_version = manifest_version;
				}

				internal string get_chunk_dir()
				{
					//  The lowest version I've ever seen was 12 (Unreal Tournament), but for completeness sake leave all of them in
					if(manifest_version >= 15) return "ChunksV4";
					else if(manifest_version >= 6) return "ChunksV3";
					else if(manifest_version >= 3) return "ChunksV2";
					else return "Chunks";
				}

				internal string to_string()
				{
					return "<ChunkInfo (guid=%s, hash=%s, sha_hash=%s, group_num=%s, window_size=%s, file_size=%s)>".printf(
						guid_str,
						hash.to_string(),
						bytes_to_hex(sha_hash),
						group_num.to_string(),
						window_size.to_string(),
						file_size.to_string());
				}
			}
		}

		//  TODO: private class CustomFields
		//  {
		//  	int size = 0;
		//  	int version = 0;
		//  	int count = 0;
		//  	//  HashMap<>
		//  }

		/**
		* Reads a string from a {@link DataInputStream}.
		*
		* At first it reads the length of the stream.
		* When the length is negative the following string is UTF-16 - otherwise it's ASCII?
		* In either case the {@link string} is returned as unescaped UTF-8 (uint8[])
		 */
		//   TODO: clean up and verify this mess with UTF-16 and ASCII
		private static string read_fstring(DataInputStream stream)
		{
			string result = "";
			try
			{
				var length = stream.read_int32();
				//  debug("[Sources.EpicGames.Manifest.read_fstring] string length: %zu", length);

				//  if the length is negative the string is UTF-16 encoded, this was a pain to figure out.
				if(length < 0)
				{
					//  utf-16 chars are 2 bytes wide but the length is # of characters, not bytes
					//  TODO: actually make sure utf-16 characters can't be longer than 2 bytes
					length *= -2;
					//  var tmp = stream.read_bytes(length - 2).get_data();
					//  TODO: CharsetConverter oconverter = new CharsetConverter ("utf-16", "utf-8");
					//  variant = new Variant.from_bytes(VariantType.STRING, stream.read_bytes(length), false);
					//  debug("[Sources.EpicGames.Manifest.read_fstring] string utf-16: %s", variant.get_string());
					result = convert((string) stream.read_bytes(length), -1, "UTF-8", "UTF-16");                                                                                                                                                                //  convert to utf8
					//  debug("[Sources.EpicGames.Manifest.read_fstring] string utf-8: %s", result);
					//  stream.seek(2, GLib.SeekType.CUR); //  utf-16 strings have two byte null terminators
					//  TODO: seek +1 for second null char?
				}
				else if(length > 0)
				{
					//  variant = new Variant.from_bytes(VariantType.STRING, stream.read_bytes(length), false);
					result = (string) stream.read_bytes(length).get_data();
					//  debug("[Sources.EpicGames.Manifest.read_fstring] string utf-8: %s", variant.get_string());
					//  var tmp = (string) stream.read_bytes(length - 1).get_data();
					//  result = convert((string) tmp, -1, "UTF-8", "ASCII");
					//  result = variant.get_string();
					//  stream.seek(1, GLib.SeekType.CUR); //  skip string null terminator
				}
				else
				{
					result = "";         //  empty string, no terminators or anything
				}
			}
			catch (Error e) {}

			//  FIXME: escape?
			return result;
		}
	}

	/**
	* Contains information about the differences between two {@link Manifest}s.
	 */
	internal class ManifestComparison
	{
		internal ArrayList<string> added     { get; default = new ArrayList<string>(); }
		internal ArrayList<string> removed   { get; default = new ArrayList<string>(); }
		internal ArrayList<string> changed   { get; default = new ArrayList<string>(); }
		internal ArrayList<string> unchanged { get; default = new ArrayList<string>(); }

		internal ManifestComparison(Manifest new_manifest, Manifest? old_manifest = null)
		{
			if(old_manifest == null)
			{
				foreach(var file_manifest in new_manifest.file_manifest_list.elements)
				{
					added.add(file_manifest.filename);

					return;
				}
			}

			var old_files = new HashMap<string, Bytes>();

			foreach(var file_manifest in old_manifest.file_manifest_list.elements)
			{
				old_files.set(file_manifest.filename, file_manifest.hash);
			}

			foreach(var file_manifest in new_manifest.file_manifest_list.elements)
			{
				Bytes? old_file_hash = null;

				if(old_files.has_key(file_manifest.filename))
				{
					old_files.unset(file_manifest.filename, out old_file_hash);
				}

				if(old_file_hash != null)
				{
					if(file_manifest.hash == old_file_hash)
					{
						unchanged.add(file_manifest.filename);
					}
					else
					{
						changed.add(file_manifest.filename);
					}
				}
				else
				{
					added.add(file_manifest.filename);
				}
			}

			//  remaining old files were removed
			if(old_files.size > 0)
			{
				removed.add_all(old_files.keys);
			}
		}
	}
}
