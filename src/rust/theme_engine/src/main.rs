use mlua::Lua;
use std::fs;
use std::path::PathBuf;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut config_dir = dirs::config_dir().unwrap_or_else(|| PathBuf::from("."));
    config_dir.push("lumiweb");
    fs::create_dir_all(&config_dir)?;

    let lua_path = config_dir.join("theme.lua");
    let css_path = config_dir.join("theme.css");

    if !lua_path.exists() {
        let default = r##"
theme = {
    name = "Cosmic Purple",
    top_bar_gradient = "linear-gradient(135deg, #1a0b2e 0%, #2d0a4e 50%, #4a154b 100%)",
    sidebar_bg = "#120a1c",
    text_color = "#ffffff"
}
"##;
        fs::write(&lua_path, default)?;
    }

    let lua = Lua::new();
    lua.load(&fs::read_to_string(&lua_path)?).exec()?;
    let theme: mlua::Table = lua.globals().get("theme")?;

    let sidebar_bg: String = theme.get("sidebar_bg").unwrap_or("#161616".to_string());
    let text_color: String = theme.get("text_color").unwrap_or("#ffffff".to_string());

    // Tło galaktyki (Unsplash, darmowa licencja)
    let galaxy_url = "https://images.unsplash.com/photo-1462331940025-496dfbfc7564?w=1600&q=80";

    let css = format!(r##"
window {{ background-color: transparent; }}

.main-window-bg {{
    background-color: #0d0d0d;
    border-radius: 10px;
    border: 1px solid #2a2a2a;
}}

.custom-titlebar {{
    background-image: linear-gradient(135deg, rgba(26,11,46,0.85) 0%, rgba(45,10,78,0.85) 50%, rgba(74,21,75,0.85) 100%), url('{galaxy}');
    background-size: cover;
    background-position: center;
    border-bottom: 1px solid #222222;
    border-radius: 10px 10px 0 0;
}}

button.mac-close, button.mac-min, button.mac-max {{
    min-width: 14px; min-height: 14px;
    border-radius: 50%; padding: 0; margin: 0; border: none;
    background-color: transparent;
}}
button.mac-close {{ background-color: #ff5f56; }}
button.mac-min   {{ background-color: #ffbd2e; }}
button.mac-max   {{ background-color: #27c93f; }}
button.mac-close image, button.mac-min image, button.mac-max image {{
    opacity: 0; color: rgba(0,0,0,0.6); -gtk-icon-size: 10px;
}}
button.mac-close:hover image,
button.mac-min:hover image,
button.mac-max:hover image {{ opacity: 1; }}

.nav-btn {{
    background: transparent; border: none; color: #cccccc;
    border-radius: 6px; min-width: 28px; min-height: 28px; padding: 2px;
}}
.nav-btn:hover {{ background-color: rgba(255,255,255,0.18); color: #ffffff; }}

.sidebar {{
    background-color: {sidebar};
    border-right: 1px solid #222222;
    border-radius: 0 0 0 10px;
}}
.sidebar-icon-btn {{
    background: transparent; border: none; color: #777777;
    border-radius: 8px; padding: 0; min-width: 32px; min-height: 32px;
}}
.sidebar-icon-btn:hover {{ background-color: #2a2a2a; }}
.sidebar-icon-btn.active-tab {{
    background-color: #2a2a2a;
    border-left: 3px solid #4a90e2;
}}

.top-url-bar {{
    background-color: rgba(0,0,0,0.5); color: {text};
    border-radius: 6px; border: 1px solid rgba(255,255,255,0.1);
    padding: 2px 10px; min-height: 24px; font-size: 12px;
}}
.top-url-bar:focus {{
    background-color: rgba(0,0,0,0.7);
    border-color: #4a90e2;
}}

.home-screen {{
    background-image: url('file://{galaxy_path}');
    background-size: cover;
    background-position: center;
    background-color: #0a0a1a;
}}
.home-glass {{
    background-color: rgba(20, 10, 40, 0.35);
    border-radius: 24px;
    border: 1px solid rgba(255, 255, 255, 0.2);
    box-shadow: 0 8px 32px rgba(74, 144, 226, 0.4),
                inset 0 1px 0 rgba(255, 255, 255, 0.2);
    padding-top: 50px;
    padding-bottom: 50px;
    padding-left: 70px;
    padding-right: 70px;
}}
.logo-text {{
    font-size: 52px; font-weight: 800; color: {text};
    letter-spacing: 1px;
    text-shadow: 0 0 15px rgba(74,144,226,0.4);
}}
.home-search-container {{
    background-color: #222222; border-radius: 20px;
    padding: 2px 6px; border: 1px solid #333333;
}}
.home-search-entry {{
    background: transparent; border: none; color: {text};
    font-size: 14px; margin-left: 8px;
}}

.edge-handle-btn {{
    background-color: rgba(34,34,34,0.9); color: #888888;
    border-radius: 8px 0 0 8px; border: 1px solid #444;
    border-right: none; min-width: 16px; min-height: 64px; padding: 0;
}}
.edge-handle-btn:hover {{ background-color: #333333; color: #ffffff; }}

.url-progress {{
    min-height: 3px;
    background: transparent;
}}
.url-progress trough {{
    background: rgba(0, 0, 0, 0.3);
    border-radius: 0;
    min-height: 3px;
}}
.url-progress progress {{
    background: linear-gradient(90deg, #6a4bc4, #4a90e2);
    border-radius: 0;
    min-height: 3px;
    box-shadow: 0 0 10px rgba(74, 144, 226, 0.8);
}}
.find-bar {{
    background: rgba(20, 15, 35, 0.95);
    border: 1px solid rgba(150, 190, 255, 0.3);
    border-radius: 10px;
    padding: 4px 8px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.4);
}}
.find-entry {{
    background: rgba(255, 255, 255, 0.08);
    border: 1px solid rgba(255, 255, 255, 0.15);
    border-radius: 6px;
    padding: 4px 10px;
    color: #ffffff;
}}
.find-btn {{
    background: transparent;
    border: none;
    color: #888;
    border-radius: 6px;
    min-width: 28px;
    min-height: 28px;
    padding: 2px;
}}
.find-btn:hover {{
    background: rgba(74, 144, 226, 0.3);
    color: #fff;
}}

.ctx-menu {{
    background: rgba(20, 15, 35, 0.98);
    border: 1px solid rgba(150, 190, 255, 0.3);
    border-radius: 10px;
    padding: 6px;
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.6);
    min-width: 220px;
}}
.ctx-btn {{
    background: transparent;
    border: none;
    color: #e0e0ff;
    border-radius: 6px;
    padding: 8px 12px;
}}
.ctx-btn:hover {{
    background: rgba(74, 144, 226, 0.3);
    color: #ffffff;
}}
.download-url {{ color: #c8d8ff; font-size: 13px; }}
.download-path {{ color: #888; font-size: 11px; }}

.bookmark-open-btn {{
    background: transparent; border: none; padding: 4px 8px;
    color: #e0e0e0; border-radius: 6px;
}}
.bookmark-open-btn:hover {{
    background: rgba(74, 144, 226, 0.2); color: #fff;
}}

.popup-window {{
    background-color: #121212;
    border-radius: 12px;
    border: 1px solid #2a2a2a;
}}
.window-title-label {{
    color: #c8d8ff;
    font-size: 13px;
    font-weight: 600;
}}
.window-close-flat {{
    background: transparent;
    border: none;
    color: #888;
    border-radius: 6px;
    min-width: 24px;
    min-height: 24px;
    padding: 0;
    margin-right: 8px;
}}
.window-close-flat:hover {{
    background: rgba(255, 60, 60, 0.3);
    color: #ff6060;
}}
/* Nowe widoki */
.section-title {{
    font-size: 28px;
    font-weight: 700;
    color: #ffffff;
    text-shadow: 0 0 20px rgba(74, 144, 226, 0.4);
    margin-bottom: 16px;
}}
.form-entry {{
    background-color: rgba(255, 255, 255, 0.08);
    border: 1px solid rgba(255, 255, 255, 0.15);
    border-radius: 10px;
    padding: 8px 14px;
    color: #ffffff;
    font-size: 14px;
    min-height: 24px;
}}
.form-entry:focus {{
    border-color: #4a90e2;
    background-color: rgba(255, 255, 255, 0.12);
}}
.action-btn {{
    background: linear-gradient(135deg, #6a4bc4, #4a90e2);
    color: #ffffff;
    border: none;
    border-radius: 10px;
    padding: 8px 20px;
    font-weight: 600;
    font-size: 14px;
    transition: 0.2s;
}}
.action-btn:hover {{
    background: linear-gradient(135deg, #7a5bd4, #5aa0f2);
    box-shadow: 0 0 16px rgba(74, 144, 226, 0.6);
}}
.list-item {{
    background-color: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 10px;
    padding: 10px 14px;
    color: #e0e0e0;
}}
.list-item:hover {{
    background-color: rgba(255, 255, 255, 0.09);
}}
.del-btn {{
    background: transparent;
    border: none;
    color: #888;
    border-radius: 6px;
    padding: 4px;
    min-width: 24px;
    min-height: 24px;
}}
.del-btn:hover {{
    background: rgba(255, 60, 60, 0.2);
    color: #ff6060;
}}
.done-text {{
    color: #666;
    text-decoration: line-through;
}}
.notes-text {{
    background-color: rgba(255, 255, 255, 0.04);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 12px;
    padding: 14px;
    color: #e8e8e8;
    font-size: 15px;
    font-family: monospace;
}}
textview > text {{
    background: transparent;
}}
/* Audio panel (pływający) */
.audio-panel {{
    background: rgba(20, 10, 40, 0.85);
    border: 1px solid rgba(150, 190, 255, 0.3);
    border-radius: 14px;
    padding: 10px 14px;
    box-shadow: 0 8px 32px rgba(74, 144, 226, 0.4), inset 0 1px 0 rgba(255,255,255,0.2);
    backdrop-filter: blur(10px);
    min-width: 240px;
}}
.audio-title {{
    color: #c8d8ff;
    font-size: 12px;
    font-weight: 600;
    letter-spacing: 0.5px;
    margin-bottom: 4px;
}}
.audio-row {{
    padding: 4px 0;
}}
.audio-row label {{
    color: #e0e0ff;
    font-size: 13px;
}}
.audio-btn {{
    background: rgba(74, 144, 226, 0.2);
    border: 1px solid rgba(74, 144, 226, 0.4);
    color: #8fc0ff;
    border-radius: 8px;
    min-width: 28px;
    min-height: 28px;
    padding: 4px;
}}
.audio-btn:hover {{
    background: rgba(74, 144, 226, 0.5);
    color: #ffffff;
}}
"##,

    galaxy = galaxy_url,
    sidebar = sidebar_bg,
    text = text_color,
    galaxy_path = format!("file://{}", dirs::home_dir().unwrap_or_default().join(".config/lumiweb/galaxy.jpg").display())
    );

    fs::write(&css_path, css)?;
    println!("✅ Motyw wygenerowany z tłem galaktyki.");
    Ok(())
}
