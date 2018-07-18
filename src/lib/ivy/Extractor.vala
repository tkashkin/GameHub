/*
 * Copyright (C) 2014 PerfectCarl - https://github.com/PerfectCarl/vala-stacktrace
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

namespace Ivy {

    /**
     * Extracts frames and builds a {@link Stacktrace}
     *
     */
    public class Extractor {

        private bool show_debug_frames = false;

        private string func = "";
        private string file_path = "";
        private string short_file_path = "";
        private string l = "";
        private string file_line = "";
        private string func_line = "";
        private string lib_address ="";

        private static Gee.ArrayList<string> libraries_with_no_info = new Gee.ArrayList<string>();

        private string get_module_name () {
            var path = new char[1024];
            Posix.readlink ("/proc/self/exe", path);
            string result = (string) path;
            return result;
        }

        // TODO CARL convert this piece of code to vala conventions
        private static string get_relative_path (string p_fullDestinationPath, string p_startPath) {

            string[] l_startPathParts = p_startPath.split ("/");
            string[] l_destinationPathParts = p_fullDestinationPath.split ("/");

            int l_sameCounter = 0;
            while ((l_sameCounter < l_startPathParts.length) &&
                   (l_sameCounter < l_destinationPathParts.length) &&
                   l_startPathParts[l_sameCounter] == l_destinationPathParts[l_sameCounter]) {
                l_sameCounter++;
            }

            if (l_sameCounter == 0) {
                return p_fullDestinationPath;             // There is no relative link.
            }

            StringBuilder l_builder = new StringBuilder ();
            for (int i = l_sameCounter ; i < l_startPathParts.length ; i++) {
                l_builder.append ("../");
            }

            for (int i = l_sameCounter ; i < l_destinationPathParts.length ; i++) {
                l_builder.append (l_destinationPathParts[i] + "/");
            }

            // CARL l_builder.Length--;
            // Remove the last /
            var result = l_builder.str;
            result = result.substring (0, result.length - 1);
            return result;
        }

        private string extract_short_file_path (string file_path) {
            var path = Environment.get_current_dir ();
            /*var i = file_path.index_of ( path );
               if( i>=0 )
                return file_path.substring ( path.length, file_path.length - path.length );
               return file_path; */
            var result = get_relative_path (file_path, path);
            return result;
        }

        // input : '/home/cran/Documents/Projects/elementary/noise/instant-beta/build/core/libnoise-core.so.0(noise_job_repository_create_job+0x309) [0x7ff60a021e69]'
        // ouput: 0x309
        private int extract_base_address (string line) {
            int result = 0;
            var start = line.last_index_of ("+");
            if (start >= 0) {
                var end = line.last_index_of (")");
                if( end > start ) {
                    var text = line.substring (start+3,end-start-3);
                    text.scanf("%x",  &result);
                }
            }
            return result;
        }

        private void process_info_for_file (string full_line, string str ) {
            func = "";
            file_path = "";
            short_file_path = "";
            l = "";
            file_line = "";
            func_line = "";
            if (full_line == "")
                return;

            var lines = full_line.split ("\n");

            if (lines.length > 0)
                func_line = lines[0];

            if (lines.length > 1)
                file_line = lines[1];
            if (file_line == "??:0" || file_line == "??:?")
                file_line = "";
            func = extract_function_name (str);

            file_path = "";
            short_file_path = "";
            l = "";
            if (file_line != "") {
                if (func == "")
                    func = extract_function_name_from_line (func_line);
                file_path = extract_file_path (file_line);
                short_file_path = extract_short_file_path (file_path);
                l = extract_line (file_line);
            }
        }

        private void process_info_from_lib (string file_path, string str) {
            //stdout.printf( "process_info_from_lib('%s', '%s') func: '%s'\n", file_path, str, func);
            var has_info = true;
            var addr1_s = "";
            var lib_addr = "";
            var cmd2 = "";
            lib_address ="";
            lock( libraries_with_no_info)
             {
                if( libraries_with_no_info.index_of (file_path) == -1 ){
                     // The library is not on the black list
                    cmd2 = "nm %s".printf(file_path);

                     addr1_s = execute_command_sync_get_output (cmd2);
                     if( addr1_s == null || addr1_s == "" )
                     {
                        // stdout.printf( "ADDED TO NO INFO: '%s'\n", file_path);
                        libraries_with_no_info.add (file_path);
                        has_info = false;

                     }
                }
                else
                    has_info = false;
            }
            if( has_info && func != "" )
            {
                MatchInfo info;
                var expression = "\\n[^ ]* T "+func;
                try {

                    Regex regex = new Regex (expression);
                    int count = 0;
                    string matches = "";
                    if( regex.match (addr1_s, 0, out info) )
                     {
                        while( info.matches() ){
                            var lll = info.fetch(0);
                            // stdout.printf ( "lll '%s'\n", lll );
                            lib_addr = lll.substring(0, lll.index_of(" "));
                            matches += lib_addr + "\n";
                            info.next();
                            count++;
                        }
                        if( count >1 )
                        {
                           stdout.printf ("  XX %d matches for '%s'. Command: '%s'. Matches: '%s'\n", count, func, cmd2, matches);
                        }
                         // stdout.printf ("  YY %d matches for '%s'. Command: '%s'. Matches: '%s'\n", count, func, cmd2, matches);
                    }

                } catch (RegexError e)
                {
                    critical( "Error while processing regex '%s. Err: '%s", expression, e.message );
                }
                //stdout.printf ("addr1_s %s\n", addr1_s);
                int addr1 = 0;
                lib_addr.scanf("%x",  &addr1);
                if( addr1 != 0 ) {
                    int addr2 = extract_base_address (str);
                    string addr3 = "%#08x".printf (addr1+addr2);
                    lib_address = addr3;
                    // stdout.printf ("lib_address : %s\n", lib_address);
                    var new_full_line = process_line (file_path, addr3);
                    //stdout.printf ("STR : %s\n", str);
                    // stdout.printf ("AD1 : %s\n", addr1_s);
                    //stdout.printf ("AD2 : %#08x\n", addr2);
                    //stdout.printf ("AD3 : %s\n", addr3);
                    //stdout.printf ("LIB : %s\n", file_path);
                    //stdout.printf ("RES : %s\n", new_full_line);

                    process_info_for_file (new_full_line, str );
                }
                else
                    stdout.printf ("NULL\n");
            }

        }

        private string extract_function_name (string line) {
            if (line == "")
                return "";
            var start = line.index_of ("(");
            if (start >= 0) {
                var end = line.index_of ("+", start);
                if (end >= 0) {
                    var result = line.substring (start + 1, end - start - 1);
                    return result.strip ();
                }
            }
            return "";
        }

        private string extract_function_name_from_line (string line) {
            return line.strip ();
        }

        private string extract_file_path_from (string str) {
            if (str == "")
                return "";
            /*if( str.index_of("??") >= 0)
                //result = result.substring (4, line.length - 4 );
                stdout.printf ("ERR2?? : %s\n", str ) ; */
            var start = str.index_of ("(");
            if (start >= 0) {
                return str.substring (0, start).strip ();
            }
            return str.strip ();
        }

        private string extract_file_path (string line) {
            var result = line;
            if (result == "")
                return "";
            if (result == "??:0??:0")
                return "";
            // For some reason, the file name can starts with ??:0
            if (result.has_prefix ("??:0"))
                result = result.substring (4, line.length - 4);
            // stdout.printf ("ERR1?? : %s\n", line );
            var start = result.index_of (":");
            if (start >= 0) {
                result = result.substring (0, start);
                return result.strip ();
            }
            return "";
        }

        private static string extract_line (string line) {
            var result = line;
            if (result == "")
                return "";
            if (result.has_prefix ("??:0"))
                result = result.substring (4, line.length - 4);
            var start = result.index_of (":");
            if (start >= 0) {
                result = result.substring (start + 1, line.length - start - 1);
                var end = result.index_of ("(");
                if (end >= 0) {
                    result = result.substring (0, end);
                }
                return result.strip ();
            }
            return "";
        }

        private string extract_address (string line) {
            if (line == "")
                return "";
            var start = line.index_of ("[");
            if (start >= 0) {
                var end = line.index_of ("]", start);
                if (end >= 0) {
                    var result = line.substring (start + 1, end - start - 1);
                    return result.strip ();
                }
            }
            return "";
        }

        private string execute_command_sync_get_output (string cmd) {
            try {
                int exitCode;
                string std_out;
                string std_err;
                Process.spawn_command_line_sync (cmd, out std_out, out std_err, out exitCode);
                if( exitCode == 0)
                    return std_out;
                else
                    print ("Error while executing '%s'. Exit code '%d'\n".printf(cmd, exitCode));

            }
            catch (Error e) {
                print ("Error while executing '%s': %s\n".printf(cmd,e.message));
            }
            return "";
        }

        // Poor's man demangler. libunwind is another dep
        // TODO : Optimize this
        // module : app
        // address : 0x007f80
        // output : /home/cran/Projects/noise/noise-perf-instant-search/tests/errors.vala:87
        private string process_line (string module, string address) {
            var cmd = "addr2line -f -e %s %s".printf (module, address);
            var result = execute_command_sync_get_output (cmd);
            //stdout.printf( "CMD %s\n", cmd);
            return result;
        }

    /**
     * Populates the stacktrace with frames
     *
     * The frames are extracted from ``Linux.Backtrace`` and enriched
     * via calls to unix tools ``nm`` and ``addr2line``.
     *
     * ''Warning:'' because this methods calls synchronously other applications (nm and addr2line), it
     * can have a significant impact on performance.
     *
     * @param trace the stacktrace
     */
        public void create_stacktrace (Stacktrace trace) {
            int frame_count = 100;
            int skipped_frames_count = 5;
            // Stacktrace not due to a crash
            if (trace.is_custom)
                skipped_frames_count = 3;

            void *[] array = new void *[frame_count];

            trace.frames.clear ();
            trace.first_vala = null;
            trace.max_file_name_length = 0;
            trace.is_all_function_name_blank = true;
            trace.is_all_file_name_blank = true;

            // TODO fix that > 0.26
            #if VALA_0_26 || VALA_0_28
            var size = Linux.Backtrace.@get (array);
            var strings = Linux.Backtrace.symbols (array);
            #else
            int size = Linux.backtrace (array, frame_count);
            unowned string[] strings = Linux.backtrace_symbols (array, size);
            // Needed because of some weird bug
            strings.length = size;
            #endif

            int[] addresses = (int[])array;
            string module = get_module_name ();
            // First ones are the handler
            for (int i = skipped_frames_count ; i < size ; i++) {
                int address = addresses[i];
                string str = strings[i];
                var addr = extract_address (str);
                lib_address ="";
                //stdout.printf ("9 '%s'. Addr: '%s' \n", func, addr);
                var full_line = process_line (module, addr);
                //stdout.printf ("10 '%s'\n", func);
                if( full_line == "" ) {
                    // Happens when the process memory is going up and up
                    // Likely a memory leak
                    // Like in the test suite for echo
                    // ** (/home/cran/Documents/Projects/i-hate-farms/ide/echo/build/test:2859):
                    // CRITICAL **: vala_data_type_copy: assertion 'self != NULL' failed
                    // Error while executing 'addr2line -f -e /home/cran/Documents/Projects/i-
                    // hate-farms/ide/echo/build/test 0x2afe3b5beb32': Failed to fork (Cannot allocate memory)

                    print ("Something went very wrong. Your stacktrace cannot be displayed\n");
                    break;
                }
                process_info_for_file( full_line, str);
                //stdout.printf ("11 '%s'\n", func);
                if (file_line == "") {
                    file_path = extract_file_path_from (str);

                }
                //stdout.printf ("12 '%s'\n", func);
                // The file name may ends with .so or .so.0 ...
                if( ".so" in file_path ) {
                    process_info_from_lib (file_path, str);
                }
                //stdout.printf ("14 '%s'\n", func);
                if( show_debug_frames )
                {
                    stdout.printf ("\nFrame %d \n--------\n  . addr: [%s]\n  . full_line: '%s'\n  . file_line: '%s'\n  . func_line: '%s'\n  . str : '%s'\n  . func: '%s'\n  . file: '%s'\n  . line: '%s'\n  . address: '%#08x'\n  . lib_address: '%s'\n",
                    i, addr, full_line, file_line, func_line, str, func, file_path, l, address, lib_address);
                }
                if (func != "" && file_path.has_suffix (".vala") && trace.is_all_function_name_blank)
                    trace.is_all_function_name_blank = false;

                if (short_file_path != "" && trace.is_all_file_name_blank)
                    trace.is_all_file_name_blank = false;

                var line_number = extract_line (file_line);
                var frame = new Frame (addr, file_line, func, file_path, short_file_path, line_number);

                if (trace.first_vala == null && file_path.has_suffix (".vala"))
                    trace.first_vala = frame;

                if (short_file_path.length > trace.max_file_name_length)
                    trace.max_file_name_length = short_file_path.length;
                if (l.length > trace.max_line_number_length)
                    trace.max_line_number_length = l.length;
                trace.frames.add (frame);
            }
        }
    }
}
