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

namespace GameHub.Utils
{
	public class BaseObject: Object
	{
		public delegate void CastAction<T>(T self);
		public T? cast<T>(CastAction<T>? action=null)
		{
			if(this is T)
			{
				if(action != null) action((T) this);
				return (T) this;
			}
			return null;
		}
	}
}
