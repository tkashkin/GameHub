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
     * A part of a stacktrace
     * 
     * This class represent on instance of a frame, ie a particular location 
     * in a binary (application or library) on the system called by the application
     *
     * ''Note:'' frames from system libraries without code information available are 
     * not displayed by default. See {@link Stacktrace.hide_installed_libraries} for how to
     * display them.   
     **/
    public class Frame {
        
        /**
         * Address of the stack in hexadecimal
         * 
         * Ex: ``0x309``
         **/
        public string address  { get;private set;default = "";}
        
        /**
         * Line of code of the frame 
         * 
         * Can point to C code, Vala code or be blank if 
         * no symbol is available (or if -rdynamic has not been set during the
         * compilation of the binary) 
         *
         * Ex: 
         **/
        public string line { get;private set;default = "";}

        /**
         * Line number in the code file. 
         * 
         * May be blank if no code information is available 
         *
         * Ex: ``25``
         **/
        public string line_number { get;private set;default = "";}

        /**
         * Full path to the code file as it was stored on the building machine
         * 
         * Returns the path to the installed binary if no code information is available 
         *
         * Ex: ``/home/cran/Documents/Projects/i-hate-farms/stacktrace/samples/error_sigsegv.vala`` 
         *
         * Ex: ``/lib/x86_64-linux-gnu/libc.so.6`` if no code information is available
         **/
        public string file_path { get;private set;default = "";}
        
        /**
         * Path the code file relative to the current path
         * 
         * Returns the path to the installed binary if no code information is available  
         * 
         * Ex: ``/stuff/to/stuff/``
         **/
        public string file_short_path { get;private set;default = "";}

        /**
         * C function name 
         * 
         * Because only the C function name is avaialable, 
         * the name mixes the vala class and vala method name (by default separated by ``_``).
         * 
         * For more information about getting full vala names see [[https://bugzilla.gnome.org/show_bug.cgi?id=738784|vala bug #738784]]
         * 
         * Ex: ``namespace_someclass_method`` 
         **/       
        public string function { get;private set;default = "";}

        public Frame (string address, string line, string function, string file_path, string file_short_path, string line_number) {
            this._address = address;
            this._line = line;

            this._file_path = file_path;
            this._file_short_path = file_short_path;
            this._function = function;
            this.line_number = line_number;
        }

    }

}
