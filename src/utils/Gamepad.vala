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

using Gdk;
using Gee;

namespace GameHub.Utils.Gamepad
{
	public static HashMap<uint16, Button> Buttons;

	public static Button BTN_A;
	public static Button BTN_B;
	public static Button BTN_C;
	public static Button BTN_X;
	public static Button BTN_Y;
	public static Button BTN_Z;

	public static Button BUMPER_LEFT;
	public static Button BUMPER_RIGHT;

	public static Button TRIGGER_LEFT;
	public static Button TRIGGER_RIGHT;

	public static Button STICK_LEFT;
	public static Button STICK_RIGHT;

	public static Button BTN_SELECT;
	public static Button BTN_START;
	public static Button BTN_HOME;

	public static Button DPAD_UP;
	public static Button DPAD_DOWN;
	public static Button DPAD_LEFT;
	public static Button DPAD_RIGHT;

	public static Button SC_PAD_TAP_LEFT;
	public static Button SC_PAD_TAP_RIGHT;

	public static Button SC_GRIP_LEFT;
	public static Button SC_GRIP_RIGHT;

	public static void init()
	{
		Buttons = new Gee.HashMap<uint16, Button>();

		BTN_A = b(0x130, "A", null, "Return");
		BTN_B = b(0x131, "B", null, "Escape");
		BTN_C = b(0x132, "C", null);
		BTN_X = b(0x133, "X", null, "Menu");
		BTN_Y = b(0x134, "Y", null);
		BTN_Z = b(0x135, "Z", null);

		BUMPER_LEFT  = b(0x136, "LB", "Left Bumper");
		BUMPER_RIGHT = b(0x137, "RB", "Right Bumper");

		TRIGGER_LEFT  = b(0x138, "LT", "Left Trigger");
		TRIGGER_RIGHT = b(0x139, "RT", "Right Trigger");

		BTN_SELECT = b(0x13a, "Select", null);
		BTN_START  = b(0x13b, "Start", null);
		BTN_HOME   = b(0x13c, "Home", null);

		STICK_LEFT  = b(0x13d, "LS", "Left Stick");
		STICK_RIGHT = b(0x13e, "RS", "Right Stick");

		DPAD_UP    = b(0x220, "Up", "D-Pad Up", "Up");
		DPAD_DOWN  = b(0x221, "Down", "D-Pad Down", "Down");
		DPAD_LEFT  = b(0x222, "Left", "D-Pad Left", "Left");
		DPAD_RIGHT = b(0x223, "Right", "D-Pad Right", "Right");

		SC_PAD_TAP_LEFT  = b(0x121, "L", "Left Touchpad Tap");
		SC_PAD_TAP_RIGHT = b(0x122, "R", "Right Touchpad Tap");

		SC_GRIP_LEFT  = b(0x150, "LG", "Left Grip");
		SC_GRIP_RIGHT = b(0x151, "RG", "Right Grip");
	}

	private static Button b(uint16 code, string name, string? long_name=null, string? key_name=null)
	{
		var btn = new Button(code, name, long_name, key_name);
		Buttons.set(code, btn);
		return btn;
	}

	public class Button: Object
	{
		public uint16 code { get; construct; }
		public string name { get; construct; }
		public string long_name { get; construct; }
		public string? key_name { get; construct; }

		public Button(uint16 code, string name, string? long_name=null, string? key_name=null)
		{
			Object(code: code, name: name, long_name: long_name ?? name, key_name: key_name);
		}

		// hack, but works (on X11)
		public void emit_kb_event(EventType type)
		{
			if(key_name == null) return;
			var event = type == EventType.KEY_RELEASE ? "keyup" : "keydown";
			Utils.run({ "xdotool", event, key_name });
		}
	}
}
