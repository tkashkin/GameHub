/*
This file is part of GameHub.
Copyright (C) 2018-2019 Anatoliy Kashkin

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

using GameHub.Data;
using GameHub.Data.Tweaks;

namespace GameHub.Utils
{
	public class ExecTask
	{
		private string[] _cmd;
		private string? _dir = null;
		private string[]? _env = null;
		private HashMap<string, string>? _env_vars = null;
		private bool _override_runtime = false;
		private bool _log = true;
		private Tweak[]? _tweaks = null;
		private TweakOptions? _tweak_options = null;

		public ExecTask(string[] cmd) { _cmd = cmd; }

		public ExecTask cmd(string[] cmd) { _cmd = cmd; return this; }
		public ExecTask dir(string? dir=null) { _dir = dir; return this; }
		public ExecTask env(string[]? env=null) { _env = env; return this; }
		public ExecTask env_var(string name, string? value=null) { if(_env_vars == null) _env_vars = new HashMap<string, string>(); _env_vars.set(name, value); return this; }
		public ExecTask override_runtime(bool override_runtime=false) { _override_runtime = override_runtime; return this; }
		public ExecTask log(bool log=true) { _log = log; return this; }
		public ExecTask tweaks(Tweak[]? tweaks=null, TweakOptions? tweak_options=null) { _tweaks = tweaks; _tweak_options = tweak_options; return this; }

		private string expand_options(string value)
		{
			if(_tweak_options != null)
			{
				return _tweak_options.expand(value);
			}
			return value;
		}

		private bool _expanded = false;
		private void expand()
		{
			if(_expanded) return;
			_expanded = true;

			var cmd_expanded = false;

			if(_log) debug("[ExecTask] {'%s'}", string.joinv("' '", _cmd));

			_dir = _dir ?? Environment.get_home_dir();
			_env = _env ?? Environ.get();

			#if PKG_APPIMAGE
			_env = Environ.unset_variable(_env, "LD_LIBRARY_PATH");
			_env = Environ.unset_variable(_env, "LD_PRELOAD");
			#endif

			if(_env_vars != null)
			{
				foreach(var env_var in _env_vars.entries)
				{
					if(env_var.value != null)
					{
						_env = Environ.set_variable(_env, env_var.key, expand_options(env_var.value));
					}
					else
					{
						_env = Environ.unset_variable(_env, env_var.key);
					}
				}
			}

			if(_tweaks != null)
			{
				foreach(var tweak in _tweaks)
				{
					if(tweak.env != null)
					{
						foreach(var env_var in tweak.env.entries)
						{
							if(env_var.value != null)
							{
								_env = Environ.set_variable(_env, env_var.key, expand_options(env_var.value));
							}
							else
							{
								_env = Environ.unset_variable(_env, env_var.key);
							}
						}
					}

					if(tweak.command != null && tweak.command.length > 0)
					{
						string[] tweaked_cmd = _cmd;
						var tweak_cmd = Utils.parse_args(tweak.command);
						if(tweak_cmd != null)
						{
							if("$command" in tweak_cmd || "${command}" in tweak_cmd)
							{
								tweaked_cmd = {};
							}
							foreach(var arg in tweak_cmd)
							{
								if(arg == "$command" || arg == "${command}")
								{
									foreach(var a in _cmd)
									{
										tweaked_cmd += a;
									}
								}
								else
								{
									tweaked_cmd += expand_options(arg);
								}
							}
							cmd_expanded = true;
						}
						_cmd = tweaked_cmd;
					}
				}
			}

			#if PKG_FLATPAK
			if(_override_runtime && ProjectConfig.RUNTIME.length > 0)
			{
				_env = Environ.set_variable(_env, "LD_LIBRARY_PATH", ProjectConfig.RUNTIME);
			}
			string[] cmd = { "flatpak-spawn", "--host" };
			foreach(var arg in _cmd)
			{
				cmd += arg;
			}
			_cmd = cmd;
			cmd_expanded = true;
			#endif

			if(_log && GameHub.Application.log_verbose)
			{
				if(cmd_expanded) debug("      cmd: {'%s'}", string.joinv("' '", _cmd));
				debug("      dir: '%s'", _dir);

				string[] env_diff = {};
				string[] env_clean = Environ.get();
				foreach(var env_var in _env)
				{
					if(!(env_var in env_clean))
					{
						env_diff += env_var;
					}
				}
				if(env_diff.length > 0)
				{
					debug("      env: {\n                   '%s'\n               }", string.joinv("'\n                   '", env_diff));
				}
			}
		}

		public Result? sync(bool capture_output=false)
		{
			var is_called_from_thread = _expanded;
			expand();
			try
			{
				if(_log && !is_called_from_thread) debug("      .sync()");
				int status;
				if(capture_output)
				{
					string sout;
					string serr;
					Process.spawn_sync(_dir, _cmd, _env, SpawnFlags.SEARCH_PATH, null, out sout, out serr, out status);
					sout = sout.strip();
					serr = serr.strip();
					if(_log)
					{
						if(sout.length > 0) print(sout + "\n");
						if(serr.length > 0) warning(serr);
					}
					return new Result(status, sout, serr);
				}
				else
				{
					Process.spawn_sync(_dir, _cmd, _env, SpawnFlags.SEARCH_PATH | SpawnFlags.CHILD_INHERITS_STDIN | SpawnFlags.STDERR_TO_DEV_NULL, null, null, null, out status);
					return new Result(status);
				}
			}
			catch (Error e)
			{
				warning("[ExecTask.sync] %s", e.message);
			}
			return null;
		}

		public async Result? sync_thread(bool capture_output=false)
		{
			expand();
			Result? result = null;
			Utils.thread("ExecTask.sync_thread", () => {
				if(_log) debug("      .sync_thread()");
				result = sync(capture_output);
				Idle.add(sync_thread.callback);
			}, _log);
			yield;
			return result;
		}

		public async Result? async(bool wait=true)
		{
			expand();
			Result? result = null;
			try
			{
				if(_log) debug("      .async()");
				Pid pid;
				Process.spawn_async(_dir, _cmd, _env, SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD, null, out pid);
				ChildWatch.add(pid, (pid, status) => {
					Process.close_pid(pid);
					result = new Result(status);
					Idle.add(async.callback);
				});
			}
			catch (Error e)
			{
				warning("[ExecTask.async] %s", e.message);
			}
			if(wait) yield;
			return result;
		}

		public class Result
		{
			public int? status;
			public int? exit_code;
			public string? output;
			public string? errors;

			public Result(int? status, string? output=null, string? errors=null)
			{
				this.status = status;
				this.output = output;
				this.errors = errors;
				if(this.status != null)
				{
					this.exit_code = Process.exit_status(this.status);
				}
			}

			public bool check_status() throws Error
			{
				if(this.status != null)
				{
					return Process.check_exit_status(this.status);
				}
				return true;
			}
		}
	}

	public static ExecTask exec(string[] cmd)
	{
		return new ExecTask(cmd);
	}
}
