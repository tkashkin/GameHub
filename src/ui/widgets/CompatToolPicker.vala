using Gtk;
using Gdk;
using Granite;

using GameHub.Data;

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

		public CompatToolPicker(Game game, bool install_mode)
		{
			Object(orientation: Orientation.HORIZONTAL, spacing: 8, game: game, install_mode: install_mode);
		}

		construct
		{
			margin_top = margin_bottom = 4;

			var label = new Label(_("Compatibility tool:"));
			label.hexpand = true;
			label.xalign = 0;

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

			combo.changed.connect(() => {
				Value v;
				combo.get_active_iter(out iter);
				model.get_value(iter, 2, out v);
				selected = v as CompatTool;
				combo.tooltip_text = selected != null ? selected.executable.get_path() : null;
			});

			combo.active = 0;

			CellRendererPixbuf r_icon = new CellRendererPixbuf();
			combo.pack_start(r_icon, false);
			combo.add_attribute(r_icon, "icon-name", 0);

			CellRendererText r_name = new CellRendererText();
			r_name.xpad = 8;
			combo.pack_start(r_name, true);
			combo.add_attribute(r_name, "text", 1);

			add(label);
			add(combo);

			show_all();
		}
	}
}
