[CCode (cheader_filename = "lumiweb_core.h")]
namespace LumiWebCore {
    [CCode (cname = "lw_init")]
    public void lw_init ();

    [CCode (cname = "lw_add_history")]
    public void lw_add_history (string url, string title);

    [CCode (cname = "lw_get_history_html")]
    public unowned string lw_get_history_html ();

    [CCode (cname = "lw_free_string")]
    public void lw_free_string (string s);

    [CCode (cname = "lw_plugin_js")]
    public unowned string lw_plugin_js (string path, string current_url);

    [CCode (cname = "lw_plugin_css")]
    public unowned string lw_plugin_css (string path, string current_url);

    [CCode (cname = "lw_calendar_add")] public void lw_calendar_add (string date, string title, string description);
    [CCode (cname = "lw_calendar_list")] public unowned string lw_calendar_list ();
    [CCode (cname = "lw_calendar_delete")] public void lw_calendar_delete (int64 id);
    [CCode (cname = "lw_todo_add")] public void lw_todo_add (string title);
    [CCode (cname = "lw_todo_toggle")] public void lw_todo_toggle (int64 id);
    [CCode (cname = "lw_todo_delete")] public void lw_todo_delete (int64 id);
    [CCode (cname = "lw_todo_list")] public unowned string lw_todo_list ();
    [CCode (cname = "lw_notes_save")] public void lw_notes_save (string content);
    [CCode (cname = "lw_notes_load")] public unowned string lw_notes_load ();
    [CCode (cname = "lw_bookmark_add")] public void lw_bookmark_add (string url, string title);
    [CCode (cname = "lw_bookmark_delete")] public void lw_bookmark_delete (int64 id);
    [CCode (cname = "lw_bookmark_list")] public unowned string lw_bookmark_list ();
    [CCode (cname = "lw_workspace_add")] public void lw_workspace_add (string name, string urls_json);
    [CCode (cname = "lw_workspace_delete")] public void lw_workspace_delete (int64 id);
    [CCode (cname = "lw_workspace_list")] public unowned string lw_workspace_list ();
    [CCode (cname = "lw_download_log")] public void lw_download_log (string url, string path);
    [CCode (cname = "lw_download_list")] public unowned string lw_download_list ();
    [CCode (cname = "lw_plugin_notify")] public unowned string lw_plugin_notify (string path, string current_url);
}
