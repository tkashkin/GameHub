using Gtk;
using Gdk;
using Granite;

using GameHub.Data;
using GameHub.Data.DB;

namespace GameHub.UI.Widgets
{
	public class CompatToolPicker: Box
	{
		public CompatTool? selected { get; private set; default = null; }

		public Game game { get; construct; }
		public bool install_mode { get; construct; }

		private Gtk.ListStore model;
		private Gtk.TreeIter iter;
		private ComboBox combo;

		private Box actions;

		public CompatToolPicker(Game game, bool install_mode)
		{
			Object(orientation: Orientation.VERTICAL, spacing: 4, game: game, install_mode: install_mode);
		}

		construct
		{
			margin_bottom = 3;

			var label = new Label(_("Compatibility tool:"));
			label.hexpand = true;
			label.xalign = 0;
			label.margin_start = label.margin_end = 4;

			model = new Gtk.ListStore(3, typeof(string), typeof(string), typeof(CompatTool));

			foreach(var tool in CompatTools)
			{
				if(tool.installed && ((install_mode && tool.can_install(game)) || (!install_mode && tool.can_run(game))))
				{
					model.append(out iter);
					model.set(iter, 0, tool.icon);
					model.set(iter, 1, tool.name);
					model.set(iter, 2, tool);
				}
			}

			combo = new ComboBox.with_model(model);
			combo.halign = Align.END;

			CellRendererPixbuf r_icon = new CellRendererPixbuf();
			combo.pack_start(r_icon, false);
			combo.add_attribute(r_icon, "icon-name", 0);

			CellRendererText r_name = new CellRendererText();
			r_name.xpad = 8;
			combo.pack_start(r_name, true);
			combo.add_attribute(r_name, "text", 1);

			var tool_box = new Box(Orientation.HORIZONTAL, 8);

			tool_box.add(label);
			tool_box.add(combo);

			actions = new Box(Orientation.HORIZONTAL, 4);

			combo.changed.connect(() => {
				Value v;
				combo.get_active_iter(out iter);
				model.get_value(iter, 2, out v);
				selected = v as CompatTool;
				combo.tooltip_text = selected != null ? selected.executable.get_path() : null;

				if(selected.can_run(game))
				{
					game.compat_tool = selected.id;
					Tables.Games.add(game);
				}

				actions.foreach(w => w.destroy());

				if(selected.actions != null)
				{
					foreach(var action in selected.actions)
					{
						add_action(action);
					}
				}

				actions.show_all();
			});

			int index = 0;

			if(game.compat_tool != null && game.compat_tool.length > 0)
			{
				model.foreach((m, p, i) => {
					Value v;
					m.get_value(i, 2, out v);
					var tool = v as CompatTool;
					if(game.compat_tool == tool.id)
					{
						return true;
					}
					index++;
					return false;
				});
			}

			combo.active = index;

			add(tool_box);
			add(actions);

			show_all();
		}

		private void add_action(CompatTool.Action action)
		{
			var btn = new Button.with_label(action.name);
			btn.tooltip_text = action.description;
			btn.hexpand = true;
			btn.clicked.connect(() => action.invoke(game));
			actions.add(btn);
		}
	}
}
