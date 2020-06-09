/*
This file is part of GameHub.
Copyright (C) 2018-2019 Anatoliy Kashkin
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

using Gee;

using GameHub.Utils;

namespace GameHub.Data
{
	public abstract class CompatTool: Object
	{
		public string id { get; protected set; default = "null"; }
		public string name { get; protected set; default = ""; }
		public string icon { get; protected set; default = "application-x-executable-symbolic"; }
		public File? executable { get; protected set; default = null; }
		public bool installed { get; protected set; default = false; }

		public Option[]? options = null;
		public Option[]? install_options = null;
		public Action[]? actions = null;

		public string[]? warnings = null;

		public virtual bool can_install(Runnable runnable) { return false; }
		public virtual bool can_run(Runnable runnable) { return false; }
		public virtual bool can_run_action(Runnable runnable, Runnable.RunnableAction action) { return false; }

		public virtual File get_install_root(Runnable runnable) { return runnable.install_dir; }

		public virtual async void install(Runnable runnable, File installer) throws Utils.RunError {}
		public virtual async void run(Runnable game) throws Utils.RunError {}
		public virtual async void run_action(Runnable runnable, Runnable.RunnableAction action) throws Utils.RunError {}
		public virtual async void run_emulator(Emulator emu, Game? game, bool launch_in_game_dir=false) throws Utils.RunError {}

		protected string[] combine_cmd_with_args(string[] cmd, Runnable runnable, string[]? args_override=null)
		{
			string[] full_cmd = cmd;

			var args = args_override ?? Utils.parse_args(runnable.arguments);
			if(args != null)
			{
				if("$command" in args || "${command}" in args)
				{
					full_cmd = {};
				}

				var variables = new HashMap<string, string>();
				variables.set("game", runnable.name.replace(": ", " - ").replace(":", ""));
				variables.set("game_dir", runnable.install_dir.get_path());

				foreach(var arg in args)
				{
					if(arg == "$command" || arg == "${command}")
					{
						foreach(var a in cmd)
						{
							full_cmd += a;
						}
					}
					else
					{
						if("$" in arg)
						{
							arg = FSUtils.expand(arg, null, variables);
						}
						full_cmd += arg;
					}
				}
			}

			return full_cmd;
		}

		protected void ensure_installed() throws Utils.RunError
		{
			if(!this.installed)
			{
				throw new Utils.RunError.COMMAND_NOT_FOUND("%s does not appear to be installed", this.name);
			}
		}

		public static CompatTool? by_id(string? id)
		{
			foreach(var tool in CompatTools)
			{
				if(tool.id == id)
				{
					return tool;
				}
			}
			return null;
		}

		public abstract class Option: Object
		{
			public string name { get; construct; }
			public string description { get; construct; }
		}

		public class BoolOption: Option
		{
			public bool enabled { get; construct set; }
			public BoolOption(string name, string description, bool enabled)
			{
				Object(name: name, description: description, enabled: enabled);
			}
		}

		public class StringOption: Option
		{
			public string? value { get; construct set; }
			public string? icon { get; set; default = null; }
			public StringOption(string name, string description, string? value)
			{
				Object(name: name, description: description, value: value);
			}
		}

		public class FileOption: Option
		{
			public File? directory { get; construct set; }
			public File? file { get; construct set; }
			public Gtk.FileChooserAction mode { get; construct set; }
			public string? icon { get; set; default = null; }
			public FileOption(string name, string description, File? directory, File? file, Gtk.FileChooserAction mode=Gtk.FileChooserAction.OPEN)
			{
				Object(name: name, description: description, directory: directory, file: file, mode: mode);
			}
		}

		public class ComboOption: StringOption
		{
			public ArrayList<string> options { get; construct set; }
			public ComboOption(string name, string description, ArrayList<string> options, string? value)
			{
				Object(name: name, description: description, options: options, value: value);
			}
		}

		public class Action: Object
		{
			// `GLib.AsyncReadyCallback` compatible callback returned by `DelegateCallback`
			private delegate void DelegateCallback2(Object? obj, AsyncResult res);
			
			// Callback passed to `DelegateCallback` that is invoked when the action
			// has been completed to collect the result
			//
			// (Needed as `<async-func>.end` is not a function pointer that can be
			//  passed around in Vala.)
			public delegate void FinishCallback(Object? obj, AsyncResult res) throws Utils.RunError;
			
			// Callback passed to the caller to generate the `DelegateCallback2`
			// instance that may be passed `<async-func>.begin` while storing a
			// reference to the given `FinishCallback`
			public delegate DelegateCallback2 DelegateCallback(FinishCallback callback);
			
			// Callback passed in the constructor to start an async transaction
			// whenever the action is invoked
			//
			// All callbacks but this one would be unnecessary if Vala allowed
			// passing around references to async-functions directly.
			public delegate void Delegate(Runnable runnable, DelegateCallback callback);
			
			public string name { get; construct; }
			public string description { get; construct; }
			private Delegate action;
			public Action(string name, string description, owned Delegate action)
			{
				Object(name: name, description: description);
				this.action = (owned) action;
			}
			public async void invoke(Runnable runnable) throws Utils.RunError
			{
				Utils.RunError? err_result = null;
				this.action(runnable, (callback) => {
					return (obj, res) => {
						try
						{
							callback(obj, res);
						}
						catch(Utils.RunError e)
						{
							err_result = e;
						}
						Idle.add(invoke.callback);
					};
				});
				yield;
				
				if(err_result != null)
				{
					throw err_result;
				}
			}
		}
	}

	public static CompatTool[] CompatTools;
}
