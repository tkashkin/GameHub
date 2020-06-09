/*
This file is part of GameHub.
Copyright (C) 2020 Alexander Schlarb

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

namespace GameHub.Utils
{
	public errordomain RunError
	{
		// Wrap errors returned by GLib.IOError
		FAILED = IOError.FAILED,
		NOT_FOUND = IOError.NOT_FOUND,
		EXISTS = IOError.EXISTS,
		IS_DIRECTORY = IOError.IS_DIRECTORY,
		NOT_DIRECTORY = IOError.NOT_DIRECTORY,
		NOT_EMPTY = IOError.NOT_EMPTY,
		NOT_REGULAR_FILE = IOError.NOT_REGULAR_FILE,
		NOT_SYMBOLIC_LINK = IOError.NOT_SYMBOLIC_LINK,
		NOT_MOUNTABLE_FILE = IOError.NOT_MOUNTABLE_FILE,
		FILENAME_TOO_LONG = IOError.FILENAME_TOO_LONG,
		INVALID_FILENAME = IOError.INVALID_FILENAME,
		TOO_MANY_LINKS = IOError.TOO_MANY_LINKS,
		NO_SPACE = IOError.NO_SPACE,
		INVALID_ARGUMENT = IOError.INVALID_ARGUMENT,
		PERMISSION_DENIED = IOError.PERMISSION_DENIED,
		NOT_SUPPORTED = IOError.NOT_SUPPORTED,
		NOT_MOUNTED = IOError.NOT_MOUNTED,
		ALREADY_MOUNTED = IOError.ALREADY_MOUNTED,
		CLOSED = IOError.CLOSED,
		CANCELLED = IOError.CANCELLED,
		PENDING = IOError.PENDING,
		READ_ONLY = IOError.READ_ONLY,
		CANT_CREATE_BACKUP = IOError.CANT_CREATE_BACKUP,
		WRONG_ETAG = IOError.WRONG_ETAG,
		TIMED_OUT = IOError.TIMED_OUT,
		WOULD_RECURSE = IOError.WOULD_RECURSE,
		BUSY = IOError.BUSY,
		WOULD_BLOCK = IOError.WOULD_BLOCK,
		HOST_NOT_FOUND = IOError.HOST_NOT_FOUND,
		WOULD_MERGE = IOError.WOULD_MERGE,
		FAILED_HANDLED = IOError.FAILED_HANDLED,
		TOO_MANY_OPEN_FILES = IOError.TOO_MANY_OPEN_FILES,
		NOT_INITIALIZED = IOError.NOT_INITIALIZED,
		ADDRESS_IN_USE = IOError.ADDRESS_IN_USE,
		PARTIAL_INPUT = IOError.PARTIAL_INPUT,
		INVALID_DATA = IOError.INVALID_DATA,
		DBUS_ERROR = IOError.DBUS_ERROR,
		HOST_UNREACHABLE = IOError.HOST_UNREACHABLE,
		NETWORK_UNREACHABLE = IOError.NETWORK_UNREACHABLE,
		CONNECTION_REFUSED = IOError.CONNECTION_REFUSED,
		PROXY_FAILED = IOError.PROXY_FAILED,
		PROXY_AUTH_FAILED = IOError.PROXY_AUTH_FAILED,
		PROXY_NEED_AUTH = IOError.PROXY_NEED_AUTH,
		PROXY_NOT_ALLOWED = IOError.PROXY_NOT_ALLOWED,
		BROKEN_PIPE = IOError.BROKEN_PIPE,
		CONNECTION_CLOSED = IOError.CONNECTION_CLOSED,
		NOT_CONNECTED = IOError.NOT_CONNECTED,
		MESSAGE_TOO_LARGE = IOError.MESSAGE_TOO_LARGE,
		
		// Extension for exit status of run programs
		ERROR_STATUS      = 10000 + 0,
		COMMAND_NOT_FOUND = 10000 + 1;
		
		public static RunError from_io_error_literal(IOError e, string prefix)
		{
			// Retain original error code by creating a `RunError` instance with
			// an arbitrary error code (FAILED) and then overwriting the code
			// attribute (we cannot use `new Error` since Vala does not allow us
			// to access the errordomain's Quark function directly)
			RunError error = new RunError.FAILED("%s%s", prefix, e.message);
			error.code = e.code;
			return error;
		}
		
		[PrintfFormat]
		public static RunError from_io_error(IOError e, string prefix_fmt, ...)
		{
			if(prefix_fmt.length > 0)
			{
				// Realize the given format string
				va_list va_list = va_list();
				string prefix = prefix_fmt.vprintf(va_list);
				
				return RunError.from_io_error_literal(e, prefix);
			}
			else
			{
				return RunError.from_io_error_literal(e, "");
			}
		}
		
		public static RunError from_spawn_error_literal(SpawnError e, string prefix)
		{
			// Map wrapped errno codes back to POSIX
			int error_code = IOError.FAILED;
			switch(e.code)
			{
				// Official mappings from gio/gioerror.c
				case SpawnError.ACCES:
				case SpawnError.PERM:
					error_code = IOError.PERMISSION_DENIED;
					break;
				case SpawnError.NAMETOOLONG:
					error_code = IOError.FILENAME_TOO_LONG;
					break;
				case SpawnError.NOENT:
					error_code = IOError.NOT_FOUND;
					break;
				case SpawnError.NOMEM:
					error_code = IOError.NO_SPACE;
					break;
				case SpawnError.NOTDIR:
					error_code = IOError.NOT_DIRECTORY;
					break;
				case SpawnError.LOOP:
					error_code = IOError.TOO_MANY_LINKS;
					break;
				case SpawnError.TXTBUSY:
					error_code = IOError.BUSY;
					break;
				case SpawnError.MFILE:
				case SpawnError.NFILE:
					error_code = IOError.TOO_MANY_OPEN_FILES;
					break;
				case SpawnError.INVAL:
					error_code = IOError.INVALID_ARGUMENT;
					break;
				case SpawnError.ISDIR:
					error_code = IOError.IS_DIRECTORY;
					break;
				// Approximated mappings
				case SpawnError.NOEXEC:
					error_code = IOError.NOT_SUPPORTED;
					break;
				case SpawnError.LIBBAD:
					error_code = IOError.INVALID_ARGUMENT;
					break;
				// Items without mapping (included for documentation)
				case SpawnError.TOO_BIG:
				case SpawnError.IO:
				default:
					break;
			}
			
			// Also display errors that do not directly map to some POSIX error
			// by name for extra context
			unowned string? error_name = null;
			switch(e.code)
			{
				case SpawnError.FORK:
					error_name = "FORK";
					break;
				case SpawnError.READ:
					error_name = "READ";
					break;
				case SpawnError.CHDIR:
					error_name = "CHDIR";
					break;
				case SpawnError.FAILED:
					error_name = "FAILED";
					break;
			}
			
			// Use mapped error code by creating a `RunError` instance with
			// an arbitrary error code (FAILED) and then overwriting the code
			// attribute (we cannot use `new Error` since Vala does not allow us
			// to access the errordomain's Quark function directly)
			RunError error;
			if(error_name != null)
			{
				error = new RunError.FAILED(
					"%s%s (%s:%s)", prefix, e.message,
					e.domain.to_string(), error_name
				);
			}
			else
			{
				error = new RunError.FAILED("%s%s", prefix, e.message);
			}
			error.code = error_code;
			return error;
		}
		
		[PrintfFormat]
		public static RunError from_spawn_error(SpawnError e, string prefix_fmt, ...)
		{
			if(prefix_fmt.length > 0)
			{
				// Realize the given format string
				va_list va_list = va_list();
				string prefix = prefix_fmt.vprintf(va_list);
				
				return RunError.from_spawn_error_literal(e, prefix);
			}
			else
			{
				return RunError.from_spawn_error_literal(e, "");
			}
		}
		
		
		/**
		 * Like `GLib.Error.prefix` but with different output type
		 * 
		 * This cannot be a method as Vala does not support methods on error
		 * domains “yet”.
		 */
		[PrintfFormat]
		public static void prefix(ref RunError? error, string fmt, ...)
		{
			if(error == null) {
				return;
			}
			
			va_list va_list = va_list();
			error.message = fmt.vprintf(va_list) + error.message;
		}
	}
}
