/* LevelDB Vala Bindings
 * Copyright 2012 Evan Nemerson <evan@coeus-group.com>
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use, copy,
 * modify, merge, publish, distribute, sublicense, and/or sell copies
 * of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

[CCode (cheader_filename = "leveldb/c.h")]
namespace LevelDB {
	[Compact, CCode (cname = "leveldb_t", lower_case_cprefix = "leveldb_", free_function = "leveldb_close")]
	public class Database {
		[CCode (cname = "leveldb_open")]
		public Database (LevelDB.Options options, string name, out string? err);

		public LevelDB.Iterator create_iterator (LevelDB.ReadOptions options);
		public LevelDB.Snapshot create_snapshot ();
		public void delete (LevelDB.WriteOptions options, [CCode (array_length_type = "size_t")] uint8[] key, out string? err);
		[CCode (cname = "leveldb_get", array_length_pos = 2.9, array_length_type = "size_t")]
		public uint8[]? get (LevelDB.ReadOptions options, [CCode (array_length_type = "size_t")] uint8[] key, out string? err);
		[CCode (cname = "leveldb_property_value")]
		public string get_property_value (string propname);
		public void put (LevelDB.WriteOptions options, [CCode (array_length_type = "size_t")] uint8[] key, [CCode (array_length_type = "size_t")] uint8[] val, out string? err);
		public void write (LevelDB.WriteOptions options, LevelDB.WriteBatch batch, out string? err);

		[CCode (cname = "leveldb_destroy_db")]
		public static void destroy (LevelDB.Options options, string name, out string? err);
		[CCode (cname = "leveldb_repair_db")]
		public static void repair (LevelDB.Options options, string name, out string? err);
	}

	[Compact, CCode (cname = "leveldb_cache_t", free_function = "leveldb_cache_destroy")]
	public class Cache {
		private Cache ();
		[CCode (cname = "leveldb_cache_create_lru")]
		public Cache.lru (size_t capacity);
	}

	[CCode (instance_pos = 0.1)]
	public delegate int CompareFunc ([CCode (array_length_type = "size_t")] uint8[] a, [CCode (array_length_type = "size_t")] uint8[] b);

	[CCode (has_target = false)]
	public delegate string NameFunc ();

	[Compact, CCode (cname = "leveldb_comparator_t", free_function = "leveldb_comparator_destroy")]
	public class Comparator {
		[CCode (cname = "leveldb_comparator_create")]
		public Comparator ([CCode (delegate_target_pos = 0.1, type = "int (*)(void*,const char*,size_t,const char*,size_t)")] owned LevelDB.CompareFunc compare, [CCode (type = "const char* (*)(void*)")] LevelDB.NameFunc name);
	}

	[CCode (cname = "int", has_type_id = false)]
	public enum Compression {
		[CCode (cname = "leveldb_no_compression")]
		NONE,
		[CCode (cname = "leveldb_snappy_compression")]
		SNAPPY
	}

	[Compact, CCode (cname = "leveldb_env_t", free_function = "leveldb_env_destroy")]
	public class Environment {
		private Environment ();
		[CCode (cname = "leveldb_create_default_env")]
		public Environment.default ();
	}

	[Compact, CCode (cname = "leveldb_iterator_t", lower_case_cprefix = "leveldb_iter_", free_function = "leveldb_iter_destroy")]
	public class Iterator {
		public bool valid ();
		public void seek_to_first ();
		public void seek_to_last ();
		public void seek ([CCode (type = "const char*", array_length_type = "size_t")] uint8[] k);
		public void next ();
		public void prev ();
		[CCode (array_length_type = "size_t")]
		public uint8[] key ();
		[CCode (array_length_type = "size_t")]
		public uint8[] value ();
		public void get_error (out string? err);
	}

	[Compact, CCode (cname = "leveldb_logger_t")]
	public class Logger {
		private Logger ();
	}

	[Compact, CCode (cname = "leveldb_options_t", lower_case_cprefix = "leveldb_options_", free_function = "leveldb_options_destroy")]
	public class Options {
		[CCode (cname = "leveldb_options_create")]
		public Options ();

		public void set_comparator (LevelDB.Comparator comparator);
		public void set_create_if_missing (bool compare_if_missing);
		public void set_error_if_exists (bool error_if_exists);
		public void set_paranoid_checks (bool paranoid_checks);
		public void set_env (LevelDB.Environment env);
		public void set_info_log (LevelDB.Logger info_log);
		public void set_write_buffer (size_t write_buffer);
		public void set_max_open_files (int max_open_files);
		public void set_cache (LevelDB.Cache cache);
		public void set_block_size (size_t block_size);
		public void set_block_restart_interval (int block_restart_interval);
		public void set_compression (LevelDB.Compression compression);
	}

	[Compact, CCode (cname = "leveldb_readoptions_t", lower_case_cprefix = "leveldb_readoptions_", free_function = "leveldb_readoptions_destroy")]
	public class ReadOptions {
		[CCode (cname = "leveldb_readoptions_create")]
		public ReadOptions ();

		public void set_fill_cache (bool fill_cache);
		public void set_snapshot (LevelDB.Snapshot snapshot);
		public void set_verify_checksums (bool verify_checksums);
	}

	[Compact, CCode (cname = "leveldb_snapshot_t", free_function = "leveldb_release_snapshot")]
	public class Snapshot {
		[CCode (cname = "leveldb_create_snapshot")]
		public Snapshot (LevelDB.Database db);
	}

	[Compact, CCode (cname = "leveldb_writeoptions_t", lower_case_cprefix = "leveldb_writeoptions_", free_function = "leveldb_writeoptions_destroy")]
	public class WriteOptions {
		[CCode (cname = "leveldb_writeoptions_create")]
		public WriteOptions ();

		public void set_sync (bool sync);
	}

	[Compact, CCode (cname = "leveldb_writebatch_t", free_function = "leveldb_writebatch_destroy", lower_case_cprefix = "leveldb_writebatch_")]
	public class WriteBatch {
		[CCode (cname = "leveldb_writebatch_create")]
		public WriteBatch ();

		[CCode (has_target = false, simple_generics = true)]
		public delegate void PutFunc<T> (T state, [CCode (array_length_type = "size_t")] uint8[] key, [CCode (array_length_type = "size_t")] uint8[] val);
		[CCode (has_target = false, simple_generics = true)]
		public delegate void DeleteFunc<T> (T state, [CCode (array_length_type = "size_t")] uint8[] key);

		public void clear ();
		public void delete ([CCode (array_length_type = "size_t")] uint8[] key);
		[CCode (simple_generics = true)]
		public void iterate<T> (T state, LevelDB.WriteBatch.PutFunc<T> put, LevelDB.WriteBatch.DeleteFunc<T> delete);
		public void put ([CCode (array_length_type = "size_t")] uint8[] key, [CCode (array_length_type = "size_t")] uint8[] val);
		[CCode (cname = "leveldb_write", instance_pos = 2.5)]
		public void write (LevelDB.Database db, LevelDB.WriteOptions options, out string? err);
	}
}
