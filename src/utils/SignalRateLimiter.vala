/*
This file is part of GameHub.
Copyright (C) Anatoliy Kashkin

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
	public class SignalRateLimiter: Object
	{
		private static uint MICROSECONDS_TO_MS = 1000;

		public signal void signaled();

		public uint interval { get; construct; }

		public SignalRateLimiter(uint interval = 100)
		{
			Object(interval: interval);
		}

		private int64 signal_time = 0;
		private uint? handler = null;

		public void update()
		{
			if(handler == null)
			{
				handler = Timeout.add(interval, handle);
			}
			signal_time = get_monotonic_time();
		}

		private bool handle()
		{
			var now = get_monotonic_time();
			if(now - signal_time > interval * MICROSECONDS_TO_MS)
			{
				signaled();
				handler = null;
				return Source.REMOVE;
			}
			return Source.CONTINUE;
		}
	}
}
