using Gtk;
using GLib;
using WebKit;
using GameHub.Utils;

namespace GameHub.UI.Windows
{
	public class WebAuthWindow: Window
	{
		private WebView webview;

        private bool is_finished = false;

        public signal void finished(string url);
        public signal void canceled();

        public WebAuthWindow(string source, string url, string success_url_prefix)
        {
            title = source;
            var titlebar = new HeaderBar();
			titlebar.title = title;
			titlebar.show_close_button = true;
			set_titlebar(titlebar);
			
            set_size_request(640, 800);
			
			set_modal(true);
			
            webview = new WebView();
            
            var cookies = FSUtils.expand(FSUtils.Paths.Cache.Cookies);
            webview.web_context.get_cookie_manager().set_persistent_storage(cookies, CookiePersistentStorage.TEXT);
            
            webview.get_settings().enable_mediasource = true;
            webview.get_settings().enable_smooth_scrolling = true;

            webview.load_changed.connect(e => {
				var uri = webview.get_uri();
				titlebar.title = webview.title;
				titlebar.subtitle = uri.split("?")[0];
				
				if(uri.has_prefix(success_url_prefix))
				{
					is_finished = true;
					finished(uri.substring(success_url_prefix.length));
					destroy();
				}
            });

            webview.load_uri(url);
            
            add(webview);

            destroy.connect(() => { if(!is_finished) canceled(); });
        }
	}
}
