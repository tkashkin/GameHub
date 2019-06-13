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
using GameHub.Utils;

namespace GameHub.Data.Providers.Data
{
	public class IGDB: DataProvider
	{
		private const string SCHEME        = "https://";
		private const string DOMAIN        = "igdb.com";
		private const string API_SUBDOMAIN = "api-v3";
		private const string API_BASE_URL  = SCHEME + API_SUBDOMAIN + DOMAIN;

		public override string id   { get { return "igdb"; } }
		public override string name { get { return "IGDB"; } }
		public override string url  { get { return SCHEME + DOMAIN; } }

		public override bool enabled
		{
			get { return Settings.Providers.Data.IGDB.get_instance().enabled; }
			set { Settings.Providers.Data.IGDB.get_instance().enabled = value; }
		}

		public override async DataProvider.Result data(Game game)
		{
			var result = new Result();



			return result;
		}

		public class Result: DataProvider.Result
		{

		}
	}
}
