using Gtk;
using Granite;

namespace GameHub.Utils
{
	public delegate void Future();
	public delegate void FutureBoolean(bool result);
	public delegate void FutureResult<T>(T result);
	
	public static void open_uri(string uri, Window? parent = null)
	{
		try
		{			
			AppInfo.launch_default_for_uri(uri, null);
		}
		catch(Error e)
		{
			error(e.message);
		}
	}
	
	public static string run(string cmd)
	{
		string stdout;
		try
		{
			Process.spawn_command_line_sync(cmd, out stdout);
		}
		catch (Error e)
		{
			error(e.message);
		}
		return stdout;
	}
	
	public static async void run_async(string cmd)
	{
		try
		{
			Process.spawn_command_line_async(cmd);
		}
		catch (Error e)
		{
			error(e.message);
		}
	}
	
	public static bool is_package_installed(string package)
	{
		var output = Utils.run("dpkg-query -W -f=${Status} " + package);
		return "install ok installed" in output;
	}
	
	public static async void sleep_async(uint interval, int priority = GLib.Priority.DEFAULT)
	{
		Timeout.add(interval, () => {
			sleep_async.callback();
			return false;
		}, priority);
		yield;
	}
}
