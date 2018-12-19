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

using Gee;

using GameHub.Utils;

namespace GameHub.Data.Compat
{
	public class AGS: CompatTool
	{
		public string binary { get; construct; default = "ags"; }
                private File detected_install_dir;
                
		public AGS(string binary="ags")
		{
			Object(binary: binary);
		}

		construct
		{
			id = "ags";
			name = "AGS";
			icon = "tool-ags-symbolic";

			executable = Utils.find_executable(binary);
			installed = executable != null && executable.query_exists();
		}


                private bool find_ags_files(File? dir)
		{
			try
			{
				FileInfo? finfo = null;
				var enumerator = dir.enumerate_children("standard::*", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
				while((finfo = enumerator.next_file()) != null)
				{
					var fname = finfo.get_name();
					if(fname.has_prefix("acsetup.cfg") || fname.has_prefix("ags-setup") )
					{
						return true;
					}
				}
			}
			catch(Error e)
			{
			}
                        return false;
                }

		private bool ags_detect(File? dir)
		{
			if (find_ags_files(dir)) {
                            detected_install_dir = dir; 
                            return true;
                        }

                	FileInfo? finfo = null;
			var enumerator = dir.enumerate_children("standard::*", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
			while((finfo = enumerator.next_file()) != null)
			{
                          if (finfo.get_file_type () == FileType.DIRECTORY) {
                              File subdir = dir.resolve_relative_path (finfo.get_name ());
                              if (find_ags_files(subdir)) {
                                  detected_install_dir = subdir; 
                                  return true;
                              }

 
                          }
                        }

                        return false;

		}

		public override bool can_run(Runnable runnable)
		{
			return installed && runnable is Game && runnable.install_dir != null
				&& ags_detect(runnable.install_dir);
		}

		public override async void run(Runnable runnable)
		{
			if(!can_run(runnable)) return;
			yield Utils.run_thread({ executable.get_path() }, detected_install_dir.get_path());
		}
	}
}
