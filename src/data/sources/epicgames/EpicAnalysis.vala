using Gee;

using GameHub.Utils;

namespace GameHub.Data.Sources.EpicGames
{
	/**
	* This analysis one or two {@link Manifest}s and assembles lists on what to do download and write
	* to files.
	*
	* @param tasks is a ordered list with instructions to open a file, write to it some {@link ChunkPart}s and close it afterwards.
	 */
	//  FIXME: There are a lot of things related to Legendarys memory management we probably don't even need
	private class Analysis
	{
		internal                        AnalysisResult? result { get; default = null; }
		internal ArrayList<Task>        tasks                  { get; default = new ArrayList<Task>(); }
		internal LinkedList<uint32>     chunks_to_dl           { get; default = new LinkedList<uint32>(); }
		internal Manifest.ChunkDataList chunk_data_list        { get; default = null; }
		internal string?                base_url               { get; default = null; }

		private                         File? resume_file { get; default = null; }
		private HashMap<string, string> hash_map          { get; default = new HashMap<string, string>(); }
		private string?                 download_dir      { get; default = null; }

		private Analysis(File install_dir, string base_url, File? resume_file)
		{
			_download_dir = install_dir.get_path();
			_base_url     = base_url;
			_resume_file  = resume_file;
		}

		internal Analysis.from_analysis(Runnables.Tasks.Install.InstallTask task,
		                                string                              base_url,
		                                Manifest                            new_manifest,
		                                Manifest?                           old_manifest      = null,
		                                File?                               resume_file       = null,
		                                string[]?                           file_install_tags = null)
		{
			this(task.install_dir, base_url, resume_file);

			_result = new AnalysisResult(new_manifest,
			                             download_dir,
			                             ref _hash_map,
			                             ref _chunks_to_dl,
			                             ref _tasks,
			                             out _chunk_data_list,
			                             old_manifest,
			                             resume_file,
			                             file_install_tags);
		}

		internal class AnalysisResult
		{
			internal uint32 install_size { get; default = 0; }
			internal uint32 reuse_size   { get; default = 0; }
			internal uint32 unchanged    { get; default = 0; }
			//  internal uint32 unchanged_size { get; default = 0; }
			internal uint64 dl_size      { get; default = 0; }

			private ManifestComparison manifest_comparison  { get; }
			private uint32             added                { get; default = 0; }
			private uint32             biggest_file_size    { get; default = 0; }
			private uint32             biggest_chunk        { get; default = 0; }
			private uint32             changed              { get; default = 0; }
			private uint32             min_memory           { get; default = 0; }
			private uint32             num_chunks           { get; default = 0; }
			private uint32             num_chunks_cache     { get; default = 0; }
			private uint32             num_files            { get; default = 0; }
			private uint32             removed              { get; default = 0; }
			private uint32             uncompressed_dl_size { get; default = 0; }

			internal AnalysisResult(Manifest                    new_manifest,
			                        string                      download_dir,
			                        ref HashMap<string, string> hash_map,
			                        ref LinkedList<uint32>      chunks_to_dl,
			                        ref ArrayList<Task>         tasks,
			                        out Manifest.ChunkDataList  chunk_data_list,
			                        Manifest?                   old_manifest      = null,
			                        File?                       resume_file       = null,
			                        string[]?                   file_install_tags = null)
			{
				foreach(var element in new_manifest.file_manifest_list.elements)
				{
					_install_size += element.file_size;
				}

				_biggest_chunk = new_manifest.chunk_data_list.elements.max((a, b) => {
					if(a.window_size < b.window_size) return -1;

					if(a.window_size == b.window_size) return 0;

					//  if(a.window_size > b.window_size) return 1;
					return 1;
				}).window_size;

				_biggest_file_size = new_manifest.file_manifest_list.elements.max((a, b) => {
					if(a.file_size < b.file_size) return -1;

					if(a.file_size == b.file_size) return 0;

					//  if(a.file_size > b.file_size) return 1;
					return 1;
				}).file_size;

				var is_1mib = (biggest_chunk == 1024 * 1024);

				if(log_analysis) debug(@"[Sources.EpicGames.AnalysisResult] Biggest chunk size: $biggest_chunk bytes (==1 MiB? $is_1mib)");

				debug("[Sources.EpicGames.AnalysisResult] Creating manifest comparison…");
				_manifest_comparison = new ManifestComparison(new_manifest, old_manifest);

				if(resume_file != null && resume_file.query_exists())
				{
					info("[Sources.EpicGames.AnalysisResult] Found previously interrupted download. Download will be resumed if possible.");
					try
					{
						var missing         = 0;
						var mismatch        = 0;
						var completed_files = new ArrayList<string>();
						var stream          = new DataInputStream(resume_file.read());

						string? line = null;

						while((line = stream.read_line_utf8()) != null)
						{
							var data      = line.split(":");
							var file_hash = data[0];
							var filename  = data[1];
							var file      = FS.file(download_dir, filename);

							if(!file.query_exists())
							{
								debug(@"[Sources.EpicGames.AnalysisResult] File does not exist but is in resume file: $(file.get_path())");
								missing++;
							}
							else if(file_hash != bytes_to_hex(new_manifest.file_manifest_list.get_file_by_path(filename).sha_hash))
							{
								mismatch++;
							}
							else
							{
								completed_files.add(filename);
							}
						}

						if(missing > 0)
						{
							warning(@"[Sources.EpicGames.AnalysisResult] $missing previously completed file(s) are missing, they will be redownloaded.");
						}

						if(mismatch > 0)
						{
							warning(@"[Sources.EpicGames.AnalysisResult] $mismatch previously completed file(s) are missing, they will be redownloaded.");
						}

						//  remove completed files from changed/added and move them to unchanged for the analysis.
						manifest_comparison.added.remove_all(completed_files);
						manifest_comparison.changed.remove_all(completed_files);
						manifest_comparison.unchanged.add_all(completed_files);

						info(@"[Sources.EpicGames.AnalysisResult] Skipping $(completed_files.size) files based on resume data.");
					}
					catch (Error e)
					{
						warning(@"[Sources.EpicGames.AnalysisResult] Reading resume file failed: $(e.message), continuing as normal…");
					}
				}

				//  Install tags are used for selective downloading, e.g. for language packs
				var additional_deletion_tasks = new ArrayList<FileTask>();

				if(file_install_tags != null)
				{
					var files_to_skip = new ArrayList<string>();

					foreach(var file_manifest in new_manifest.file_manifest_list.elements)
					{
						foreach(var file_install_tag in file_install_tags)
						{
							//  TODO: ??? https://github.com/derrod/legendary/blob/a2280edea8f7f8da9a080fd3fb2bafcabf9ee33d/legendary/downloader/manager.py#L146
							if(!(file_install_tag in file_manifest.install_tags))
							{
								files_to_skip.add(file_manifest.filename);
							}
						}
					}

					info(@"[Sources.EpicGames.AnalysisResult] Found $(files_to_skip.size) files to skip based on install tag.");

					manifest_comparison.added.remove_all(files_to_skip);
					manifest_comparison.changed.remove_all(files_to_skip);

					files_to_skip.sort(); //  TODO: Does this need a comparefunction?
					foreach(var file in files_to_skip)
					{
						//  Union
						if(!(file in manifest_comparison.unchanged))
						{
							manifest_comparison.unchanged.add(file);
						}

						additional_deletion_tasks.add(new FileTask.delete(file, true));
					}
				}

				//  Legendary has exclude filters here

				if(file_install_tags.length > 0)
				{
					info(@"[Sources.EpicGames.AnalysisResult] Remaining files after filtering: $(manifest_comparison.added.size + manifest_comparison.changed.size)");

					//  correct install size after filtering
					_install_size = 0;
					foreach(var file_manifest in new_manifest.file_manifest_list.elements)
					{
						if(file_manifest.filename in manifest_comparison.added)
						{
							_install_size += file_manifest.file_size;
						}
					}
				}

				if(!manifest_comparison.removed.is_empty)
				{
					_removed = manifest_comparison.removed.size;
					debug(@"[Sources.EpicGames.AnalysisResult] $removed removed files");
				}

				if(!manifest_comparison.added.is_empty)
				{
					_added = manifest_comparison.added.size;
					debug(@"[Sources.EpicGames.AnalysisResult] $added added files");
				}

				if(!manifest_comparison.changed.is_empty)
				{
					_changed = manifest_comparison.changed.size;
					debug(@"[Sources.EpicGames.AnalysisResult] $changed changed files");
				}

				if(!manifest_comparison.unchanged.is_empty)
				{
					_unchanged = manifest_comparison.unchanged.size;
					debug(@"[Sources.EpicGames.AnalysisResult] $unchanged unchanged files");
				}

				//  count references to chunks for determining runtime cache size later
				//  TODO: do we care about this?
				var references         = new HashMultiSet<uint32>(); // FIXME: correct type to count?
				var file_manifest_list = new_manifest.file_manifest_list.elements;

				file_manifest_list.sort((a, b) => {
					if(a.filename.down() < b.filename.down()) return -1;

					if(a.filename.down() == b.filename.down()) return 0;

					//  if(a.filename.down() > b.filename.down()) return 1;
					return 1;
				});

				foreach(var file_manifest in file_manifest_list)
				{
					hash_map.set(file_manifest.filename, bytes_to_hex(file_manifest.sha_hash));

					//  chunks of unchanged files are not downloaded so we can skip them
					if(file_manifest.filename in manifest_comparison.unchanged)
					{
						//  debug("skipped: %s", file_manifest.filename);
						_unchanged += file_manifest.file_size;
						continue;
					}

					foreach(var chunk_part in file_manifest.chunk_parts)
					{
						references.add(chunk_part.guid_num);
					}
				}

				//  TODO: Legendary is doing optimizations here
				//  var processing_optimizations = false;

				//  determine reusable chunks and prepare lookup table for reusable ones
				var re_usable = new HashMap<string, HashMap<ChunkKey, uint32> >();
				var patch     = true; // FIXME: hardcoded always update

				if(old_manifest != null && !manifest_comparison.changed.is_empty && patch)
				{
					if(log_analysis) debug("[Sources.EpicGames.AnalysisResult] Analyzing manifests for re-usable chunks…");

					foreach(var changed_file in manifest_comparison.changed)
					{
						var old_file = old_manifest.file_manifest_list.get_file_by_path(changed_file);
						var new_file = new_manifest.file_manifest_list.get_file_by_path(changed_file);

						var    existing_chunks = new HashMap<uint32, ArrayList<OldChunkKey>>();
						uint32 offset          = 0;

						foreach(var chunk_part in old_file.chunk_parts)
						{
							//  debug(@"Old chunk: $chunk_part");
							if(!existing_chunks.has_key(chunk_part.guid_num))
							{
								var list = new ArrayList<OldChunkKey>();
								existing_chunks.set(chunk_part.guid_num, list);
							}

							existing_chunks.get(chunk_part.guid_num).add(new OldChunkKey(offset, chunk_part.offset, chunk_part.offset + chunk_part.size));
							offset += chunk_part.size;
						}

						foreach(var chunk_part in new_file.chunk_parts)
						{
							//  debug(@"New chunk: $chunk_part");
							var key = new ChunkKey(chunk_part.guid_num, chunk_part.offset, chunk_part.size);

							if(!existing_chunks.has_key(chunk_part.guid_num)) continue;

							foreach(var thing in existing_chunks.get(chunk_part.guid_num))
							{
								//  check if new chunk part is wholly contained in the old chunk part
								if(thing.chunk_part_offset <= chunk_part.offset
								   && (chunk_part.offset + chunk_part.size) <= thing.chunk_part_end)
								{
									references.remove(chunk_part.guid_num);

									if(!re_usable.has_key(changed_file))
									{
										re_usable.set(changed_file,
										              new HashMap<ChunkKey, uint32>(
												      key => { return key.hash(); },
												      (a, b) => { return a.equal_to(b); }));
									}

									re_usable.get(changed_file).set(key, thing.file_offset + (chunk_part.offset - thing.chunk_part_offset));
									_reuse_size += chunk_part.size;
									break;
								}
							}
						}
					}
				}

				if(log_analysis) debug("re-usable size: " + reuse_size.to_string());

				if(log_analysis) debug("files with re-usable parts: " + re_usable.size.to_string());

				uint32 last_cache_size    = 0;
				uint32 current_cache_size = 0;

				//  set to determine whether a file is currently cached or not
				var cached = new ArrayList<uint32>();

				//  Using this secondary set is orders of magnitude faster than checking the deque.
				var chunks_in_dl_list = new ArrayList<uint32>();

				//  This is just used to count all unique guids that have been cached
				var dl_cache_guids = new ArrayList<uint32>();

				//  run through the list of files and create the download jobs and also determine minimum
				//  runtime cache requirement by simulating adding/removing from cache during download.
				debug("[Sources.EpicGames.AnalysisResult] Creating filetasks and chunktasks…");
				foreach(var current_file in file_manifest_list)
				{
					//  skip unchanged and empty files
					if(current_file.filename in manifest_comparison.unchanged)
					{
						continue;
					}
					else if(current_file.chunk_parts.size == 0)
					{
						tasks.add(new FileTask.empty_file(current_file.filename));
						continue;
					}

					var existing_chunks = re_usable.get(current_file.filename);
					var chunk_tasks     = new ArrayList<ChunkTask>();
					var reused          = 0;

					foreach(var chunk_part in current_file.chunk_parts)
					{
						var chunk_task = new ChunkTask(chunk_part.guid_num, chunk_part.offset, chunk_part.size);

						//  re-use the chunk from the existing file if we can
						var key = new ChunkKey(chunk_part.guid_num, chunk_part.offset, chunk_part.size);

						if(existing_chunks != null && existing_chunks.has_key(key))
						{
							if(log_analysis) debug("reusing chunk: " + new_manifest.chunk_data_list.get_chunk_by_number(chunk_part.guid_num).to_string());

							reused++;
							chunk_task.chunk_file   = current_file.filename;
							chunk_task.chunk_offset = existing_chunks.get(key);
						}
						else
						{
							//  add to DL list if not already in it
							if(!(chunk_part.guid_num in chunks_in_dl_list))
							{
								//  debug("chunk " + chunk_part.guid_num.to_string() + " to download, hash should be: " + new_manifest.chunk_data_list.get_chunk_by_number(chunk_part.guid_num).to_string());
								chunks_to_dl.add(chunk_part.guid_num);
								chunks_in_dl_list.add(chunk_part.guid_num);
							}

							//  if chunk has more than one use or is already in cache,
							//  check if we need to add or remove it again.
							if(references.count(chunk_part.guid_num) > 1
							   || chunk_part.guid_num in cached)
							{
								references.remove(chunk_part.guid_num);

								//  delete from cache if no references left
								if(!(chunk_part.guid_num in references))
								{
									current_cache_size -= biggest_chunk;
									cached.remove(chunk_part.guid_num);
									chunk_task.cleanup = true;
								}

								//  add to cache if not already cached
								else if(!(chunk_part.guid_num in cached))
								{
									dl_cache_guids.add(chunk_part.guid_num);
									cached.add(chunk_part.guid_num);
									current_cache_size += biggest_chunk;
								}
							}
							else
							{
								chunk_task.cleanup = true;
							}
						}

						chunk_tasks.add(chunk_task);
					}

					if(reused > 0)
					{
						if(log_analysis) debug(@"[Sources.EpicGames.AnalysisResult] Reusing $reused chunks from: $(current_file.filename)");

						//  open temporary file that will contain download + old file contents
						tasks.add(new FileTask.open(current_file.filename + ".tmp"));
						tasks.add_all(chunk_tasks);
						tasks.add(new FileTask.close(current_file.filename + ".tmp"));

						//  delete old file and rename temporary
						tasks.add(new FileTask.rename(current_file.filename,
						                              current_file.filename + ".tmp",
						                              true));
					}
					else
					{
						tasks.add(new FileTask.open(current_file.filename));
						tasks.add_all(chunk_tasks);
						tasks.add(new FileTask.close(current_file.filename));
					}

					//  check if runtime cache size has changed
					if(current_cache_size > last_cache_size)
					{
						if(log_analysis) debug(@"[Sources.EpicGames.AnalysisResult] New maximum cache size: $(current_cache_size / 1024 / 1024) MiB");

						last_cache_size = current_cache_size;
					}
				}

				if(log_analysis) debug(@"[Sources.EpicGames.AnalysisResult] Final cache size requirement: $(last_cache_size / 1024 / 1024) MiB");

				_min_memory = last_cache_size + (1024 * 1024 * 32); //  add some padding just to be safe

				//  TODO: Legendary does same caching stuff here
				//  https://github.com/derrod/legendary/blob/a2280edea8f7f8da9a080fd3fb2bafcabf9ee33d/legendary/downloader/manager.py#L363

				//  calculate actual dl and patch write size.
				_dl_size              = 0;
				_uncompressed_dl_size = 0;
				new_manifest.chunk_data_list.elements.foreach(chunk => {
					if(chunk.guid_num in chunks_in_dl_list)
					{
						_dl_size += chunk.file_size;
						_uncompressed_dl_size += chunk.window_size;
					}

					return true;
				});

				//  add jobs to remove files
				foreach(var filename in manifest_comparison.removed)
				{
					tasks.add(new FileTask.delete(filename));
				}

				tasks.add_all(additional_deletion_tasks);

				_num_chunks_cache = dl_cache_guids.size;
				chunk_data_list   = new_manifest.chunk_data_list;
			}

			class ChunkKey
			{
				public uint32 guid_num;
				public uint32 offset;
				public uint32 size;

				public ChunkKey(uint32 guid_num, uint32 offset, uint32 size)
				{
					this.guid_num = guid_num;
					this.offset   = offset;
					this.size     = size;
				}

				public uint hash() { var hash = (guid_num.to_string() + offset.to_string() + size.to_string()).hash(); return hash; }

				public bool equal_to(ChunkKey chunk_key) { return chunk_key.hash() == hash(); }
			}

			class OldChunkKey
			{
				public uint32 file_offset;
				public uint32 chunk_part_offset;
				public uint32 chunk_part_end;

				public OldChunkKey(uint32 file_offset, uint32 chunk_part_offset, uint32 chunk_part_end)
				{
					this.file_offset       = file_offset;
					this.chunk_part_offset = chunk_part_offset;
					this.chunk_part_end    = chunk_part_end;
				}
			}
		}

		//  This only exists so I can put both subclasses in one list
		//  so that the tasks order stays in the correct position
		internal abstract class Task {}

		/**
		* Download manager task for a file
		*
		* @param filename name of the file
		* @param del if this is a file to be deleted, if rename is true, delete filename before renaming
		* @param empty if this is an empty file that just needs to be "touch"-ed (may not have chunk tasks)
		* @param temporary_filename If rename is true: Filename to rename from.
		*/
		internal class FileTask: Task
		{
			internal string filename           { get; }
			internal bool    del                { get; default = false; }
			internal bool    empty              { get; default = false; }
			internal bool    fopen              { get; default = false; }
			internal bool    fclose             { get; default = false; }
			internal bool    frename            { get; default = false; }
			internal string? temporary_filename { get; default = null; }
			internal bool    silent             { get; default = false; }

			internal bool is_reusing
			{
				get
				{
					return temporary_filename != null;
				}
			}

			internal FileTask(string filename)
			{
				_filename = filename;
			}

			internal FileTask.delete(string filename, bool silent = false)
			{
				this(filename);
				_del    = true;
				_silent = silent;
			}

			internal FileTask.empty_file(string filename)
			{
				this(filename);
				_empty = true;
			}

			internal FileTask.open(string filename)
			{
				this(filename);
				_fopen = true;
			}

			internal FileTask.close(string filename)
			{
				this(filename);
				_fclose = true;
			}

			internal FileTask.rename(string new_filename, string old_filename, bool dele = false)
			{
				this(new_filename);
				_frename            = true;
				_temporary_filename = old_filename;
				_del                = dele;
			}
		}

		/**
		* Download manager chunk task
		*
		* @param chunk_guid GUID of chunk
		* @param cleanup whether or not this chunk can be removed from disk/memory after it has been written
		* @param chunk_offset Offset into file or shared memory
		* @param chunk_size Size to read from file or shared memory
		* @param chunk_file Either cache or existing game file this chunk is read from if not using shared memory
		*/
		internal class ChunkTask: Task
		{
			internal uint32  chunk_guid   { get; }
			internal bool    cleanup      { get; set; default = false; }
			internal uint32  chunk_offset { get; set; default = 0; }
			internal uint32  chunk_size   { get; default = 0; }
			internal string? chunk_file   { get; set; default = null; }

			internal ChunkTask(uint32 chunk_guid, uint32 chunk_offset, uint32 chunk_size)
			{
				_chunk_guid   = chunk_guid;
				_chunk_offset = chunk_offset;
				_chunk_size   = chunk_size;
			}
		}
	}
}
