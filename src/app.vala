using Gtk;
using Gdk;
using Granite;

using GameHub.Data;
using GameHub.Data.Sources.Steam;
using GameHub.Data.Sources.GOG;
using GameHub.Data.Sources.Humble;
using GameHub.Utils;

namespace GameHub
{
	public class Application: Granite.Application
	{
		construct
		{
			application_id = ProjectConfig.PROJECT_NAME;
			flags = ApplicationFlags.FLAGS_NONE;
			program_name = "GameHub";
			build_version = ProjectConfig.VERSION;
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
			#if USE_IVY
			Ivy.Stacktrace.register_handlers();
			#endif
			
			Intl.setlocale(LocaleCategory.ALL, "");
			Intl.bindtextdomain(ProjectConfig.GETTEXT_PACKAGE, ProjectConfig.DATADIR + "/locale");
			Intl.bind_textdomain_codeset(ProjectConfig.GETTEXT_PACKAGE, "UTF-8");
			Intl.textdomain(ProjectConfig.GETTEXT_PACKAGE);
			
			FSUtils.make_dirs();
			
			GamesDB.init();
			
			GameSources = { new Steam(), new GOG(), new Humble() };
			
			var app = new Application();
			return app.run(args);
		}
	}
}
