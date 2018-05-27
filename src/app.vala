using Gtk;
using Gdk;
using Granite;

using GameHub.Data;
using GameHub.Data.Sources.Steam;
using GameHub.Data.Sources.GOG;
using GameHub.Utils;

[CCode(cname="GETTEXT_PACKAGE")] extern const string GETTEXT_PACKAGE;

namespace GameHub
{
	public class Application: Granite.Application
	{
		construct
		{
			application_id = "com.github.tkashkin.gamehub";
			flags = ApplicationFlags.FLAGS_NONE;
			program_name = "GameHub";
		}

		protected override void activate()
		{
			weak IconTheme default_theme = IconTheme.get_default();
			default_theme.add_resource_path("/com/github/tkashkin/gamehub/icons");
			
			var provider = new CssProvider();
			provider.load_from_resource("/com/github/tkashkin/gamehub/GameHub.css");
			StyleContext.add_provider_for_screen(Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
			
			new GameHub.UI.Windows.MainWindow(this).show_all();
		}

		public static int main(string[] args)
		{
			//Ivy.Stacktrace.register_handlers();
			
			Intl.setlocale(LocaleCategory.ALL, "");
			Intl.textdomain(GETTEXT_PACKAGE);
			
			FSUtils.make_dirs();
			
			GameSources = { new Steam(), new GOG() };
			
			var app = new Application();
			return app.run(args);
		}
	}
}
