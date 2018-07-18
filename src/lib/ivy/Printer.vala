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
     * Prints the stacktrace to ``stdout`` in colors
     * 
     */     
    public class Printer {

        private Color background_color = Color.BLACK;
        private int title_length = 0;

        private Stacktrace stacktrace;

       private string get_reset_code () {
            // return get_color_code (Style.RESET, Colors.WHITE, Colors.BLACK);
            return "\x1b[0m";
        }

        private string get_reset_style () {
            return get_color_code (Style.DIM, stacktrace.highlight_color, background_color);
        }

        private string get_color_code (Style attr, Color fg, Color bg = background_color) {
            /* Command is the control command to the terminal */
            if (bg == Color.BLACK)
                return "%c[%d;%dm".printf (0x1B, (int) attr, (int) fg + 30);
            else
                return "%c[%d;%d;%dm".printf (0x1B, (int) attr, (int) fg + 30, (int) bg + 40);
        }

        private string get_signal_name () {
            return stacktrace.sig.to_string ();
        }

        private string get_highlight_code () {
            return get_color_code (Style.BRIGHT, stacktrace.highlight_color);
        }

        private string get_printable_function (Frame frame, int padding = 0) {
            var result = "";
            var is_unknown = false;
            if (frame.function == "") {
                result = "<unknown> " + frame.address;
                is_unknown = true;
            } else {
                var s = "";
                int count = padding - get_signal_name ().length;
                if (padding != 0 && count > 0)
                    s = string.nfill (count, ' ');
                result = "'" + frame.function + "'" + s;
            }
            if (is_unknown)
                return result + get_reset_code ();
            else
                return get_highlight_code () + result + get_reset_code ();
        }

        private string get_printable_line_number (Frame frame, bool pad = true) {
            var path = frame.line_number;
            var max_line_number_length = stacktrace.max_line_number_length;
            var result = "";
            var color = get_highlight_code ();
            if (path.length >= max_line_number_length || !pad)
                result = color + path + get_reset_style ();
            else {
                result = color + path + get_reset_style ();
                result = string.nfill (max_line_number_length - path.length, ' ') + result;
            }
            return result;
        }

        private string get_printable_file_short_path (Frame frame, bool pad = true) {
            var path = frame.file_short_path;
            var max_file_name_length = stacktrace.max_file_name_length;
            var result = "";
            var color = get_highlight_code ();
            if (path.length >= max_file_name_length || !pad)
                result = color + path + get_reset_style ();
            else {
                result = color + path + get_reset_style ();
                result = result + string.nfill (max_file_name_length - path.length, ' ');
            }
            return result;
        }

        private string get_printable_title () {
            var c = get_color_code (Style.DIM, stacktrace.highlight_color, background_color);
            var color = get_highlight_code ();

            var result = "";

            if( stacktrace.is_custom)
                result = "%sA function was called in %s".printf (
                    c,
                    get_reset_style ());
            else
                result = "%sAn error occured %s(%s)%s".printf (
                    c,
                    color,
                    get_signal_name (),
                    get_reset_style ());

            title_length = get_signal_name ().length;
            return result;
        }

        private string get_reason () {
            // var c = get_reset_code();
            var sig = stacktrace.sig;

            var color = get_highlight_code ();
            if (sig == ProcessSignal.TRAP) {
                return "The reason is likely %san uncaught error%s".printf (
                    color, get_reset_code ());
            }
            if (sig == ProcessSignal.ABRT) {
                return "The reason is likely %sa failed assertion (assert...)%s".printf (
                    color, get_reset_code ());
            }
            if (sig == ProcessSignal.SEGV) {
                return "The reason is likely %sa null reference being used%s".printf (
                    color, get_reset_code ());
            }
            return "Unknown reason";
        }

        /**
         * Print the stacktrace to ``stdout``
         *
         * @param trace the stacktrace 
         * 
         */
        public virtual void print (Stacktrace trace) {
            this.stacktrace = trace;
            background_color = stacktrace.error_background;
            var header = "%s%s\n".printf (get_printable_title (),
                                          get_reset_code ());
            var first_vala = trace.first_vala;

            if (trace.first_vala != null) {
                header = "%s in %s, line %s in %s\n".printf (
                    get_printable_title (),
                    get_printable_file_short_path (first_vala, false),
                    get_printable_line_number (first_vala, false),
                    get_printable_function (first_vala) + get_reset_code ());
                title_length += first_vala.line_number.length +
                                first_vala.function.length +
                                first_vala.file_short_path.length;
            }
            stdout.printf (header);
            background_color = Color.BLACK;
            if( !stacktrace.is_custom) {
                var reason = get_reason ();
                stdout.printf ("   %s.\n", reason);
            }
            var is_all_file_name_blank = stacktrace.is_all_file_name_blank;

            // Has the user forgot to compile with -g -X -rdynamic flag ?
            if (is_all_file_name_blank) {
                var advice = "   %sNote%s: no file path and line numbers can be retrieved. Are you sure %syou added -g -X -rdynamic%s to valac command line?\n";
                var color = get_highlight_code ();
                stdout.printf (advice, color, get_reset_code (), color, get_reset_code ());
            }

            // Has the user forgot to compile with rdynamic flag ?
            if (stacktrace.is_all_function_name_blank && !is_all_file_name_blank) {
                var advice = "   %sNote%s: no vala function name can be retrieved. Are you sure %syou added -X -rdynamic%s to valac command line?\n";
                var color = get_highlight_code ();
                stdout.printf (advice, color, get_reset_code (), color, get_reset_code ());
            }

            stdout.printf ("\n");
            int i = 1;
            bool has_displayed_first_vala = false;
            foreach (var frame in trace.frames) {
                var show_frame = frame.function != "" || frame.file_path.has_suffix (".vala") || frame.file_path.has_suffix (".c");
                if (Stacktrace.hide_installed_libraries && has_displayed_first_vala)
                    show_frame = show_frame && frame.file_short_path != "";

                // Ignore glib tracing code if displayed before the first vala frame
                if ((frame.function == "g_logv" || frame.function == "g_log") && !has_displayed_first_vala)
                    show_frame = false;
                if (show_frame) {
                    // #2  ./OtherModule.c      line 80      in 'other_module_do_it'
                    // at /home/cran/Projects/noise/noise-perf-instant-search/tests/errors/module/OtherModule.vala:10
                    var str = " %s  #%d  %s    line %s in %s\n";
                    background_color = Color.BLACK;
                    var lead = " ";
                    var function_padding = 0;
                    if (frame == first_vala) {
                        has_displayed_first_vala = true;
                        lead = "*";
                        background_color = stacktrace.error_background;
                        function_padding = 22;
                    }
                    var l_number = "";
                    if (frame.line_number == "") {
                        str = " %s  #%d  <unknown>  %s in %s\n";
                        var func_name = get_printable_function (frame);
                        var fill_len = int.max (stacktrace.max_file_name_length + stacktrace.max_line_number_length - 1, 0);
                        str = str.printf (
                            lead,
                            i,
                            string.nfill (fill_len, ' '),
                            func_name);
                    } else {
                        str = str.printf (
                            lead,
                            i,
                            get_printable_file_short_path (frame),
                            get_printable_line_number (frame),
                            get_printable_function (frame, function_padding));
                        l_number = ":" + frame.line_number;
                    }
                    stdout.printf (str);
                    str = "        at %s%s\n".printf (
                        frame.file_path, l_number);
                    stdout.printf (str);

                    i++;
                }
            }
        }

    }
}
