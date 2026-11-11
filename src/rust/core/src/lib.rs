use std::ffi::{CStr, CString};
use mlua::Lua;
use std::os::raw::c_char;
use std::path::PathBuf;
use std::sync::OnceLock;
use rusqlite::{Connection, params};

static DB_PATH: OnceLock<PathBuf> = OnceLock::new();

#[no_mangle]
pub extern "C" fn lw_init() {
    let mut path = dirs::config_dir().unwrap_or_else(|| PathBuf::from("."));
    path.push("lumiweb");
    std::fs::create_dir_all(&path).unwrap();
    path.push("lumiweb.db");
    
    let conn = Connection::open(&path).unwrap();
    conn.execute(
        "CREATE TABLE IF NOT EXISTS history (
            id INTEGER PRIMARY KEY,
            url TEXT NOT NULL,
            title TEXT NOT NULL,
            timestamp TEXT NOT NULL
        )",
        [],
    ).unwrap();
    
    let _ = DB_PATH.set(path);
}

fn get_conn() -> Connection {
    let path = DB_PATH.get().expect("DB not initialized");
    Connection::open(path).unwrap()
}

#[no_mangle]
pub extern "C" fn lw_add_history(url_ptr: *const c_char, title_ptr: *const c_char) {
    if url_ptr.is_null() || title_ptr.is_null() { return; }
    let url = unsafe { CStr::from_ptr(url_ptr) }.to_string_lossy().into_owned();
    let title = unsafe { CStr::from_ptr(title_ptr) }.to_string_lossy().into_owned();
    let timestamp = chrono::Local::now().to_rfc3339();
    
    let conn = get_conn();
    conn.execute(
        "INSERT INTO history (url, title, timestamp) VALUES (?1, ?2, ?3)",
        params![url, title, timestamp],
    ).unwrap_or_default();
}

#[no_mangle]
pub extern "C" fn lw_get_history_html() -> *mut c_char {
    let conn = get_conn();
    let mut stmt = conn.prepare("SELECT url, title, timestamp FROM history ORDER BY id DESC LIMIT 150").unwrap();
    let entries_iter = stmt.query_map([], |row| {
        Ok((
            row.get::<_, String>(0)?,
            row.get::<_, String>(1)?,
            row.get::<_, String>(2)?,
        ))
    }).unwrap();

    let mut html = String::from(r#"<html><head><meta charset="utf-8"><style>
        body { background: #121212; color: #eee; font-family: sans-serif; padding: 20px; }
        h2 { color: #4a90e2; }
        a { color: #4a90e2; text-decoration: none; font-size: 18px; }
        a:hover { text-decoration: underline; }
        .item { padding: 12px; border-bottom: 1px solid #333; }
        .time { font-size: 12px; color: #888; }
    </style></head><body><h2>Historia przeglądania (LumiWeb)</h2>"#);

    for entry in entries_iter.filter_map(Result::ok) {
        let (url, title, time) = entry;
        let display_title = if title.trim().is_empty() { url.clone() } else { title };
        html.push_str(&format!("<div class='item'><a href='{}'>{}</a><br><span class='time'>{}</span></div>", url, display_title, time));
    }
    html.push_str("</body></html>");
    
    CString::new(html).unwrap().into_raw()
}

#[no_mangle]
pub extern "C" fn lw_free_string(s: *mut c_char) {
    if s.is_null() { return; }
    unsafe { let _ = CString::from_raw(s); }
}


// ==================== LUA PLUGIN SUPPORT ====================
use std::cell::RefCell;
use std::rc::Rc;

fn eval_plugin(path: &str, current_url: &str) -> (Vec<String>, Vec<String>) {
    let (j, c, _) = eval_plugin_full(path, current_url);
    (j, c)
}

fn eval_plugin_full(path: &str, current_url: &str) -> (Vec<String>, Vec<String>, Vec<String>) {
    let lua = Lua::new();
    let js_bag: Rc<RefCell<Vec<String>>> = Rc::new(RefCell::new(Vec::new()));
    let css_bag: Rc<RefCell<Vec<String>>> = Rc::new(RefCell::new(Vec::new()));
    let notif_bag: Rc<RefCell<Vec<String>>> = Rc::new(RefCell::new(Vec::new()));

    let js_clone = js_bag.clone();
    let _ = lua.globals().set("js", lua.create_function(move |_, code: String| {
        js_clone.borrow_mut().push(code);
        Ok(())
    }).unwrap());

    let css_clone = css_bag.clone();
    let _ = lua.globals().set("css", lua.create_function(move |_, code: String| {
        css_clone.borrow_mut().push(code);
        Ok(())
    }).unwrap());

    let url_clone = current_url.to_string();
    let _ = lua.globals().set("url", lua.create_function(move |_, ()| {
        Ok(url_clone.clone())
    }).unwrap());
    
    // notify() - wysyła powiadomienie do hosta
    let notif_clone = notif_bag.clone();
    let _ = lua.globals().set("notify", lua.create_function(move |_, msg: String| {
        notif_clone.borrow_mut().push(msg);
        Ok(())
    }).unwrap());

    if let Ok(script) = std::fs::read_to_string(path) {
        if let Err(e) = lua.load(&script).exec() {
            eprintln!("[LUA] Error in {}: {}", path, e);
        }
    }

    let js_out = js_bag.borrow().clone();
    let css_out = css_bag.borrow().clone();
    let notif_out = notif_bag.borrow().clone();
    (js_out, css_out, notif_out)
}

#[no_mangle]
pub extern "C" fn lw_plugin_js(path_ptr: *const c_char, url_ptr: *const c_char) -> *mut c_char {
    if path_ptr.is_null() { return CString::new("").unwrap().into_raw(); }
    let path = unsafe { CStr::from_ptr(path_ptr) }.to_string_lossy().into_owned();
    let url = if url_ptr.is_null() { String::new() } else { unsafe { CStr::from_ptr(url_ptr) }.to_string_lossy().into_owned() };
    let (js, _) = eval_plugin(&path, &url);
    CString::new(js.join("\n;\n")).unwrap_or_else(|_| CString::new("").unwrap()).into_raw()
}

#[no_mangle]
pub extern "C" fn lw_plugin_css(path_ptr: *const c_char, url_ptr: *const c_char) -> *mut c_char {
    if path_ptr.is_null() { return CString::new("").unwrap().into_raw(); }
    let path = unsafe { CStr::from_ptr(path_ptr) }.to_string_lossy().into_owned();
    let url = if url_ptr.is_null() { String::new() } else { unsafe { CStr::from_ptr(url_ptr) }.to_string_lossy().into_owned() };
    let (_, css) = eval_plugin(&path, &url);
    CString::new(css.join("\n")).unwrap_or_else(|_| CString::new("").unwrap()).into_raw()
}


// ==================== KALENDARZ / TODO / NOTATKI ====================
fn ensure_tables(conn: &Connection) {
    conn.execute("CREATE TABLE IF NOT EXISTS calendar (
        id INTEGER PRIMARY KEY, date TEXT, title TEXT, description TEXT)", []).ok();
    conn.execute("CREATE TABLE IF NOT EXISTS todos (
        id INTEGER PRIMARY KEY, title TEXT, done INTEGER DEFAULT 0)", []).ok();
    conn.execute("CREATE TABLE IF NOT EXISTS notes (
        id INTEGER PRIMARY KEY, content TEXT)", []).ok();
}

#[no_mangle]
pub extern "C" fn lw_calendar_add(date_p: *const c_char, title_p: *const c_char, desc_p: *const c_char) {
    if date_p.is_null() || title_p.is_null() { return; }
    let date = unsafe { CStr::from_ptr(date_p) }.to_string_lossy().into_owned();
    let title = unsafe { CStr::from_ptr(title_p) }.to_string_lossy().into_owned();
    let desc = if desc_p.is_null() { String::new() } else { unsafe { CStr::from_ptr(desc_p) }.to_string_lossy().into_owned() };
    let conn = get_conn();
    ensure_tables(&conn);
    conn.execute("INSERT INTO calendar (date, title, description) VALUES (?1,?2,?3)", params![date, title, desc]).ok();
}

#[no_mangle]
pub extern "C" fn lw_calendar_list() -> *mut c_char {
    let conn = get_conn();
    ensure_tables(&conn);
    let mut stmt = conn.prepare("SELECT id, date, title, description FROM calendar ORDER BY date").unwrap();
    let rows: Vec<(i64,String,String,String)> = stmt.query_map([], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?, r.get(3)?))).unwrap().filter_map(Result::ok).collect();
    let json = serde_json::to_string(&rows).unwrap_or_else(|_| "[]".into());
    CString::new(json).unwrap().into_raw()
}

#[no_mangle]
pub extern "C" fn lw_calendar_delete(id: i64) {
    let conn = get_conn();
    ensure_tables(&conn);
    conn.execute("DELETE FROM calendar WHERE id=?1", params![id]).ok();
}

#[no_mangle]
pub extern "C" fn lw_todo_add(title_p: *const c_char) {
    if title_p.is_null() { return; }
    let title = unsafe { CStr::from_ptr(title_p) }.to_string_lossy().into_owned();
    let conn = get_conn();
    ensure_tables(&conn);
    conn.execute("INSERT INTO todos (title) VALUES (?1)", params![title]).ok();
}

#[no_mangle]
pub extern "C" fn lw_todo_toggle(id: i64) {
    let conn = get_conn();
    ensure_tables(&conn);
    conn.execute("UPDATE todos SET done = 1 - done WHERE id=?1", params![id]).ok();
}

#[no_mangle]
pub extern "C" fn lw_todo_delete(id: i64) {
    let conn = get_conn();
    ensure_tables(&conn);
    conn.execute("DELETE FROM todos WHERE id=?1", params![id]).ok();
}

#[no_mangle]
pub extern "C" fn lw_todo_list() -> *mut c_char {
    let conn = get_conn();
    ensure_tables(&conn);
    let mut stmt = conn.prepare("SELECT id, title, done FROM todos ORDER BY id").unwrap();
    let rows: Vec<(i64,String,i64)> = stmt.query_map([], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?))).unwrap().filter_map(Result::ok).collect();
    let json = serde_json::to_string(&rows).unwrap_or_else(|_| "[]".into());
    CString::new(json).unwrap().into_raw()
}

#[no_mangle]
pub extern "C" fn lw_notes_save(content_p: *const c_char) {
    let content = if content_p.is_null() { String::new() } else { unsafe { CStr::from_ptr(content_p) }.to_string_lossy().into_owned() };
    let conn = get_conn();
    ensure_tables(&conn);
    conn.execute("DELETE FROM notes", []).ok();
    conn.execute("INSERT INTO notes (content) VALUES (?1)", params![content]).ok();
}

#[no_mangle]
pub extern "C" fn lw_notes_load() -> *mut c_char {
    let conn = get_conn();
    ensure_tables(&conn);
    let result: Result<String, _> = conn.query_row("SELECT content FROM notes LIMIT 1", [], |r| r.get(0));
    let content = result.unwrap_or_default();
    CString::new(content).unwrap_or_else(|_| CString::new("").unwrap()).into_raw()
}


// ==================== BOOKMARKS ====================
#[no_mangle]
pub extern "C" fn lw_bookmark_add(url_p: *const c_char, title_p: *const c_char) {
    if url_p.is_null() { return; }
    let url = unsafe { CStr::from_ptr(url_p) }.to_string_lossy().into_owned();
    let title = if title_p.is_null() { String::new() }
                else { unsafe { CStr::from_ptr(title_p) }.to_string_lossy().into_owned() };
    let conn = get_conn();
    conn.execute("CREATE TABLE IF NOT EXISTS bookmarks (
        id INTEGER PRIMARY KEY, url TEXT, title TEXT, ts TEXT)", []).ok();
    conn.execute("INSERT INTO bookmarks (url, title, ts) VALUES (?1,?2,?3)",
        params![url, title, chrono::Local::now().to_rfc3339()]).ok();
}

#[no_mangle]
pub extern "C" fn lw_bookmark_delete(id: i64) {
    let conn = get_conn();
    conn.execute("DELETE FROM bookmarks WHERE id=?1", params![id]).ok();
}

#[no_mangle]
pub extern "C" fn lw_bookmark_list() -> *mut c_char {
    let conn = get_conn();
    conn.execute("CREATE TABLE IF NOT EXISTS bookmarks (
        id INTEGER PRIMARY KEY, url TEXT, title TEXT, ts TEXT)", []).ok();
    let mut stmt = conn.prepare("SELECT id, url, title FROM bookmarks ORDER BY ts DESC").unwrap();
    let rows: Vec<(i64,String,String)> = stmt.query_map([], |r|
        Ok((r.get(0)?, r.get(1)?, r.get(2)?))).unwrap().filter_map(Result::ok).collect();
    let json = serde_json::to_string(&rows).unwrap_or_else(|_| "[]".into());
    CString::new(json).unwrap().into_raw()
}


// ==================== WORKSPACES ====================
#[no_mangle]
pub extern "C" fn lw_workspace_add(name_p: *const c_char, urls_json_p: *const c_char) {
    if name_p.is_null() { return; }
    let name = unsafe { CStr::from_ptr(name_p) }.to_string_lossy().into_owned();
    let urls = if urls_json_p.is_null() { String::from("[]") }
               else { unsafe { CStr::from_ptr(urls_json_p) }.to_string_lossy().into_owned() };
    let conn = get_conn();
    conn.execute("CREATE TABLE IF NOT EXISTS workspaces (
        id INTEGER PRIMARY KEY, name TEXT, urls TEXT)", []).ok();
    conn.execute("INSERT INTO workspaces (name, urls) VALUES (?1,?2)",
        params![name, urls]).ok();
}

#[no_mangle]
pub extern "C" fn lw_workspace_delete(id: i64) {
    let conn = get_conn();
    conn.execute("DELETE FROM workspaces WHERE id=?1", params![id]).ok();
}

#[no_mangle]
pub extern "C" fn lw_workspace_list() -> *mut c_char {
    let conn = get_conn();
    conn.execute("CREATE TABLE IF NOT EXISTS workspaces (
        id INTEGER PRIMARY KEY, name TEXT, urls TEXT)", []).ok();
    let mut stmt = conn.prepare("SELECT id, name, urls FROM workspaces ORDER BY id DESC").unwrap();
    let rows: Vec<(i64,String,String)> = stmt.query_map([], |r|
        Ok((r.get(0)?, r.get(1)?, r.get(2)?))).unwrap().filter_map(Result::ok).collect();
    let json = serde_json::to_string(&rows).unwrap_or_else(|_| "[]".into());
    CString::new(json).unwrap().into_raw()
}

// ==================== DOWNLOADS ====================
#[no_mangle]
pub extern "C" fn lw_download_log(url_p: *const c_char, path_p: *const c_char) {
    let url = if url_p.is_null() { String::new() }
              else { unsafe { CStr::from_ptr(url_p) }.to_string_lossy().into_owned() };
    let path = if path_p.is_null() { String::new() }
               else { unsafe { CStr::from_ptr(path_p) }.to_string_lossy().into_owned() };
    let conn = get_conn();
    conn.execute("CREATE TABLE IF NOT EXISTS downloads (
        id INTEGER PRIMARY KEY, url TEXT, path TEXT, ts TEXT)", []).ok();
    conn.execute("INSERT INTO downloads (url, path, ts) VALUES (?1,?2,?3)",
        params![url, path, chrono::Local::now().to_rfc3339()]).ok();
}

#[no_mangle]
pub extern "C" fn lw_download_list() -> *mut c_char {
    let conn = get_conn();
    conn.execute("CREATE TABLE IF NOT EXISTS downloads (
        id INTEGER PRIMARY KEY, url TEXT, path TEXT, ts TEXT)", []).ok();
    let mut stmt = conn.prepare("SELECT id, url, path, ts FROM downloads ORDER BY id DESC LIMIT 100").unwrap();
    let rows: Vec<(i64,String,String,String)> = stmt.query_map([], |r|
        Ok((r.get(0)?, r.get(1)?, r.get(2)?, r.get(3)?))).unwrap().filter_map(Result::ok).collect();
    let json = serde_json::to_string(&rows).unwrap_or_else(|_| "[]".into());
    CString::new(json).unwrap().into_raw()
}


#[no_mangle]
pub extern "C" fn lw_plugin_notify(path_ptr: *const c_char, url_ptr: *const c_char) -> *mut c_char {
    if path_ptr.is_null() { return CString::new("").unwrap().into_raw(); }
    let path = unsafe { CStr::from_ptr(path_ptr) }.to_string_lossy().into_owned();
    let url = if url_ptr.is_null() { String::new() }
              else { unsafe { CStr::from_ptr(url_ptr) }.to_string_lossy().into_owned() };
    let (_, _, notifs) = eval_plugin_full(&path, &url);
    CString::new(notifs.join("\n")).unwrap_or_else(|_| CString::new("").unwrap()).into_raw()
}
