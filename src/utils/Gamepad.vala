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
	public const int KEY_EVENT_EMIT_INTERVAL = 50000;
	public const int KEY_UP_EMIT_TIMEOUT = 50000;

	public static HashMap<uint16, Button> Buttons;
	public static HashMap<uint16, Axis> Axes;

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

	public static Axis AXIS_LS_X;
	public static Axis AXIS_LS_Y;
	public static Axis AXIS_RS_X;
	public static Axis AXIS_RS_Y;

	public static void init()
	{
		Buttons = new HashMap<uint16, Button>();
		Axes = new HashMap<uint16, Axis>();

		BTN_A = b(0x130, "A", null, Key.Return);
		BTN_B = b(0x131, "B", null, Key.Escape);
		BTN_C = b(0x132, "C");
		BTN_X = b(0x133, "X", null, Key.Menu);
		BTN_Y = b(0x134, "Y");
		BTN_Z = b(0x135, "Z");

		BUMPER_LEFT  = b(0x136, "LB", "Left Bumper", Key.F1);
		BUMPER_RIGHT = b(0x137, "RB", "Right Bumper", Key.F2);

		TRIGGER_LEFT  = b(0x138, "LT", "Left Trigger", Key.F3);
		TRIGGER_RIGHT = b(0x139, "RT", "Right Trigger", Key.F4);

		BTN_SELECT = b(0x13a, "Select", null, Key.F5);
		BTN_START  = b(0x13b, "Start", null, Key.F6);
		BTN_HOME   = b(0x13c, "Home", null, Key.F7);

		STICK_LEFT  = b(0x13d, "LS", "Left Stick");
		STICK_RIGHT = b(0x13e, "RS", "Right Stick");

		DPAD_UP    = b(0x220, "Up", "D-Pad Up", Key.Up);
		DPAD_DOWN  = b(0x221, "Down", "D-Pad Down", Key.Down);
		DPAD_LEFT  = b(0x222, "Left", "D-Pad Left", Key.Left);
		DPAD_RIGHT = b(0x223, "Right", "D-Pad Right", Key.Right);

		SC_PAD_TAP_LEFT  = b(0x121, "L", "Left Trackpad Touch");
		SC_PAD_TAP_RIGHT = b(0x122, "R", "Right Trackpad Touch");

		SC_GRIP_LEFT  = b(0x150, "LG", "Left Grip");
		SC_GRIP_RIGHT = b(0x151, "RG", "Right Grip");

		AXIS_LS_X = a(0x0, "LS X", "Left Stick X", Key.Left, Key.Right);
		AXIS_LS_Y = a(0x1, "LS Y", "Left Stick Y", Key.Up, Key.Down);
		AXIS_RS_X = a(0x2, "RS X", "Right Stick X");
		AXIS_RS_Y = a(0x3, "RS Y", "Right Stick Y");
	}

	private static Button b(uint16 code, string name, string? long_name=null, uint key=0)
	{
		var btn = new Button(code, name, long_name, key);
		Buttons.set(code, btn);
		return btn;
	}

	private static Axis a(uint16 code, string name, string? long_name=null, uint negative_key=0, uint positive_key=0, double key_threshold=0.5)
	{
		var axis = new Axis(code, name, long_name, negative_key, positive_key, key_threshold);
		Axes.set(code, axis);
		return axis;
	}

	public class Button: Object
	{
		public uint16 code { get; construct; }
		public string name { get; construct; }
		public string long_name { get; construct; }
		public uint key { get; construct; }

		private bool pressed = false;

		public Button(uint16 code, string name, string? long_name=null, uint key=0)
		{
			Object(code: code, name: name, long_name: long_name ?? name, key: key);
		}

		public void emit_key_event(bool press)
		{
			Gamepad.emit_key_event(key, press);
			pressed = press;
		}

		public void reset()
		{
			if(pressed)
			{
				emit_key_event(false);
			}
		}
	}

	public class Axis: Object
	{
		public uint16 code { get; construct; }
		public string name { get; construct; }
		public string long_name { get; construct; }
		public uint negative_key { get; construct; }
		public uint positive_key { get; construct; }
		public double key_threshold { get; construct; }

		private double _value = 0;
		private int _value_sign = 0;
		private int _pressed_sign = 0;
		private bool _sign_changed = false;

		private Timer timer = new Timer();

		public double value
		{
			get
			{
				return _value;
			}
			set
			{
				int sign = value < -key_threshold ? -1 : (value > key_threshold ? 1 : 0);
				_sign_changed = _value_sign == sign;
				_value_sign = sign;
				_value = value;
			}
		}

		public Axis(uint16 code, string name, string? long_name=null, uint negative_key=0, uint positive_key=0, double key_threshold=0.5)
		{
			Object(code: code, name: name, long_name: long_name ?? name, negative_key: negative_key, positive_key: positive_key, key_threshold: key_threshold);
		}

		public void emit_key_event()
		{
			if(negative_key == 0 && positive_key == 0) return;

			ulong last_update;
			timer.elapsed(out last_update);
			if(_value_sign == 0 && last_update >= Gamepad.KEY_UP_EMIT_TIMEOUT)
			{
				if(_pressed_sign < 0) Gamepad.emit_key_event(negative_key, false);
				if(_pressed_sign > 0) Gamepad.emit_key_event(positive_key, false);
				timer.stop();
				_value = 0;
				_value_sign = 0;
				_pressed_sign = 0;
				_sign_changed = false;
				return;
			}

			if(!_sign_changed) return;

			if(_value_sign < 0)
			{
				Gamepad.emit_key_event(positive_key, false);
				Gamepad.emit_key_event(negative_key, true);
				_pressed_sign = -1;
			}
			else if(_value_sign > 0)
			{
				Gamepad.emit_key_event(negative_key, false);
				Gamepad.emit_key_event(positive_key, true);
				_pressed_sign = 1;
			}
			else
			{
				if(_pressed_sign < 0) Gamepad.emit_key_event(negative_key, false);
				if(_pressed_sign > 0) Gamepad.emit_key_event(positive_key, false);
				_pressed_sign = 0;
			}

			_sign_changed = false;
			timer.start();
		}

		public void reset()
		{
			value = 0;
			emit_key_event();
		}
	}

	public static void reset()
	{
		foreach(var button in Gamepad.Buttons.values)
		{
			button.reset();
		}
		foreach(var axis in Gamepad.Axes.values)
		{
			axis.reset();
		}
	}

	// hack, but works (on X11)
	private static void emit_key_event(uint key_code, bool press)
	{
		if(key_code == 0) return;
		foreach(var wnd in Gtk.Window.list_toplevels())
		{
			if(wnd.is_active)
			{
				unowned X.Display xdisplay = (wnd.screen.get_display() as Gdk.X11.Display).get_xdisplay();
				XTest.fake_key_event(xdisplay, xdisplay.keysym_to_keycode((ulong) key_code), press, X.CURRENT_TIME);
				break;
			}
		}
	}
}
