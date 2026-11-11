using Gtk;
using WebKit;


[CCode (cname = "webkit_user_content_manager_register_script_message_handler")]
extern static bool webkit_ucm_register_handler (WebKit.UserContentManager manager, string name, string? world_name);

public class LumiWebWindow : Gtk.ApplicationWindow {
    private Gtk.Entry url_entry;
    private Gtk.ProgressBar progress_bar;
    private Gtk.Revealer? find_bar = null;
    private Gtk.Entry? find_entry = null;
    private Gtk.Stack main_stack;
    private Gtk.Box tab_list_box;
    private WebKit.WebView home_screen;
    private WebKit.UserContentFilterStore filter_store;
    private bool private_mode = false;
    private GLib.List<string> closed_tabs = new GLib.List<string> ();
    private Gtk.Button bookmark_btn;
    private Gtk.Window? bookmarks_win = null;
    private GLib.HashTable<string, bool>? shown_notifs = null;
    private double last_click_x = 0;
    private double last_click_y = 0;
    private Gtk.Window? downloads_win = null;
    private Gtk.Window? workspaces_win = null;
    private Gtk.Paned? split_paned = null;
    private WebKit.WebView? split_left_view = null;
    private WebKit.WebView? split_right_view = null;
    private bool split_horizontal = true;
    private GLib.HashTable<WebKit.WebView, Gtk.Button> audio_tabs;
    private CssProvider css_provider;
    private GLib.FileMonitor theme_monitor;
    private WebKit.NetworkSession network_session;
    
    private Gtk.Revealer menu_revealer;
    private WebKit.WebView menu_webview;

    private Gtk.Button current_active_tab = null;

    public LumiWebWindow (Gtk.Application app) {
        Object (application: app, title: "LumiWeb", default_width: 1100, default_height: 750);
        this.decorated = false;

        LumiWebCore.lw_init ();
        this.shown_notifs = new GLib.HashTable<string, bool> (str_hash, str_equal);
        this.audio_tabs = new GLib.HashTable<WebKit.WebView, Gtk.Button> (null, null);

        // PERSYSTENTNA SESJA
        this.network_session = WebKit.NetworkSession.get_default ();
        var cookie_manager = this.network_session.get_cookie_manager ();
        string cookie_path = GLib.Environment.get_user_config_dir () + "/lumiweb/cookies.sqlite";
        cookie_manager.set_persistent_storage (cookie_path, WebKit.CookiePersistentStorage.SQLITE);
var overlay = new Gtk.Overlay ();
        var root_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        root_box.add_css_class ("main-window-bg");
        overlay.set_child (root_box);
        this.set_child (overlay);

        // --- BELKA TYTUŁOWA ---
        var window_handle = new Gtk.WindowHandle ();
        var titlebar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        titlebar.add_css_class ("custom-titlebar");
        titlebar.set_size_request (-1, 38);
        
        var controls_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        controls_box.set_margin_start (16);
        controls_box.set_valign (Gtk.Align.CENTER);

        var close_btn = create_mac_button ("mac-close", "window-close-symbolic");
        close_btn.clicked.connect (() => { this.close (); });
        var min_btn = create_mac_button ("mac-min", "window-minimize-symbolic");
        min_btn.clicked.connect (() => { this.minimize (); });
        var max_btn = create_mac_button ("mac-max", "window-maximize-symbolic");
        max_btn.clicked.connect (() => { if (this.is_maximized ()) this.unmaximize (); else this.maximize (); });

        controls_box.append (close_btn);
        controls_box.append (min_btn);
        controls_box.append (max_btn);
        titlebar.append (controls_box);

        this.url_entry = new Gtk.Entry ();
        this.url_entry.set_placeholder_text ("Szukaj lub wpisz adres...");
        this.url_entry.set_hexpand (true);
        this.url_entry.add_css_class ("top-url-bar");
        this.url_entry.activate.connect (() => { 
            if (this.main_stack.get_visible_child () == this.home_screen) {
                stworz_nowa_karte (this.url_entry.get_text ());
            } else {
                var current_webview = (WebKit.WebView) this.main_stack.get_visible_child ();
                zaladuj_w_webview (current_webview, this.url_entry.get_text ());
            }
        });
        var url_container = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        url_container.set_hexpand(true);
        url_container.set_margin_start(16);
        url_container.set_margin_end(16);
        url_container.set_valign(Gtk.Align.CENTER);
        url_container.append(this.url_entry);
        this.bookmark_btn = new Gtk.Button.from_icon_name ("non-starred-symbolic");
        this.bookmark_btn.add_css_class ("nav-btn");
        this.bookmark_btn.set_tooltip_text ("Zakładka (Ctrl+D)");
        this.bookmark_btn.set_valign (Gtk.Align.CENTER);
        this.bookmark_btn.clicked.connect (() => { this.toggle_bookmark (); });
        url_container.append (this.bookmark_btn);
        titlebar.append (url_container);
        
        // --- PRZYCISKI NAWIGACJI (PRAWA STRONA) ---
        var nav_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
        nav_box.set_margin_end (12);
        nav_box.set_valign (Gtk.Align.CENTER);
        
        var back_btn = new Gtk.Button.from_icon_name ("go-previous-symbolic");
        back_btn.add_css_class ("nav-btn");
        back_btn.set_tooltip_text ("Wstecz");
        back_btn.clicked.connect (() => {
            if (this.main_stack.get_visible_child () is WebKit.WebView) {
                ((WebKit.WebView) this.main_stack.get_visible_child ()).go_back ();
            }
        });
        
        var forward_btn = new Gtk.Button.from_icon_name ("go-next-symbolic");
        forward_btn.add_css_class ("nav-btn");
        forward_btn.set_tooltip_text ("Dalej");
        forward_btn.clicked.connect (() => {
            if (this.main_stack.get_visible_child () is WebKit.WebView) {
                ((WebKit.WebView) this.main_stack.get_visible_child ()).go_forward ();
            }
        });
        
        var reload_btn = new Gtk.Button.from_icon_name ("view-refresh-symbolic");
        reload_btn.add_css_class ("nav-btn");
        reload_btn.set_tooltip_text ("Odśwież");
        reload_btn.clicked.connect (() => {
            if (this.main_stack.get_visible_child () is WebKit.WebView) {
                ((WebKit.WebView) this.main_stack.get_visible_child ()).reload ();
            }
        });
        
        var home_btn = new Gtk.Button.from_icon_name ("go-home-symbolic");
        home_btn.add_css_class ("nav-btn");
        home_btn.set_tooltip_text ("Strona główna");
        home_btn.clicked.connect (() => {
            this.main_stack.set_visible_child (this.home_screen);
            this.url_entry.set_text ("");
        });
        
        nav_box.append (back_btn);
        nav_box.append (forward_btn);
        nav_box.append (reload_btn);
        nav_box.append (home_btn);
        titlebar.append (nav_box);
        
        window_handle.set_child (titlebar);
        root_box.append (window_handle);
        
        // Progress bar pod paskiem URL
        this.progress_bar = new Gtk.ProgressBar ();
        this.progress_bar.set_show_text (false);
        this.progress_bar.set_valign (Gtk.Align.START);
        this.progress_bar.set_margin_top (0);
        this.progress_bar.add_css_class ("url-progress");
        this.progress_bar.set_visible (false);
        root_box.append (this.progress_bar);

        // --- GŁÓWNY KONTENER ---
        var content_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        content_box.set_vexpand (true);
        root_box.append (content_box);

        var sidebar = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        sidebar.add_css_class ("sidebar");
        sidebar.set_size_request (48, -1);
        
        this.tab_list_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
        this.tab_list_box.set_margin_top (8);
        this.tab_list_box.set_halign (Gtk.Align.CENTER);
        
        var new_tab_btn = new Gtk.Button.from_icon_name ("tab-new-symbolic");
        new_tab_btn.add_css_class ("sidebar-icon-btn");
        new_tab_btn.set_tooltip_text ("Nowa karta");
        new_tab_btn.clicked.connect(() => { 
            this.main_stack.set_visible_child (this.home_screen);
            this.url_entry.set_text ("");
            if (current_active_tab != null) current_active_tab.remove_css_class ("active-tab");
            current_active_tab = null;
        });
        this.tab_list_box.append (new_tab_btn);
        sidebar.append (this.tab_list_box);

        var bottom_icons = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
        bottom_icons.set_valign (Gtk.Align.END);
        bottom_icons.set_margin_bottom (12);
        bottom_icons.set_halign (Gtk.Align.CENTER);

        var dl_btn = new Gtk.Button.from_icon_name ("user-bookmarks-symbolic");
        dl_btn.add_css_class ("sidebar-icon-btn");
        dl_btn.set_tooltip_text ("Zakładki");
        dl_btn.clicked.connect (() => {
            if (this.bookmarks_win == null) this.bookmarks_win = new BookmarksWindow (this);
            else ((BookmarksWindow) this.bookmarks_win).refresh ();
            this.bookmarks_win.present ();
        });
        
        var settings_btn = new Gtk.Button.from_icon_name ("preferences-system-symbolic");
        settings_btn.add_css_class ("sidebar-icon-btn");
        settings_btn.clicked.connect (() => {
            try { Process.spawn_command_line_async (this.get_settings_binary ()); } 
            catch (Error e) { warning ("Błąd: %s", e.message); }
        });

        bottom_icons.append (dl_btn);
        bottom_icons.append (settings_btn);
        sidebar.append (bottom_icons);
        content_box.append (sidebar);

        this.main_stack = new Gtk.Stack ();
        this.main_stack.set_transition_type (Gtk.StackTransitionType.CROSSFADE);
        this.main_stack.set_hexpand (true);
        this.main_stack.set_vexpand (true);
        content_box.append (this.main_stack);

        // === NOWA STRONA GŁÓWNA: HTML + canvas galaktyka + prawdziwe szkło ===
        this.home_screen = new WebKit.WebView ();
        this.home_screen.set_hexpand (true);
        this.home_screen.set_vexpand (true);
        var home_bg = Gdk.RGBA ();
        home_bg.parse ("#05060f");
        this.home_screen.set_background_color (home_bg);
        
        webkit_ucm_register_handler (this.home_screen.get_user_content_manager (), "home", null);
        this.home_screen.get_user_content_manager ().script_message_received.connect ((value) => {
            string msg = value.to_string ();
            if (msg == null || msg == "") return;
            int sep = msg.index_of (":");
            if (sep <= 0) return;
            string val = msg.substring (sep + 1);
            if (val != "") stworz_nowa_karte (val);
        });
        
        string home_html_path = GLib.Environment.get_user_config_dir () + "/lumiweb/home.html";
        if (GLib.FileUtils.test (home_html_path, GLib.FileTest.EXISTS)) {
            this.home_screen.load_uri ("file://" + home_html_path);
        }
        
        this.main_stack.add_named (this.home_screen, "home");

        


        // --- MENU RADIALNE (ZABEZPIECZONE PRZED GBM) ---
        // Tworzymy sztywny kontener, aby Wayland nie próbował rozciągnąć menu na cały ekran
        var menu_wrapper = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        menu_wrapper.set_halign (Gtk.Align.END);
        menu_wrapper.set_valign (Gtk.Align.CENTER);
        menu_wrapper.set_size_request (400, 600);
        menu_wrapper.set_overflow (Gtk.Overflow.HIDDEN); // KLUCZ DO SUKCESU

        this.menu_revealer = new Gtk.Revealer ();
        this.menu_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_LEFT);
        this.menu_revealer.set_reveal_child (false);
        this.menu_revealer.set_hexpand (false);
        this.menu_revealer.set_vexpand (false);
this.menu_webview = new WebKit.WebView ();
        this.menu_webview.set_hexpand (false);
        this.menu_webview.set_vexpand (false);
        this.menu_webview.set_size_request (400, 600);
        this.menu_webview.set_background_color (Gdk.RGBA () { red = 0.0f, green = 0.0f, blue = 0.0f, alpha = 0.0f });
        
        webkit_ucm_register_handler (this.menu_webview.get_user_content_manager (), "menuAction", null);
        this.menu_webview.get_user_content_manager ().script_message_received.connect ((js_value) => {
            string action = js_value.to_string ();
            obsluz_akcje_menu (action);
        });

        this.menu_webview.load_html (POBierz_HTML_MENU (), "file:///");
        this.menu_revealer.set_child (this.menu_webview);
        menu_wrapper.append (this.menu_revealer);
        menu_wrapper.set_can_target (false);
        this.menu_revealer.notify["reveal-child"].connect (() => {
            menu_wrapper.set_can_target (this.menu_revealer.get_reveal_child ());
        });
        overlay.add_overlay (menu_wrapper);

        var open_menu_btn = new Gtk.Button.from_icon_name ("pan-start-symbolic");
        open_menu_btn.add_css_class ("edge-handle-btn");
        open_menu_btn.set_halign (Gtk.Align.END);
        open_menu_btn.set_valign (Gtk.Align.CENTER);
        open_menu_btn.clicked.connect (() => {
            this.menu_revealer.set_reveal_child (!this.menu_revealer.get_reveal_child ());
        });
        overlay.add_overlay (open_menu_btn);

        // --- ŁADOWANIE MOTYWU CSS ---
        this.css_provider = new CssProvider ();
        Gtk.StyleContext.add_provider_for_display (Gdk.Display.get_default (), css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        zaladuj_motyw ();

        string css_path = GLib.Environment.get_user_config_dir () + "/lumiweb/theme.css";
        var file = GLib.File.new_for_path (css_path);
        try {
            this.theme_monitor = file.monitor_file (GLib.FileMonitorFlags.NONE, null);
            this.theme_monitor.changed.connect (() => {
                GLib.Timeout.add (100, () => { zaladuj_motyw (); return false; });
            });
        } catch (Error e) { warning ("Błąd monitorowania: %s", e.message); }

        // Ctrl+W - zamknij aktywną kartę (przez Gtk.ShortcutController)
        var shortcut_ctrl = new Gtk.ShortcutController ();
        var ctrl_trigger = Gtk.ShortcutTrigger.parse_string ("<Control>w");
        var ctrl_action = new Gtk.CallbackAction ((w, args) => {
            if (this.current_active_tab != null && this.main_stack.get_visible_child () is WebKit.WebView) {
                var wv = (WebKit.WebView) this.main_stack.get_visible_child ();
                this.main_stack.remove (wv);
                this.tab_list_box.remove (this.current_active_tab);
                this.audio_tabs.remove (wv);
                this.main_stack.set_visible_child (this.home_screen);
                this.url_entry.set_text ("");
                this.current_active_tab = null;
            }
            return true;
        });
        var shortcut = new Gtk.Shortcut (ctrl_trigger, ctrl_action);
        shortcut_ctrl.add_shortcut (shortcut);
        ((Gtk.Widget) this).add_controller (shortcut_ctrl);
    }

    private void obsluz_akcje_menu (string action) {
        if (action == "home") {
            this.main_stack.set_visible_child (this.home_screen);
            this.url_entry.set_text ("");
        } else if (action == "history") {
            var webview = this.stworz_nowa_karte ("");
            unowned string html = LumiWebCore.lw_get_history_html ();
            webview.load_html (html, "file:///");
            LumiWebCore.lw_free_string (html);
        } else if (action == "zoom_in") {
            if (this.main_stack.get_visible_child () is WebKit.WebView) {
                var wv = (WebKit.WebView) this.main_stack.get_visible_child ();
                wv.set_zoom_level (wv.get_zoom_level () + 0.1);
            }
        } else if (action == "zoom_out") {
            if (this.main_stack.get_visible_child () is WebKit.WebView) {
                var wv = (WebKit.WebView) this.main_stack.get_visible_child ();
                wv.set_zoom_level (wv.get_zoom_level () - 0.1);
            }
        } else if (action == "devtools") {
            if (this.main_stack.get_visible_child () is WebKit.WebView) {
                ((WebKit.WebView) this.main_stack.get_visible_child ()).get_inspector ().show ();
            }
        } else if (action == "settings") {
            try { Process.spawn_command_line_async (this.get_settings_binary ()); } 
            catch (Error e) { warning ("Błąd: %s", e.message); }
        } else if (action == "calendar") {
            var win = new CalendarWindow (this);
            win.present ();
        } else if (action == "todo") {
            var win = new TodoWindow (this);
            win.present ();
        } else if (action == "notes") {
            var win = new NotesWindow (this);
            win.present ();
        } else if (action == "audio") {
            var win = new AudioWindow (this, this.audio_tabs);
            win.present ();

        }
    }

    private string POBierz_HTML_MENU () {
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <style>
            body {
                margin: 0; padding: 0; overflow: hidden;
                background: transparent;
                font-family: sans-serif;
                display: flex; align-items: center; justify-content: flex-end;
                width: 100%; height: 100%;
            }
            .wheel-container {
                position: relative;
                width: 400px; height: 400px;
                right: -180px;
                display: flex; align-items: center; justify-content: center;
            }
            .circle-bg {
                position: absolute;
                width: 360px; height: 360px;
                border-radius: 50%;
                border: 2px dashed rgba(255, 255, 255, 0.15);
                box-shadow: 0 0 30px rgba(74, 144, 226, 0.2) inset;
            }
            .circle-inner {
                position: absolute;
                width: 260px; height: 260px;
                border-radius: 50%;
                border: 1px solid rgba(255, 255, 255, 0.05);
            }
            .item {
                position: absolute;
                width: 45px; height: 45px;
                background: rgba(30, 30, 40, 0.8);
                border-radius: 12px;
                display: flex; align-items: center; justify-content: center;
                cursor: pointer;
                transition: all 0.3s;
                color: #aaa;
                border: 1px solid rgba(255,255,255,0.1);
            }
            .item:hover {
                background: #4a90e2;
                color: white;
                box-shadow: 0 0 20px #4a90e2;
                transform: scale(1.1);
            }
            
            /* Ułożenie w półkolu (7 elementów) */
            .item:nth-child(1) { transform: translate(-50px, -180px); } /* Góra */
            .item:nth-child(2) { transform: translate(-130px, -150px); } /* Góra-lewo */
            .item:nth-child(3) { transform: translate(-180px, -80px); }  /* Środek-góra */
            .item:nth-child(4) { transform: translate(-200px, 0px); }    /* Środek */
            .item:nth-child(5) { transform: translate(-180px, 80px); }   /* Środek-dół */
            .item:nth-child(6) { transform: translate(-130px, 150px); }  /* Dół-lewo */
            .item:nth-child(7) { transform: translate(-50px, 180px); }   /* Dół */

            svg { width: 20px; height: 20px; fill: currentColor; }
        </style>
        </head>
        <body>
            <div class="wheel-container">
                <div class="circle-bg"></div>
                <div class="circle-inner"></div>
                
                <div class="item" onclick="sendAction('home')" title="Strona główna">
                    <svg viewBox="0 0 24 24"><path d="M12 3L2 12h3v8h6v-6h2v6h6v-8h3L12 3z"/></svg>
                </div>
                <div class="item" onclick="sendAction('calendar')" title="Kalendarz">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                        <rect x="3" y="5" width="18" height="16" rx="2"/>
                        <line x1="16" y1="3" x2="16" y2="7"/>
                        <line x1="8" y1="3" x2="8" y2="7"/>
                        <line x1="3" y1="11" x2="21" y2="11"/>
                        <circle cx="8" cy="15" r="1"/><circle cx="12" cy="15" r="1"/><circle cx="16" cy="15" r="1"/>
                    </svg>
                </div>
                <div class="item" onclick="sendAction('todo')" title="Zadania">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                        <path d="M9 11l3 3L22 4"/>
                        <path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/>
                    </svg>
                </div>
                <div class="item" onclick="sendAction('notes')" title="Notatki">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                        <path d="M12 20h9"/>
                        <path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z"/>
                    </svg>
                </div>
                <div class="item" onclick="sendAction('history')" title="Historia">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                        <circle cx="12" cy="12" r="9"/>
                        <path d="M12 7v5l3 2"/>
                    </svg>
                </div>
                <div class="item" onclick="sendAction('zoom_in')" title="Powiększ">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
                        <circle cx="11" cy="11" r="7"/>
                        <line x1="21" y1="21" x2="16.65" y2="16.65"/>
                        <line x1="8" y1="11" x2="14" y2="11"/>
                        <line x1="11" y1="8" x2="11" y2="14"/>
                    </svg>
                </div>
                <div class="item" onclick="sendAction('zoom_out')" title="Pomniejsz">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
                        <circle cx="11" cy="11" r="7"/>
                        <line x1="21" y1="21" x2="16.65" y2="16.65"/>
                        <line x1="8" y1="11" x2="14" y2="11"/>
                    </svg>
                </div>
                <div class="item" onclick="sendAction('devtools')" title="DevTools">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <polyline points="16 18 22 12 16 6"/>
                        <polyline points="8 6 2 12 8 18"/>
                    </svg>
                </div>
                <div class="item" onclick="sendAction('audio')" title="Dźwięk">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                        <polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5" fill="currentColor"/>
                        <path d="M15.54 8.46a5 5 0 0 1 0 7.07"/>
                        <path d="M19.07 4.93a10 10 0 0 1 0 14.14"/>
                    </svg>
                </div>
                <div class="item" onclick="sendAction('split_h')" title="Split pionowy">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                        <rect x="3" y="4" width="18" height="16" rx="2"/>
                        <line x1="12" y1="4" x2="12" y2="20"/>
                    </svg>
                </div>
                <div class="item" onclick="sendAction('split_v')" title="Split poziomy">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                        <rect x="3" y="4" width="18" height="16" rx="2"/>
                        <line x1="3" y1="12" x2="21" y2="12"/>
                    </svg>
                </div>
                <div class="item" onclick="sendAction('workspaces')" title="Przestrzenie">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                        <rect x="3" y="3" width="8" height="8" rx="1.5"/>
                        <rect x="13" y="3" width="8" height="8" rx="1.5"/>
                        <rect x="3" y="13" width="8" height="8" rx="1.5"/>
                        <rect x="13" y="13" width="8" height="8" rx="1.5"/>
                    </svg>
                </div>
                <div class="item" onclick="sendAction('downloads')" title="Pobierane">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                        <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
                        <polyline points="7 10 12 15 17 10"/>
                        <line x1="12" y1="15" x2="12" y2="3"/>
                    </svg>
                </div>
                <div class="item" onclick="sendAction('settings')" title="Ustawienia">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                        <circle cx="12" cy="12" r="3"/>
                        <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>
                    </svg>
                </div>
            </div>
            <script>
                function sendAction(action) {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.menuAction) {
                        window.webkit.messageHandlers.menuAction.postMessage(action);
                    }
                }
            </script>
        </body>
        </html>
        """;
    }

    private void zaladuj_mody_i_pluginy_do_ucm (WebKit.UserContentManager ucm) {
        string config_dir = GLib.Environment.get_user_config_dir () + "/lumiweb";
        
        string mods_dir = config_dir + "/mods";
        try {
            var dir = Dir.open (mods_dir, 0);
            string? name;
            while ((name = dir.read_name ()) != null) {
                if (name.has_suffix (".css")) {
                    string path = Path.build_filename (mods_dir, name);
                    string css = "";
                    FileUtils.get_contents (path, out css);
                    ucm.add_style_sheet (new UserStyleSheet (css, UserContentInjectedFrames.ALL_FRAMES, UserStyleLevel.USER, null, null));
                }
            }
        } catch (FileError e) { }

        string plugins_dir = config_dir + "/plugins";

        // JS pluginy (legacy)
        try {
            var dir = Dir.open (plugins_dir, 0);
            string? name;
            while ((name = dir.read_name ()) != null) {
                if (name.has_suffix (".js")) {
                    string path = Path.build_filename (plugins_dir, name);
                    string js = "";
                    FileUtils.get_contents (path, out js);
                    ucm.add_script (new UserScript (js, UserContentInjectedFrames.ALL_FRAMES, UserScriptInjectionTime.END, null, null));
                }
            }
        } catch (FileError e) { }

        // LUA pluginy (nowe)
        try {
            var dir = Dir.open (plugins_dir, 0);
            string? name;
            while ((name = dir.read_name ()) != null) {
                if (name.has_suffix (".lua")) {
                    string path = Path.build_filename (plugins_dir, name);
                    string cur_url = "";
                    if (this.main_stack.get_visible_child () is WebKit.WebView) {
                        cur_url = ((WebKit.WebView) this.main_stack.get_visible_child ()).get_uri () ?? "";
                    }

                    unowned string css_code = LumiWebCore.lw_plugin_css (path, cur_url);
                    if (css_code != null && css_code.length > 0) {
                        ucm.add_style_sheet (new UserStyleSheet (css_code, UserContentInjectedFrames.ALL_FRAMES, UserStyleLevel.USER, null, null));
                        LumiWebCore.lw_free_string (css_code);
                    }

                    unowned string js_code = LumiWebCore.lw_plugin_js (path, cur_url);
                    if (js_code != null && js_code.length > 0) {
                        ucm.add_script (new UserScript (js_code, UserContentInjectedFrames.ALL_FRAMES, UserScriptInjectionTime.END, null, null));
                        LumiWebCore.lw_free_string (js_code);
                    }
                    
                    this.check_lua_notifications (path, cur_url);
                }
            }
        } catch (FileError e) { }
    }

    private void zaladuj_motyw () {
        string css_path = GLib.Environment.get_user_config_dir () + "/lumiweb/theme.css";
        if (FileUtils.test (css_path, FileTest.EXISTS)) {
            try { this.css_provider.load_from_path (css_path); } catch (Error e) {}
        }
    }

    private Gtk.Button create_mac_button (string css_class, string icon_name) {
        var btn = new Gtk.Button ();
        btn.add_css_class (css_class);
        var img = new Gtk.Image.from_icon_name (icon_name);
        btn.set_child (img);
        return btn;
    }

    
    
    private void fetch_favicon_http (string page_uri, Gtk.Button tab_btn) {
        if (!page_uri.has_prefix ("http")) return;
        try {
            var uri = GLib.Uri.parse (page_uri, GLib.UriFlags.NONE);
            if (uri == null) return;
            string favicon_url = uri.get_scheme () + "://" + uri.get_host () + "/favicon.ico";
            GLib.stderr.puts ("[FAV] Trying: " + favicon_url + "\n");

            new Thread<void*> ("favicon-fetch", () => {
                try {
                    var file = GLib.File.new_for_uri (favicon_url);
                    uint8[] contents;
                    string? etag;
                    file.load_contents (null, out contents, out etag);
                    if (contents.length > 0) {
                        var bytes = new GLib.Bytes (contents);
                        var texture = Gdk.Texture.from_bytes (bytes);
                        Idle.add (() => {
                            var img = new Gtk.Image.from_paintable (texture);
                            img.set_pixel_size (16);
                            tab_btn.set_child (img);
                            GLib.stderr.puts ("[FAV] ✅ OK: " + favicon_url + "\n");
                            return false;
                        });
                    }
                } catch (Error e) {
                    GLib.stderr.puts ("[FAV] ❌ " + favicon_url + " → " + e.message + "\n");
                }
                return null;
            });
        } catch (Error e) {
            GLib.stderr.puts ("[FAV] Parse error: " + e.message + "\n");
        }
    }


    public void open_url (string url) {
        if (url == null || url == "") return;
        if (url.has_prefix ("file://") || url.has_prefix ("http://") || url.has_prefix ("https://")) {
            stworz_nowa_karte (url);
        } else {
            // Zgadnij - może to być lokalna ścieżka
            var f = GLib.File.new_for_path (url);
            if (f.query_exists ()) {
                stworz_nowa_karte (f.get_uri ());
            } else {
                stworz_nowa_karte (url);
            }
        }
    }

    private WebKit.WebView stworz_nowa_karte (string url) {
        var webview = new WebKit.WebView ();
        webview.set_hexpand (true);
        webview.set_vexpand (true);
        webview.get_settings ().set_enable_developer_extras (true);
        webview.get_settings ().set_user_agent ("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15 LumiWeb/1.0");

        var ucm = webview.get_user_content_manager ();
        string adguard_path = GLib.Environment.get_user_config_dir () + "/lumiweb/youtube_adguard.js";
        if (GLib.FileUtils.test (adguard_path, GLib.FileTest.EXISTS)) {
            try {
                string js = "";
                FileUtils.get_contents (adguard_path, out js);
                var script = new WebKit.UserScript (js,
                    WebKit.UserContentInjectedFrames.TOP_FRAME,
                    WebKit.UserScriptInjectionTime.END,
                    null, null);
                ucm.add_script (script);
                print ("[AdBlock] Skrypt AdGuard YouTube wstrzykniety.\n");
            } catch (Error e) {
                warning ("Blad wczytywania skryptu AdGuard: %s", e.message);
            }
        }
        zaladuj_mody_i_pluginy_do_ucm (ucm);

        var tab_btn = new Gtk.Button ();
        tab_btn.add_css_class ("sidebar-icon-btn");
        
        var default_icon = new Gtk.Image.from_icon_name ("globe-symbolic");
        default_icon.set_pixel_size (16); 
        tab_btn.set_child (default_icon);

        // Pobieranie favicon przez HTTP /favicon.ico
        webview.notify["estimated-load-progress"].connect (() => {
            if (this.main_stack.get_visible_child () == webview) {
                double p = webview.get_estimated_load_progress ();
                this.progress_bar.set_fraction (p);
                this.progress_bar.set_visible (p > 0.0 && p < 1.0);
            }
        });
        
        webview.load_changed.connect ((ev) => {
            if (this.main_stack.get_visible_child () == webview) {
                if (ev == WebKit.LoadEvent.STARTED) {
                    this.progress_bar.set_fraction (0.0);
                    this.progress_bar.set_visible (true);
                } else if (ev == WebKit.LoadEvent.FINISHED) {
                    this.progress_bar.set_fraction (1.0);
                    GLib.Timeout.add (300, () => { this.progress_bar.set_visible (false); return false; });
                }
            }
            if (ev == WebKit.LoadEvent.FINISHED) {
                string cur_uri = webview.get_uri () ?? "";
                if (cur_uri != "") {
                    GLib.Timeout.add (500, () => {
                        fetch_favicon_http (cur_uri, tab_btn);
                        return false;
                    });
                }
            }
        });

        // Context menu (prawy klik)


        // === WEBSITE PERMISSIONS (mikrofon, kamera, geolokalizacja) ===
        webview.permission_request.connect ((req) => {
            string origin = "";
            try {
                var u = GLib.Uri.parse (webview.get_uri () ?? "", GLib.UriFlags.NONE);
                if (u != null) origin = u.get_scheme () + "://" + u.get_host ();
            } catch (Error e) {}
            string kind = "";
            if (req is WebKit.UserMediaPermissionRequest) kind = "kamera/mikrofon";
            else if (req is WebKit.GeolocationPermissionRequest) kind = "geolokalizacja";
            else if (req is WebKit.NotificationPermissionRequest) kind = "powiadomienia";
            else {
                req.deny ();
                return false;
            }
            
            var dialog = new Gtk.MessageDialog (this, Gtk.DialogFlags.MODAL,
                Gtk.MessageType.QUESTION, Gtk.ButtonsType.NONE,
                "Strona %s prosi o dostęp do: %s", origin, kind);
            dialog.add_button ("Odmów", Gtk.ResponseType.NO);
            dialog.add_button ("Zezwól", Gtk.ResponseType.YES);
            dialog.response.connect ((resp) => {
                if (resp == Gtk.ResponseType.YES) req.allow ();
                else req.deny ();
                dialog.destroy ();
            });
            dialog.present ();
            return true;
        });
        
                // === CONTEXT MENU (prawy klik) ===
        webview.context_menu.connect ((menu, hit) => {
            double pop_x = this.last_click_x;
            double pop_y = this.last_click_y;
            
            var popover = new Gtk.Popover ();
            popover.set_has_arrow (false);
            popover.set_parent (webview);
            
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            box.add_css_class ("ctx-menu");
            
            // --- NAWIGACJA ---
            string cur_uri = webview.get_uri () ?? "";
            
            if (webview.can_go_back ()) {
                var b = new Gtk.Button.with_label ("← Wstecz");
                b.add_css_class ("ctx-btn");
                b.clicked.connect (() => { webview.go_back (); popover.popdown (); });
                box.append (b);
            }
            if (webview.can_go_forward ()) {
                var b = new Gtk.Button.with_label ("→ Dalej");
                b.add_css_class ("ctx-btn");
                b.clicked.connect (() => { webview.go_forward (); popover.popdown (); });
                box.append (b);
            }
            
            var reload_btn = new Gtk.Button.with_label ("↻ Odśwież");
            reload_btn.add_css_class ("ctx-btn");
            reload_btn.clicked.connect (() => { webview.reload (); popover.popdown (); });
            box.append (reload_btn);
            
            // --- KONTEKST LINKU ---
            if (hit.context_is_link ()) {
                string link_url = hit.get_link_uri () ?? "";
                var sep1 = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
                sep1.add_css_class ("ctx-sep");
                box.append (sep1);
                
                var b_new = new Gtk.Button.with_label ("Otwórz w nowej karcie");
                b_new.add_css_class ("ctx-btn");
                var lu1 = link_url;
                b_new.clicked.connect (() => {
                    popover.popdown ();
                    GLib.Idle.add (() => { this.stworz_nowa_karte (lu1); return false; });
                });
                box.append (b_new);
                
                var b_copy = new Gtk.Button.with_label ("Kopiuj adres linku");
                b_copy.add_css_class ("ctx-btn");
                var lu2 = link_url;
                b_copy.clicked.connect (() => {
                    var cb = Gdk.Display.get_default ().get_clipboard ();
                    cb.set_text (lu2);
                    popover.popdown ();
                });
                box.append (b_copy);
                
                var b_save = new Gtk.Button.with_label ("Zapisz link jako...");
                b_save.add_css_class ("ctx-btn");
                var lu3 = link_url;
                b_save.clicked.connect (() => {
                    popover.popdown ();
                    GLib.Idle.add (() => {
                        // Pobierz przez GLib.File (jak favicony) — najprościej
                        new Thread<void*> ("download", () => {
                            try {
                                var file = GLib.File.new_for_uri (lu3);
                                var dest = GLib.Environment.get_user_special_dir (GLib.UserDirectory.DOWNLOAD) ?? GLib.Environment.get_home_dir ();
                                string fname = GLib.Path.get_basename (lu3);
                                if (fname == "" || !fname.contains (".")) fname = "pobrane_" + GLib.Random.next_int ().to_string ();
                                string path = GLib.Path.build_filename (dest, fname);
                                file.copy (GLib.File.new_for_path (path), GLib.FileCopyFlags.OVERWRITE, null, null);
                                LumiWebCore.lw_download_log (lu3, path);
                                GLib.stderr.puts ("[Download] " + path + "\n");
                            } catch (Error e) {
                                GLib.stderr.puts ("[Download] ERR: " + e.message + "\n");
                            }
                            return null;
                        });
                        return false;
                    });
                });
                box.append (b_save);
            }
            
            // --- KONTEKST OBRAZU ---
            if (hit.context_is_image ()) {
                string img_url = hit.get_image_uri () ?? "";
                if (img_url != "") {
                    var sep2 = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
                    sep2.add_css_class ("ctx-sep");
                    box.append (sep2);
                    
                    var b_img_open = new Gtk.Button.with_label ("Otwórz obraz w nowej karcie");
                    b_img_open.add_css_class ("ctx-btn");
                    var iu1 = img_url;
                    b_img_open.clicked.connect (() => {
                        popover.popdown ();
                        GLib.Idle.add (() => { this.stworz_nowa_karte (iu1); return false; });
                    });
                    box.append (b_img_open);
                    
                    var b_img_copy = new Gtk.Button.with_label ("Kopiuj adres obrazu");
                    b_img_copy.add_css_class ("ctx-btn");
                    var iu2 = img_url;
                    b_img_copy.clicked.connect (() => {
                        var cb = Gdk.Display.get_default ().get_clipboard ();
                        cb.set_text (iu2);
                        popover.popdown ();
                    });
                    box.append (b_img_copy);
                    
                    var b_img_save = new Gtk.Button.with_label ("Zapisz obraz jako...");
                    b_img_save.add_css_class ("ctx-btn");
                    var iu3 = img_url;
                    b_img_save.clicked.connect (() => {
                        popover.popdown ();
                        try {
                            var dest = GLib.Environment.get_user_special_dir (GLib.UserDirectory.DOWNLOAD) ?? GLib.Environment.get_home_dir ();
                            string fname = GLib.Path.get_basename (iu3);
                            if (fname == "") fname = "obraz_" + GLib.Random.next_int ().to_string ();
                            string path = GLib.Path.build_filename (dest, fname);
                            var f = GLib.File.new_for_uri (iu3);
                            f.copy_async (GLib.File.new_for_path (path), 0, GLib.Priority.DEFAULT, null, null, null);
                            LumiWebCore.lw_download_log (iu3, path);
                        } catch (Error e) {}
                    });
                    box.append (b_img_save);
                }
            }
            
            // --- KONTEKST ZAZNACZENIA ---
            if (hit.context_is_selection ()) {
                var sep3 = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
                sep3.add_css_class ("ctx-sep");
                box.append (sep3);
                
                var b_copy_sel = new Gtk.Button.with_label ("Kopiuj zaznaczenie");
                b_copy_sel.add_css_class ("ctx-btn");
                b_copy_sel.clicked.connect (() => {
                    webview.execute_editing_command (WebKit.EDITING_COMMAND_COPY);
                    popover.popdown ();
                });
                box.append (b_copy_sel);
            }
            
            // --- ZAWSZE DOSTĘPNE ---
            var sep4 = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
            sep4.add_css_class ("ctx-sep");
            box.append (sep4);
            
            var b_copy_url = new Gtk.Button.with_label ("Kopiuj adres strony");
            b_copy_url.add_css_class ("ctx-btn");
            var cu = cur_uri;
            b_copy_url.clicked.connect (() => {
                var cb = Gdk.Display.get_default ().get_clipboard ();
                cb.set_text (cu);
                popover.popdown ();
            });
            box.append (b_copy_url);
            
            var b_save_page = new Gtk.Button.with_label ("Zapisz stronę jako...");
            b_save_page.add_css_class ("ctx-btn");
            var cu2 = cur_uri;
            b_save_page.clicked.connect (() => {
                popover.popdown ();
                try {
                    var dest = GLib.Environment.get_user_special_dir (GLib.UserDirectory.DOWNLOAD) ?? GLib.Environment.get_home_dir ();
                    string fname = "strona_" + GLib.Random.next_int ().to_string () + ".html";
                    string path = GLib.Path.build_filename (dest, fname);
                    webview.get_page_id ();
                    // Pobierz HTML przez JS
                    webview.evaluate_javascript.begin (
                        "document.documentElement.outerHTML",
                        -1, null, null, null,
                        (obj, res) => {
                            try {
                                var val = webview.evaluate_javascript.end (res);
                                string html = val.to_string () ?? "";
                                GLib.FileUtils.set_contents (path, html);
                                LumiWebCore.lw_download_log (cu2, path);
                                GLib.stderr.puts ("[Save] " + path + "\n");
                            } catch (Error e) {}
                        });
                } catch (Error e) {}
            });
            box.append (b_save_page);
            
            var b_inspect = new Gtk.Button.with_label ("Zbadaj element");
            b_inspect.add_css_class ("ctx-btn");
            b_inspect.clicked.connect (() => {
                webview.get_inspector ().show ();
                popover.popdown ();
            });
            box.append (b_inspect);
            
            popover.set_child (box);
            
            // Ustaw pozycję kliknięcia
            var rect = Gdk.Rectangle ();
            rect.x = (int) pop_x;
            rect.y = (int) pop_y;
            rect.width = 1;
            rect.height = 1;
            popover.set_pointing_to (rect);
            popover.popup ();
            return true;
        });

webview.notify["uri"].connect (() => {
            if (this.main_stack.get_visible_child () == webview) {
                string u = webview.get_uri () ?? "";
                this.url_entry.set_text (u);
                this.update_bookmark_star (u);
            }
        });

        webview.notify["title"].connect (() => {
            tab_btn.set_tooltip_text (webview.get_title () ?? "Nowa karta");
        });

        tab_btn.clicked.connect (() => {
            this.main_stack.set_visible_child (webview);
            this.ustaw_aktywna_karte (tab_btn);
            this.url_entry.set_text (webview.get_uri () ?? "");
        });

        var right_click = new Gtk.GestureClick ();
        right_click.button = 3;
        right_click.pressed.connect (() => {
            string u = webview.get_uri () ?? "";
            if (u.has_prefix ("http")) {
                this.closed_tabs.insert (u, 0);
                if (this.closed_tabs.length () > 20)
                    this.closed_tabs.remove (this.closed_tabs.nth_data (this.closed_tabs.length () - 1));
            }
            this.main_stack.remove (webview);
            this.tab_list_box.remove (tab_btn);
            this.audio_tabs.remove (webview);
            if (this.current_active_tab == tab_btn) {
                this.main_stack.set_visible_child (this.home_screen);
                this.url_entry.set_text ("");
                this.current_active_tab = null;
            }
        });
        tab_btn.add_controller (right_click);

        this.main_stack.add_named (webview, "web_" + GLib.Random.next_int ().to_string ());
        this.tab_list_box.append (tab_btn);
        this.main_stack.set_visible_child (webview);
        this.ustaw_aktywna_karte (tab_btn);

        this.audio_tabs.insert (webview, tab_btn);
        if (url != "") zaladuj_w_webview (webview, url);
        return webview;
    }

    private void ustaw_aktywna_karte (Gtk.Button btn) {
        if (this.current_active_tab != null) this.current_active_tab.remove_css_class ("active-tab");
        btn.add_css_class ("active-tab");
        this.current_active_tab = btn;
    }



    
    private void load_adblock_filter (WebKit.UserContentManager ucm) {
        string[] filter_files = {
            GLib.Environment.get_user_config_dir () + "/lumiweb/adblock-part1.json",
            GLib.Environment.get_user_config_dir () + "/lumiweb/adblock-part2.json"
        };
        for (int i = 0; i < filter_files.length; i++) {
            string path = filter_files[i];
            if (!GLib.FileUtils.test (path, GLib.FileTest.EXISTS)) continue;
            try {
                var file = GLib.File.new_for_path (path);
                uint8[] contents;
                file.load_contents (null, out contents, null);
                var bytes = new GLib.Bytes (contents);
                string filter_id = "lumiweb-adblock-part" + (i + 1).to_string ();
                this.filter_store.save.begin (filter_id, bytes, null, (obj, res) => {
                    try {
                        this.filter_store.save.end (res);
                        this.filter_store.load.begin (filter_id, null, (obj2, res2) => {
                            try {
                                var filter = this.filter_store.load.end (res2);
                                ucm.add_filter (filter);
                                print ("[AdBlock] Filtry aktywne: %s\n", filter_id);
                            } catch (Error e) {
                                warning ("Blad ladowania filtra %s: %s", filter_id, e.message);
                            }
                        });
                    } catch (Error e) {
                        warning ("Blad zapisu filtra %s: %s", filter_id, e.message);
                    }
                });
            } catch (Error e) {
                warning ("Blad odczytu pliku %s: %s", path, e.message);
            }
        }
    }



    public bool is_private () { return this.private_mode; }
    public void set_private (bool val) { this.private_mode = val; }
    
    private void add_current_bookmark () {
        if (this.main_stack.get_visible_child () is WebKit.WebView) {
            var wv = (WebKit.WebView) this.main_stack.get_visible_child ();
            string u = wv.get_uri () ?? "";
            string t = wv.get_title () ?? "";
            if (u.has_prefix ("http")) {
                LumiWebCore.lw_bookmark_add (u, t);
                this.bookmark_btn.set_icon_name ("starred-symbolic");
                GLib.Timeout.add (1500, () => {
                    this.bookmark_btn.set_icon_name ("non-starred-symbolic");
                    return false;
                });
            }
        }
    }
    
    private void register_shortcuts (Gtk.ShortcutController sc) {
        // Ctrl+T - new tab
        sc.add_shortcut (new Gtk.Shortcut (
            Gtk.ShortcutTrigger.parse_string ("<Control>t"),
            new Gtk.CallbackAction ((w, a) => {
                this.main_stack.set_visible_child (this.home_screen);
                this.url_entry.set_text ("");
                this.url_entry.grab_focus ();
                return true;
            })));
        // Ctrl+L - focus URL
        sc.add_shortcut (new Gtk.Shortcut (
            Gtk.ShortcutTrigger.parse_string ("<Control>l"),
            new Gtk.CallbackAction ((w, a) => {
                this.url_entry.grab_focus ();
                this.url_entry.select_region (0, -1);
                return true;
            })));
        // Ctrl+F - find in page
        sc.add_shortcut (new Gtk.Shortcut (
            Gtk.ShortcutTrigger.parse_string ("<Control>f"),
            new Gtk.CallbackAction ((w, a) => { this.show_find_bar (); return true; })));
        // Escape - zamknij find bar
        sc.add_shortcut (new Gtk.Shortcut (
            Gtk.ShortcutTrigger.parse_string ("Escape"),
            new Gtk.CallbackAction ((w, a) => {
                if (this.find_bar != null) this.hide_find_bar ();
                return false;
            })));
        // Ctrl+D - bookmark
        sc.add_shortcut (new Gtk.Shortcut (
            Gtk.ShortcutTrigger.parse_string ("<Control>d"),
            new Gtk.CallbackAction ((w, a) => { this.toggle_bookmark (); return true; })));
        // Ctrl+Shift+T - reopen closed tab
        sc.add_shortcut (new Gtk.Shortcut (
            Gtk.ShortcutTrigger.parse_string ("<Control><Shift>t"),
            new Gtk.CallbackAction ((w, a) => {
                if (this.closed_tabs.length () > 0) {
                    string u = this.closed_tabs.nth_data (0);
                    this.closed_tabs.remove (u);
                    this.stworz_nowa_karte (u);
                }
                return true;
            })));
        // Ctrl+Shift+N - new private window
        sc.add_shortcut (new Gtk.Shortcut (
            Gtk.ShortcutTrigger.parse_string ("<Control><Shift>n"),
            new Gtk.CallbackAction ((w, a) => {
                var app = this.application;
                if (app != null) {
                    var pw = new LumiWebWindow ((Gtk.Application) app);
                    pw.set_private (true);
                    pw.present ();
                }
                return true;
            })));
    }
    
    private string session_file_path () {
        return GLib.Environment.get_user_config_dir () + "/lumiweb/session.json";
    }
    
    public void save_session () {
        if (this.private_mode) return;
        var arr = new Json.Array ();
        var keys = this.audio_tabs.get_keys ();
        foreach (var wv in keys) {
            if (wv != null) {
                string u = wv.get_uri () ?? "";
                if (u.has_prefix ("http")) arr.add_string_element (u);
            }
        }
        var root = new Json.Node (Json.NodeType.ARRAY);
        root.set_array (arr);
        var gen = new Json.Generator ();
        gen.set_root (root);
        try { gen.to_file (this.session_file_path ()); }
        catch (Error e) { warning ("Session save: %s", e.message); }
    }
    
    public void load_session () {
        if (this.private_mode) return;
        string path = this.session_file_path ();
        if (!GLib.FileUtils.test (path, GLib.FileTest.EXISTS)) return;
        try {
            var parser = new Json.Parser ();
            parser.load_from_file (path);
            foreach (var node in parser.get_root ().get_array ().get_elements ()) {
                string u = node.get_string ();
                if (u != null && u.has_prefix ("http")) this.stworz_nowa_karte (u);
            }
        } catch (Error e) { warning ("Session load: %s", e.message); }
    }


    
    


    public void new_tab (string url) {
        this.stworz_nowa_karte (url);
    }
    
    public GLib.List<string> get_open_urls () {
        var list = new GLib.List<string> ();
        var keys = this.audio_tabs.get_keys ();
        foreach (var wv in keys) {
            if (wv != null) {
                string u = wv.get_uri () ?? "";
                if (u.has_prefix ("http")) list.append (u);
            }
        }
        return list;
    }
    
    public void toggle_split_mode (bool horizontal = true) {
        if (this.split_paned != null) {
            this.disable_split ();
            return;
        }
        if (!(this.main_stack.get_visible_child () is WebKit.WebView)) return;
        
        var existing = (WebKit.WebView) this.main_stack.get_visible_child ();
        this.split_horizontal = horizontal;
        this.split_left_view = existing;
        this.split_right_view = new WebKit.WebView ();
        this.split_right_view.set_hexpand (true);
        this.split_right_view.set_vexpand (true);
        var ucm = this.split_right_view.get_user_content_manager ();
        this.zaladuj_mody_i_pluginy_do_ucm (ucm);
        
        this.main_stack.remove (existing);
        
        this.split_paned = new Gtk.Paned (
            horizontal ? Gtk.Orientation.HORIZONTAL : Gtk.Orientation.VERTICAL);
        this.split_paned.set_hexpand (true);
        this.split_paned.set_vexpand (true);
        this.split_paned.set_start_child (existing);
        this.split_paned.set_end_child (this.split_right_view);
        this.split_paned.set_position (600);
        
        this.main_stack.add_named (this.split_paned, "split");
        this.main_stack.set_visible_child_name ("split");
    }
    
    private void disable_split () {
        if (this.split_paned == null) return;
        var lv = this.split_left_view;
        var rv = this.split_right_view;
        this.main_stack.remove (this.split_paned);
        this.split_paned = null;
        
        if (lv != null) {
            this.main_stack.add_named (lv, "web_" + GLib.Random.next_int ().to_string ());
            this.main_stack.set_visible_child (lv);
        }
        if (rv != null) this.audio_tabs.remove (rv);
        this.split_left_view = null;
        this.split_right_view = null;
    }
    

    private void show_notification (string title, string body) {
        try {
            var notif = new GLib.Notification (title);
            notif.set_body (body);
            var app = this.application;
            if (app != null) {
                ((GLib.Application) app).send_notification (null, notif);
            }
            GLib.stderr.puts ("[Notify] " + title + ": " + body + "\n");
        } catch (Error e) {
            warning ("Notification: %s", e.message);
        }
    }
    
    private void check_lua_notifications (string plugin_path, string current_url) {
        unowned string notifs = LumiWebCore.lw_plugin_notify (plugin_path, current_url);
        if (notifs != null && notifs.length > 0) {
            foreach (var line in notifs.split ("\n")) {
                string msg = line.strip ();
                if (msg == "") continue;
                if (this.shown_notifs != null && this.shown_notifs.contains (msg)) continue;
                if (this.shown_notifs != null) this.shown_notifs.insert (msg, true);
                this.show_notification ("LumiWeb Plugin", msg);
            }
            LumiWebCore.lw_free_string (notifs);
        }
    }
    

    private void update_bookmark_star (string url) {
        if (this.bookmark_btn == null) return;
        if (!url.has_prefix ("http")) {
            this.bookmark_btn.set_icon_name ("non-starred-symbolic");
            return;
        }
        unowned string json = LumiWebCore.lw_bookmark_list ();
        bool found = false;
        try {
            var parser = new Json.Parser ();
            parser.load_from_data (json);
            foreach (var node in parser.get_root ().get_array ().get_elements ()) {
                var row = node.get_array ();
                string u = row.get_string_element (1);
                if (u == url) { found = true; break; }
            }
        } catch (Error e) {}
        LumiWebCore.lw_free_string (json);
        this.bookmark_btn.set_icon_name (found ? "starred-symbolic" : "non-starred-symbolic");
    }
    
    private void toggle_bookmark () {
        if (this.main_stack.get_visible_child () is WebKit.WebView) {
            var wv = (WebKit.WebView) this.main_stack.get_visible_child ();
            string u = wv.get_uri () ?? "";
            if (!u.has_prefix ("http")) return;
            unowned string json = LumiWebCore.lw_bookmark_list ();
            try {
                var parser = new Json.Parser ();
                parser.load_from_data (json);
                foreach (var node in parser.get_root ().get_array ().get_elements ()) {
                    var row = node.get_array ();
                    int64 id = row.get_int_element (0);
                    string bu = row.get_string_element (1);
                    if (bu == u) {
                        LumiWebCore.lw_bookmark_delete (id);
                        LumiWebCore.lw_free_string (json);
                        this.update_bookmark_star (u);
                        return;
                    }
                }
            } catch (Error e) {}
            LumiWebCore.lw_free_string (json);
            LumiWebCore.lw_bookmark_add (u, wv.get_title () ?? "");
            this.update_bookmark_star (u);
        }
    }
    

    private void show_find_bar () {
        if (this.find_bar == null) {
            this.find_bar = new Gtk.Revealer ();
            this.find_bar.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
            var fb = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            fb.add_css_class ("find-bar");
            fb.set_margin_start (16);
            fb.set_margin_end (16);
            fb.set_margin_top (4);
            fb.set_margin_bottom (4);
            
            this.find_entry = new Gtk.Entry ();
            this.find_entry.set_placeholder_text ("Szukaj na stronie...");
            this.find_entry.set_hexpand (true);
            this.find_entry.add_css_class ("find-entry");
            fb.append (this.find_entry);
            
            var prev_btn = new Gtk.Button.from_icon_name ("go-up-symbolic");
            prev_btn.add_css_class ("find-btn");
            prev_btn.set_tooltip_text ("Poprzednie");
            fb.append (prev_btn);
            
            var next_btn = new Gtk.Button.from_icon_name ("go-down-symbolic");
            next_btn.add_css_class ("find-btn");
            next_btn.set_tooltip_text ("Następne");
            fb.append (next_btn);
            
            var close_btn = new Gtk.Button.from_icon_name ("window-close-symbolic");
            close_btn.add_css_class ("find-btn");
            close_btn.clicked.connect (() => { this.hide_find_bar (); });
            fb.append (close_btn);
            
            this.find_bar.set_child (fb);
            
            // Wstaw find_bar pod progress bar
            var root = this.get_child ();
            if (root is Gtk.Box) {
                ((Gtk.Box) root).append (this.find_bar);
            }
            
            this.find_entry.activate.connect (() => {
                if (this.main_stack.get_visible_child () is WebKit.WebView) {
                    var wv = (WebKit.WebView) this.main_stack.get_visible_child ();
                    var ctrl = wv.get_find_controller ();
                    ctrl.search (this.find_entry.get_text (), WebKit.FindOptions.CASE_INSENSITIVE, uint.MAX);
                }
            });
            this.find_entry.changed.connect (() => {
                if (this.main_stack.get_visible_child () is WebKit.WebView) {
                    var wv = (WebKit.WebView) this.main_stack.get_visible_child ();
                    string q = this.find_entry.get_text ();
                    var ctrl = wv.get_find_controller ();
                    ctrl.search (q, WebKit.FindOptions.CASE_INSENSITIVE, uint.MAX);
                }
            });
            
            next_btn.clicked.connect (() => {
                if (this.main_stack.get_visible_child () is WebKit.WebView) {
                    var wv = (WebKit.WebView) this.main_stack.get_visible_child ();
                    var ctrl = wv.get_find_controller ();
                    ctrl.search (this.find_entry.get_text (), WebKit.FindOptions.CASE_INSENSITIVE, uint.MAX);
                    ctrl.search_next ();
                }
            });
            prev_btn.clicked.connect (() => {
                if (this.main_stack.get_visible_child () is WebKit.WebView) {
                    var wv = (WebKit.WebView) this.main_stack.get_visible_child ();
                    var ctrl = wv.get_find_controller ();
                    ctrl.search_previous ();
                }
            });
        }
        this.find_bar.set_reveal_child (true);
        this.find_entry.grab_focus ();
    }
    
    private void hide_find_bar () {
        if (this.find_bar != null) {
            this.find_bar.set_reveal_child (false);
        }
        if (this.main_stack.get_visible_child () is WebKit.WebView) {
            var wv = (WebKit.WebView) this.main_stack.get_visible_child ();
            var ctrl = wv.get_find_controller ();
            ctrl.search ("", WebKit.FindOptions.CASE_INSENSITIVE, uint.MAX);
        }
    }
    
    private void clear_cookies_on_exit () {
        if (!this.private_mode) return;
        var session = WebKit.NetworkSession.get_default ();
        var data_manager = session.get_website_data_manager ();
        // WebKit 6.0 - async clear
        data_manager.clear.begin (WebKit.WebsiteDataTypes.ALL, 0, null, (obj, res) => {
            try {
                data_manager.clear.end (res);
                GLib.stderr.puts ("[Private] Website data wyczyszczone\n");
            } catch (Error e) {
                warning ("Clear data: %s", e.message);
            }
        });
    }
    

    private string get_install_prefix () {
        try {
            string exe = GLib.FileUtils.read_link ("/proc/self/exe");
            string bin_dir = GLib.Path.get_dirname (exe);
            return GLib.Path.get_dirname (bin_dir);
        } catch (Error e) {
            return GLib.Environment.get_home_dir () + "/.local";
        }
    }
    

    private string get_settings_binary () {
        try {
            string exe = GLib.FileUtils.read_link ("/proc/self/exe");
            string exe_dir = GLib.Path.get_dirname (exe);
            string installed = GLib.Path.build_filename (exe_dir, "lumiweb-settings");
            if (GLib.FileUtils.test (installed, GLib.FileTest.IS_EXECUTABLE))
                return installed;
        } catch (Error e) {}
        string[] dev_paths = {
            "./src/rust/settings/target/release/lumiweb-settings",
            "./src/rust/settings/target/debug/lumiweb-settings"
        };
        foreach (var p in dev_paths) {
            if (GLib.FileUtils.test (p, GLib.FileTest.IS_EXECUTABLE))
                return p;
        }
        return "lumiweb-settings";
    }
    
    private string get_search_url (string query) {
        string engine = "google";
        string path = GLib.Environment.get_user_config_dir () + "/lumiweb/search.txt";
        if (GLib.FileUtils.test (path, GLib.FileTest.EXISTS)) {
            try {
                GLib.FileUtils.get_contents (path, out engine);
                engine = engine.strip ();
            } catch (Error e) {}
        }
        if (engine == "") engine = "google";
        
        switch (engine) {
            case "duckduckgo": return "https://duckduckgo.com/?q=" + GLib.Uri.escape_string (query);
            case "bing": return "https://www.bing.com/search?q=" + GLib.Uri.escape_string (query);
            case "brave": return "https://search.brave.com/search?q=" + GLib.Uri.escape_string (query);
            case "startpage": return "https://www.startpage.com/sp/search?query=" + GLib.Uri.escape_string (query);
            default: return "https://www.google.com/search?q=" + GLib.Uri.escape_string (query);
        }
    }

    private void zaladuj_w_webview (WebKit.WebView webview, string tekst) {
        if (tekst == "") return;
        if (tekst.has_prefix ("http://") || tekst.has_prefix ("https://")) webview.load_uri (tekst);
        else webview.load_uri (get_search_url (tekst));
    }
}


// ============================================================
// OSOBNE OKNA: Kalendarz, Todo, Notatki
// ============================================================

public class CalendarWindow : Gtk.Window {
    private Gtk.Box list_box;
    
    public CalendarWindow (Gtk.Window parent) {
        Object (title: "Kalendarz", transient_for: parent, modal: false,
                default_width: 500, default_height: 600);
        this.decorated = false;
        this.add_css_class ("popup-window");
        
        var root = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        this.set_child (root);
        
        // Titlebar
        var handle = new Gtk.WindowHandle ();
        var titlebar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        titlebar.add_css_class ("custom-titlebar");
        titlebar.set_size_request (-1, 36);
        
        var icon = new Gtk.Image.from_icon_name ("x-office-calendar-symbolic");
        icon.set_pixel_size (16);
        icon.set_margin_start (12);
        titlebar.append (icon);
        
        var title_lbl = new Gtk.Label ("Kalendarz");
        title_lbl.add_css_class ("window-title-label");
        title_lbl.set_hexpand (true);
        title_lbl.set_halign (Gtk.Align.START);
        titlebar.append (title_lbl);
        
        var close_btn = new Gtk.Button.from_icon_name ("window-close-symbolic");
        close_btn.add_css_class ("window-close-flat");
        close_btn.clicked.connect (() => { this.close (); });
        titlebar.append (close_btn);
        
        handle.set_child (titlebar);
        root.append (handle);
        
        // Formularz
        var form = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        form.set_margin_top (16);
        form.set_margin_start (16);
        form.set_margin_end (16);
        
        var date_entry = new Gtk.Entry ();
        date_entry.set_placeholder_text ("RRRR-MM-DD");
        date_entry.set_width_chars (12);
        date_entry.add_css_class ("form-entry");
        form.append (date_entry);
        
        var name_entry = new Gtk.Entry ();
        name_entry.set_placeholder_text ("Nazwa wydarzenia");
        name_entry.set_hexpand (true);
        name_entry.add_css_class ("form-entry");
        form.append (name_entry);
        
        var add_btn = new Gtk.Button.with_label ("Dodaj");
        add_btn.add_css_class ("action-btn");
        form.append (add_btn);
        
        root.append (form);
        
        // Lista
        this.list_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
        this.list_box.set_margin_top (16);
        this.list_box.set_margin_start (16);
        this.list_box.set_margin_end (16);
        this.list_box.set_margin_bottom (16);
        
        var scroll = new Gtk.ScrolledWindow ();
        scroll.set_child (this.list_box);
        scroll.set_vexpand (true);
        root.append (scroll);
        
        void refresh () {
            var child = this.list_box.get_first_child ();
            while (child != null) { var next = child.get_next_sibling (); this.list_box.remove (child); child = next; }
            unowned string json = LumiWebCore.lw_calendar_list ();
            try {
                var parser = new Json.Parser ();
                parser.load_from_data (json);
                var arr = parser.get_root ().get_array ();
                foreach (var node in arr.get_elements ()) {
                    var row = node.get_array ();
                    int64 id = row.get_int_element (0);
                    string date = row.get_string_element (1);
                    string title = row.get_string_element (2);
                    var item = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
                    item.add_css_class ("list-item");
                    var lbl = new Gtk.Label (date + "  ·  " + title);
                    lbl.set_hexpand (true);
                    lbl.set_halign (Gtk.Align.START);
                    item.append (lbl);
                    var del = new Gtk.Button.from_icon_name ("user-trash-symbolic");
                    del.add_css_class ("del-btn");
                    var id_cap = id;
                    del.clicked.connect (() => {
                        LumiWebCore.lw_calendar_delete (id_cap);
                        this.refresh_internal ();
                    });
                    item.append (del);
                    this.list_box.append (item);
                }
            } catch (Error e) {}
            LumiWebCore.lw_free_string (json);
        }
        
        add_btn.clicked.connect (() => {
            if (date_entry.get_text () != "" && name_entry.get_text () != "") {
                LumiWebCore.lw_calendar_add (date_entry.get_text (), name_entry.get_text (), "");
                name_entry.set_text ("");
                this.refresh_internal ();
            }
        });
        name_entry.activate.connect (() => { add_btn.clicked (); });
        
        refresh ();
    }
    
    private void refresh_internal () {
        var child = this.list_box.get_first_child ();
        while (child != null) { var next = child.get_next_sibling (); this.list_box.remove (child); child = next; }
        unowned string json = LumiWebCore.lw_calendar_list ();
        try {
            var parser = new Json.Parser ();
            parser.load_from_data (json);
            var arr = parser.get_root ().get_array ();
            foreach (var node in arr.get_elements ()) {
                var row = node.get_array ();
                int64 id = row.get_int_element (0);
                string date = row.get_string_element (1);
                string title = row.get_string_element (2);
                var item = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
                item.add_css_class ("list-item");
                var lbl = new Gtk.Label (date + "  ·  " + title);
                lbl.set_hexpand (true);
                lbl.set_halign (Gtk.Align.START);
                item.append (lbl);
                var del = new Gtk.Button.from_icon_name ("user-trash-symbolic");
                del.add_css_class ("del-btn");
                var id_cap = id;
                del.clicked.connect (() => {
                    LumiWebCore.lw_calendar_delete (id_cap);
                    this.refresh_internal ();
                });
                item.append (del);
                this.list_box.append (item);
            }
        } catch (Error e) {}
        LumiWebCore.lw_free_string (json);
    }
}

public class TodoWindow : Gtk.Window {
    private Gtk.Box list_box;
    
    public TodoWindow (Gtk.Window parent) {
        Object (title: "Zadania", transient_for: parent, modal: false,
                default_width: 480, default_height: 600);
        this.decorated = false;
        this.add_css_class ("popup-window");
        
        var root = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        this.set_child (root);
        
        var handle = new Gtk.WindowHandle ();
        var titlebar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        titlebar.add_css_class ("custom-titlebar");
        titlebar.set_size_request (-1, 36);
        
        var icon = new Gtk.Image.from_icon_name ("checkbox-checked-symbolic");
        icon.set_pixel_size (16);
        icon.set_margin_start (12);
        titlebar.append (icon);
        
        var title_lbl = new Gtk.Label ("Zadania");
        title_lbl.add_css_class ("window-title-label");
        title_lbl.set_hexpand (true);
        title_lbl.set_halign (Gtk.Align.START);
        titlebar.append (title_lbl);
        
        var close_btn = new Gtk.Button.from_icon_name ("window-close-symbolic");
        close_btn.add_css_class ("window-close-flat");
        close_btn.clicked.connect (() => { this.close (); });
        titlebar.append (close_btn);
        
        handle.set_child (titlebar);
        root.append (handle);
        
        var form = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        form.set_margin_top (16);
        form.set_margin_start (16);
        form.set_margin_end (16);
        
        var entry = new Gtk.Entry ();
        entry.set_placeholder_text ("Nowe zadanie...");
        entry.set_hexpand (true);
        entry.add_css_class ("form-entry");
        form.append (entry);
        
        var add_btn = new Gtk.Button.with_label ("Dodaj");
        add_btn.add_css_class ("action-btn");
        form.append (add_btn);
        
        root.append (form);
        
        this.list_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        this.list_box.set_margin_top (16);
        this.list_box.set_margin_start (16);
        this.list_box.set_margin_end (16);
        this.list_box.set_margin_bottom (16);
        
        var scroll = new Gtk.ScrolledWindow ();
        scroll.set_child (this.list_box);
        scroll.set_vexpand (true);
        root.append (scroll);
        
        add_btn.clicked.connect (() => {
            if (entry.get_text () != "") {
                LumiWebCore.lw_todo_add (entry.get_text ());
                entry.set_text ("");
                this.refresh_internal ();
            }
        });
        entry.activate.connect (() => { add_btn.clicked (); });
        
        this.refresh_internal ();
    }
    
    private void refresh_internal () {
        var child = this.list_box.get_first_child ();
        while (child != null) { var next = child.get_next_sibling (); this.list_box.remove (child); child = next; }
        unowned string json = LumiWebCore.lw_todo_list ();
        try {
            var parser = new Json.Parser ();
            parser.load_from_data (json);
            var arr = parser.get_root ().get_array ();
            foreach (var node in arr.get_elements ()) {
                var row = node.get_array ();
                int64 id = row.get_int_element (0);
                string title = row.get_string_element (1);
                int64 done = row.get_int_element (2);
                var item = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
                item.add_css_class ("list-item");
                var check = new Gtk.CheckButton ();
                check.set_active (done == 1);
                var id_cap = id;
                check.toggled.connect (() => {
                    LumiWebCore.lw_todo_toggle (id_cap);
                    GLib.Idle.add (() => { this.refresh_internal (); return false; });
                });
                item.append (check);
                var lbl = new Gtk.Label (title);
                lbl.set_hexpand (true);
                lbl.set_halign (Gtk.Align.START);
                if (done == 1) lbl.add_css_class ("done-text");
                item.append (lbl);
                var del = new Gtk.Button.from_icon_name ("user-trash-symbolic");
                del.add_css_class ("del-btn");
                del.clicked.connect (() => {
                    LumiWebCore.lw_todo_delete (id_cap);
                    this.refresh_internal ();
                });
                item.append (del);
                this.list_box.append (item);
            }
        } catch (Error e) {}
        LumiWebCore.lw_free_string (json);
    }
}

public class NotesWindow : Gtk.Window {
    private Gtk.TextView textview;
    
    public NotesWindow (Gtk.Window parent) {
        Object (title: "Notatki", transient_for: parent, modal: false,
                default_width: 600, default_height: 500);
        this.decorated = false;
        this.add_css_class ("popup-window");
        
        var root = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        this.set_child (root);
        
        var handle = new Gtk.WindowHandle ();
        var titlebar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        titlebar.add_css_class ("custom-titlebar");
        titlebar.set_size_request (-1, 36);
        
        var icon = new Gtk.Image.from_icon_name ("accessories-text-editor-symbolic");
        icon.set_pixel_size (16);
        icon.set_margin_start (12);
        titlebar.append (icon);
        
        var title_lbl = new Gtk.Label ("Notatki");
        title_lbl.add_css_class ("window-title-label");
        title_lbl.set_hexpand (true);
        title_lbl.set_halign (Gtk.Align.START);
        titlebar.append (title_lbl);
        
        var close_btn = new Gtk.Button.from_icon_name ("window-close-symbolic");
        close_btn.add_css_class ("window-close-flat");
        close_btn.clicked.connect (() => { this.close (); });
        titlebar.append (close_btn);
        
        handle.set_child (titlebar);
        root.append (handle);
        
        this.textview = new Gtk.TextView ();
        this.textview.set_wrap_mode (Gtk.WrapMode.WORD);
        this.textview.add_css_class ("notes-text");
        this.textview.set_margin_top (16);
        this.textview.set_margin_start (16);
        this.textview.set_margin_end (16);
        
        var scroll = new Gtk.ScrolledWindow ();
        scroll.set_child (this.textview);
        scroll.set_vexpand (true);
        root.append (scroll);
        
        var save_btn = new Gtk.Button.with_label ("Zapisz");
        save_btn.add_css_class ("action-btn");
        save_btn.set_margin_top (12);
        save_btn.set_margin_start (16);
        save_btn.set_margin_end (16);
        save_btn.set_margin_bottom (16);
        save_btn.set_halign (Gtk.Align.END);
        root.append (save_btn);
        
        unowned string saved = LumiWebCore.lw_notes_load ();
        this.textview.buffer.set_text (saved, -1);
        LumiWebCore.lw_free_string (saved);
        
        save_btn.clicked.connect (() => {
            var buf = this.textview.buffer;
            Gtk.TextIter start_iter, end_iter;
            buf.get_bounds (out start_iter, out end_iter);
            LumiWebCore.lw_notes_save (buf.get_text (start_iter, end_iter, false));
            save_btn.set_label ("Zapisano!");
            GLib.Timeout.add (1500, () => {
                save_btn.set_label ("Zapisz");
                return false;
            });
        });
    }
}


// ============================================================
// AUDIO WINDOW - pływające okno z dźwiękami kart
// ============================================================
public class AudioWindow : Gtk.Window {
    private Gtk.Box list_box;
    private GLib.HashTable<WebKit.WebView, Gtk.Button> tabs;
    
    public AudioWindow (Gtk.Window parent, GLib.HashTable<WebKit.WebView, Gtk.Button> tabs) {
        Object (title: "Dźwięk", transient_for: parent, modal: false,
                default_width: 320, default_height: 400,
                resizable: true);
        this.decorated = false;
        this.add_css_class ("popup-window");
        this.tabs = tabs;
        
        var root = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        this.set_child (root);
        
        var handle = new Gtk.WindowHandle ();
        var titlebar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        titlebar.add_css_class ("custom-titlebar");
        titlebar.set_size_request (-1, 36);
        
        var icon = new Gtk.Image.from_icon_name ("audio-volume-high-symbolic");
        icon.set_pixel_size (16);
        icon.set_margin_start (12);
        titlebar.append (icon);
        
        var title_lbl = new Gtk.Label ("Aktywne dźwięki");
        title_lbl.add_css_class ("window-title-label");
        title_lbl.set_hexpand (true);
        title_lbl.set_halign (Gtk.Align.START);
        titlebar.append (title_lbl);
        
        var close_btn = new Gtk.Button.from_icon_name ("window-close-symbolic");
        close_btn.add_css_class ("window-close-flat");
        close_btn.clicked.connect (() => { this.close (); });
        titlebar.append (close_btn);
        
        handle.set_child (titlebar);
        root.append (handle);
        
        this.list_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
        this.list_box.set_margin_top (12);
        this.list_box.set_margin_start (12);
        this.list_box.set_margin_end (12);
        this.list_box.set_margin_bottom (12);
        
        var scroll = new Gtk.ScrolledWindow ();
        scroll.set_child (this.list_box);
        scroll.set_vexpand (true);
        root.append (scroll);
        
        this.refresh ();
    }
    
    public void refresh () {
        var child = this.list_box.get_first_child ();
        while (child != null) { var next = child.get_next_sibling (); this.list_box.remove (child); child = next; }
        
        int count = 0;
        var keys = this.tabs.get_keys ();
        foreach (var wv in keys) {
            if (wv == null) continue;
            bool playing = wv.is_playing_audio;
            if (!playing) continue;
            count++;
            
            var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            row.add_css_class ("audio-row");
            
            var lbl = new Gtk.Label (wv.get_title () ?? "Dźwięk");
            lbl.set_ellipsize (3);
            lbl.set_max_width_chars (22);
            lbl.set_hexpand (true);
            lbl.set_halign (Gtk.Align.START);
            row.append (lbl);
            
            var mute_btn = new Gtk.Button.from_icon_name (
                wv.is_muted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic");
            mute_btn.add_css_class ("audio-btn");
            var wv_cap = wv;
            mute_btn.clicked.connect (() => {
                wv_cap.set_is_muted (!wv_cap.is_muted);
                GLib.Idle.add (() => { this.refresh (); return false; });
            });
            row.append (mute_btn);
            this.list_box.append (row);
        }
        
        if (count == 0) {
            var empty = new Gtk.Label ("Brak aktywnych dźwięków");
            empty.add_css_class ("audio-empty");
            this.list_box.append (empty);
        }
    }
}


public class BookmarksWindow : Gtk.Window {
    private Gtk.Box list_box;
    public BookmarksWindow (Gtk.Window parent) {
        Object (title: "Zakładki", transient_for: parent, modal: false,
                default_width: 500, default_height: 600);
        this.decorated = false;
        this.add_css_class ("popup-window");
        var root = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        this.set_child (root);
        var handle = new Gtk.WindowHandle ();
        var titlebar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        titlebar.add_css_class ("custom-titlebar");
        titlebar.set_size_request (-1, 36);
        var icon = new Gtk.Image.from_icon_name ("user-bookmarks-symbolic");
        icon.set_pixel_size (16); icon.set_margin_start (12);
        titlebar.append (icon);
        var lbl_title = new Gtk.Label ("Zakładki");
        lbl_title.add_css_class ("window-title-label");
        lbl_title.set_hexpand (true); lbl_title.set_halign (Gtk.Align.START);
        titlebar.append (lbl_title);
        var close_btn = new Gtk.Button.from_icon_name ("window-close-symbolic");
        close_btn.add_css_class ("window-close-flat");
        close_btn.clicked.connect (() => { this.close (); });
        titlebar.append (close_btn);
        handle.set_child (titlebar);
        root.append (handle);
        this.list_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        this.list_box.set_margin_top (12); this.list_box.set_margin_start (12);
        this.list_box.set_margin_end (12); this.list_box.set_margin_bottom (12);
        var scroll = new Gtk.ScrolledWindow ();
        scroll.set_child (this.list_box);
        scroll.set_vexpand (true);
        root.append (scroll);
        this.refresh ();
    }
    public void refresh () {
        var child = this.list_box.get_first_child ();
        while (child != null) { var n = child.get_next_sibling (); this.list_box.remove (child); child = n; }
        unowned string json = LumiWebCore.lw_bookmark_list ();
        try {
            var parser = new Json.Parser ();
            parser.load_from_data (json);
            foreach (var node in parser.get_root ().get_array ().get_elements ()) {
                var row = node.get_array ();
                int64 id = row.get_int_element (0);
                string url = row.get_string_element (1);
                string title = row.get_string_element (2);
                var item = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
                item.add_css_class ("list-item");
                var btn = new Gtk.Button ();
                btn.add_css_class ("bookmark-open-btn");
                var lbl = new Gtk.Label (title == "" ? url : title);
                lbl.set_halign (Gtk.Align.START); lbl.set_hexpand (true);
                btn.set_child (lbl);
                btn.clicked.connect (() => {
                    var p = this.get_transient_for ();
                    if (p is LumiWebWindow) ((LumiWebWindow) p).open_url (url);
                });
                item.append (btn);
                var del = new Gtk.Button.from_icon_name ("user-trash-symbolic");
                del.add_css_class ("del-btn");
                var id_cap = id;
                del.clicked.connect (() => { LumiWebCore.lw_bookmark_delete (id_cap); this.refresh (); });
                item.append (del);
                this.list_box.append (item);
            }
        } catch (Error e) {}
        LumiWebCore.lw_free_string (json);
    }
}


public class DownloadsWindow : Gtk.Window {
    private Gtk.Box list_box;
    public DownloadsWindow (Gtk.Window parent) {
        Object (title: "Pobierane", transient_for: parent, modal: false,
                default_width: 600, default_height: 500);
        this.decorated = false;
        this.add_css_class ("popup-window");
        var root = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        this.set_child (root);
        var handle = new Gtk.WindowHandle ();
        var titlebar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        titlebar.add_css_class ("custom-titlebar");
        titlebar.set_size_request (-1, 36);
        var icon = new Gtk.Image.from_icon_name ("folder-download-symbolic");
        icon.set_pixel_size (16); icon.set_margin_start (12);
        titlebar.append (icon);
        var lbl = new Gtk.Label ("Pobierane");
        lbl.add_css_class ("window-title-label");
        lbl.set_hexpand (true); lbl.set_halign (Gtk.Align.START);
        titlebar.append (lbl);
        var close_btn = new Gtk.Button.from_icon_name ("window-close-symbolic");
        close_btn.add_css_class ("window-close-flat");
        close_btn.clicked.connect (() => { this.close (); });
        titlebar.append (close_btn);
        handle.set_child (titlebar);
        root.append (handle);
        this.list_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        this.list_box.set_margin_top (12); this.list_box.set_margin_start (12);
        this.list_box.set_margin_end (12); this.list_box.set_margin_bottom (12);
        var scroll = new Gtk.ScrolledWindow ();
        scroll.set_child (this.list_box);
        scroll.set_vexpand (true);
        root.append (scroll);
        this.refresh ();
    }
    public void refresh () {
        var child = this.list_box.get_first_child ();
        while (child != null) { var n = child.get_next_sibling (); this.list_box.remove (child); child = n; }
        unowned string json = LumiWebCore.lw_download_list ();
        try {
            var parser = new Json.Parser ();
            parser.load_from_data (json);
            foreach (var node in parser.get_root ().get_array ().get_elements ()) {
                var row = node.get_array ();
                string url = row.get_string_element (1);
                string path = row.get_string_element (2);
                string ts = row.get_string_element (3);
                var item = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
                item.add_css_class ("list-item");
                var u = new Gtk.Label (url); u.set_halign (Gtk.Align.START);
                u.set_ellipsize (3); u.add_css_class ("download-url");
                item.append (u);
                var p = new Gtk.Label (path + "  ·  " + ts);
                p.set_halign (Gtk.Align.START); p.add_css_class ("download-path");
                item.append (p);
                this.list_box.append (item);
            }
        } catch (Error e) {}
        LumiWebCore.lw_free_string (json);
    }
}

public class WorkspacesWindow : Gtk.Window {
    private Gtk.Box list_box;
    private Gtk.Window? parent_win;
    public WorkspacesWindow (Gtk.Window parent) {
        Object (title: "Przestrzenie", transient_for: parent, modal: false,
                default_width: 500, default_height: 500);
        this.parent_win = parent;
        this.decorated = false;
        this.add_css_class ("popup-window");
        var root = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        this.set_child (root);
        var handle = new Gtk.WindowHandle ();
        var titlebar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        titlebar.add_css_class ("custom-titlebar");
        titlebar.set_size_request (-1, 36);
        var icon = new Gtk.Image.from_icon_name ("view-grid-symbolic");
        icon.set_pixel_size (16); icon.set_margin_start (12);
        titlebar.append (icon);
        var lbl = new Gtk.Label ("Przestrzenie robocze");
        lbl.add_css_class ("window-title-label");
        lbl.set_hexpand (true); lbl.set_halign (Gtk.Align.START);
        titlebar.append (lbl);
        var close_btn = new Gtk.Button.from_icon_name ("window-close-symbolic");
        close_btn.add_css_class ("window-close-flat");
        close_btn.clicked.connect (() => { this.close (); });
        titlebar.append (close_btn);
        handle.set_child (titlebar);
        root.append (handle);
        
        var form = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        form.set_margin_top (12); form.set_margin_start (12); form.set_margin_end (12);
        var name_entry = new Gtk.Entry ();
        name_entry.set_placeholder_text ("Nazwa przestrzeni...");
        name_entry.set_hexpand (true);
        name_entry.add_css_class ("form-entry");
        form.append (name_entry);
        var save_btn = new Gtk.Button.with_label ("Zapisz obecne karty");
        save_btn.add_css_class ("action-btn");
        form.append (save_btn);
        root.append (form);
        
        this.list_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        this.list_box.set_margin_top (12); this.list_box.set_margin_start (12);
        this.list_box.set_margin_end (12); this.list_box.set_margin_bottom (12);
        var scroll = new Gtk.ScrolledWindow ();
        scroll.set_child (this.list_box);
        scroll.set_vexpand (true);
        root.append (scroll);
        
        save_btn.clicked.connect (() => {
            string n = name_entry.get_text ();
            if (n == "") return;
            var arr = new Json.Array ();
            if (parent_win is LumiWebWindow) {
                foreach (var u in ((LumiWebWindow) parent_win).get_open_urls ())
                    arr.add_string_element (u);
            }
            var root_node = new Json.Node (Json.NodeType.ARRAY);
            root_node.set_array (arr);
            var gen = new Json.Generator ();
            gen.set_root (root_node);
            LumiWebCore.lw_workspace_add (n, gen.to_data (null));
            name_entry.set_text ("");
            this.refresh ();
        });
        
        this.refresh ();
    }
    public void refresh () {
        var child = this.list_box.get_first_child ();
        while (child != null) { var n = child.get_next_sibling (); this.list_box.remove (child); child = n; }
        unowned string json = LumiWebCore.lw_workspace_list ();
        try {
            var parser = new Json.Parser ();
            parser.load_from_data (json);
            foreach (var node in parser.get_root ().get_array ().get_elements ()) {
                var row = node.get_array ();
                int64 id = row.get_int_element (0);
                string name = row.get_string_element (1);
                string urls_json = row.get_string_element (2);
                var item = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
                item.add_css_class ("list-item");
                var btn = new Gtk.Button ();
                btn.add_css_class ("bookmark-open-btn");
                var l = new Gtk.Label (name);
                l.set_halign (Gtk.Align.START); l.set_hexpand (true);
                btn.set_child (l);
                var name_c = name;
                btn.clicked.connect (() => {
                    if (this.parent_win is LumiWebWindow) {
                        var pw = (LumiWebWindow) this.parent_win;
                        try {
                            var p = new Json.Parser ();
                            p.load_from_data (urls_json);
                            foreach (var n2 in p.get_root ().get_array ().get_elements ()) {
                                string u = n2.get_string ();
                                if (u != null) pw.new_tab (u);
                            }
                        } catch (Error e) {}
                    }
                });
                item.append (btn);
                var del = new Gtk.Button.from_icon_name ("user-trash-symbolic");
                del.add_css_class ("del-btn");
                var id_c = id;
                del.clicked.connect (() => { LumiWebCore.lw_workspace_delete (id_c); this.refresh (); });
                item.append (del);
                this.list_box.append (item);
            }
        } catch (Error e) {}
        LumiWebCore.lw_free_string (json);
    }
}

int main (string[] args) {
    // Sprawdź czy podano URL lub plik w args
    string? initial_url = null;
    for (int i = 1; i < args.length; i++) {
        string arg = args[i];
        if (arg.has_prefix ("-")) continue;
        
        if (arg.contains ("://")) {
            initial_url = arg;
            break;
        }
        // Plik lokalny (.html, .htm) lub istniejąca ścieżka
        if (arg.has_suffix (".html") || arg.has_suffix (".htm") ||
            arg.has_suffix (".xhtml") || arg.has_suffix (".svg") ||
            GLib.FileUtils.test (arg, GLib.FileTest.EXISTS)) {
            var f = GLib.File.new_for_path (arg);
            if (f.query_exists ()) {
                initial_url = f.get_uri ();
                break;
            }
        }
        // Wygląda jak domena (np. google.com)
        if (arg.contains (".") && !arg.contains (" ")) {
            initial_url = "https://" + arg;
            break;
        }
    }
    
    var app = new Gtk.Application ("com.lumiweb.browser",
        GLib.ApplicationFlags.HANDLES_OPEN | GLib.ApplicationFlags.HANDLES_COMMAND_LINE);
    
    LumiWebWindow? window = null;
    
    app.activate.connect (() => {
        if (window == null) {
            window = new LumiWebWindow (app);
        }
        window.present ();
        
        if (initial_url != null && window != null) {
            window.open_url (initial_url);
            initial_url = null;
        }
    });
    
    app.open.connect ((files, hint) => {
        if (window == null) {
            window = new LumiWebWindow (app);
            window.present ();
        }
        for (int i = 0; i < files.length; i++) {
            var uri = files[i].get_uri ();
            if (uri != null && window != null) window.open_url (uri);
        }
    });
    
    app.command_line.connect ((cmd) => {
        var args_cl = cmd.get_arguments ();
        if (window == null) {
            window = new LumiWebWindow (app);
            window.present ();
        }
        for (int i = 1; i < args_cl.length; i++) {
            string a = args_cl[i];
            if (a.contains ("://")) {
                window.open_url (a);
            } else if (GLib.FileUtils.test (a, GLib.FileTest.EXISTS)) {
                window.open_url (GLib.File.new_for_path (a).get_uri ());
            }
        }
        return 0;
    });
    
    return app.run (args);
}
