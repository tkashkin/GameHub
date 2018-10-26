/*
This file is part of GameHub.
Copyright (C) 2018 Anatoliy Kashkin

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

using GameHub.Data.DB;
using GameHub.Utils;

namespace GameHub.Data.Compat
{
	public class CustomEmulator: CompatTool
	{
		public static CustomEmulator instance;

		private ArrayList<string> emulator_names = new ArrayList<string>();

		private CompatTool.ComboOption emu_option;

		public CustomEmulator()
		{
			instance = this;
		}

		construct
		{
			id = "emulator";
			name = _("Custom emulator");
			icon = "input-gaming-symbolic";

			installed = true;

			emu_option = new CompatTool.ComboOption("emulator", _("Emulator"), emulator_names, null);

			update_emulators();

			options = { emu_option };
		}

		public void update_emulators()
		{
			emulator_names.clear();

			var emulators = Tables.Emulators.get_all();

			foreach(var emu in emulators)
			{
				emulator_names.add(emu.name);
			}

			emu_option.options = emulator_names;
		}

		public override bool can_run(Runnable game)
		{
			update_emulators();
			return installed && game is Game && emulator_names.size > 0;
		}

		public override async void run(Runnable game)
		{
			if(!can_run(game)) return;

			var emu = Tables.Emulators.by_name(emu_option.value);
			if(emu == null) return;

			yield emu.run_game(game as Game);
		}
	}
}
