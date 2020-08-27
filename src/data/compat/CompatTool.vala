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

using GameHub.Data.Runnables;
using GameHub.Data.Runnables.Tasks.Install;
using GameHub.Data.Runnables.Tasks.Run;

using GameHub.Utils;

namespace GameHub.Data.Compat
{
	public abstract class CompatTool: BaseObject
	{
		public string tool { get; protected construct set; default = "null"; }
		public string id { get; protected construct set; default = "null"; }
		public string full_id { owned get { return "%s:%s".printf(tool, id); } }

		public string? name { get; protected construct set; }
		public string icon { get; protected construct set; default = "application-x-executable-symbolic"; }
		public string? version { get; protected set; }

		public File executable { get; protected construct set; }
		public string? info { get; protected set; }
		public string? options { get; protected set; }
	}

	namespace CompatToolTraits
	{
		public interface Install: CompatTool
		{
			public abstract bool can_install(Traits.SupportsCompatTools runnable, InstallTask task);
			public abstract async void install(Traits.SupportsCompatTools runnable, InstallTask task, File installer);
		}

		public interface Run: CompatTool
		{
			public abstract bool can_run(Traits.SupportsCompatTools runnable);
			public abstract async void run(Traits.SupportsCompatTools runnable);
		}
	}
}
