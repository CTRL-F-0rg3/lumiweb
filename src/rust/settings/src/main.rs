use eframe::egui;
use std::fs;
use std::path::PathBuf;
use std::process::Command;

struct SettingsApp {
    active_tab: usize,
    zoom_level: f32,
    block_ads: bool,
    // Zmienne motywu
    top_bar_gradient: String,
    sidebar_bg: String,
    text_color: String,
    search_engine: String,
}

impl Default for SettingsApp {
    fn default() -> Self {
        Self {
            active_tab: 0,
            zoom_level: 1.0,
            block_ads: true,
            top_bar_gradient: "linear-gradient(135deg, #1a0b2e 0%, #2d0a4e 50%, #4a154b 100%)".to_string(),
            sidebar_bg: "#120a1c".to_string(),
            text_color: "#ffffff".to_string(),
            search_engine: Self::load_search_engine(),
        }
    }
}

impl SettingsApp {
    fn load_search_engine() -> String {
        let path = Self::config_path().join("search.txt");
        fs::read_to_string(&path)
            .map(|s| s.trim().to_string())
            .unwrap_or_else(|_| "google".to_string())
    }

    fn save_search_engine(&self) {
        let path = Self::config_path().join("search.txt");
        fs::write(path, &self.search_engine).ok();
    }

    fn config_path() -> PathBuf {
        let mut path = dirs::config_dir().unwrap_or_else(|| PathBuf::from("."));
        path.push("lumiweb");
        fs::create_dir_all(&path).unwrap_or_default();
        path
    }

    fn save_theme(&self) {
        let lua_content = format!(r##"-- LumiWeb Theme Configuration
theme = {{
    name = "Custom Theme",
    top_bar_gradient = "{}",
    sidebar_bg = "{}",
    text_color = "{}",
    tab_bg = "rgba(255, 255, 255, 0.1)",
    tab_active_bg = "rgba(255, 255, 255, 0.2)",
    window_controls_color = "{}"
}}"##, self.top_bar_gradient, self.sidebar_bg, self.text_color, self.text_color);

        let theme_path = Self::config_path().join("theme.lua");
        fs::write(theme_path, lua_content).expect("Nie udało się zapisać theme.lua");

        // Uruchamiamy silnik motywów (w tle)
        let engine_path = PathBuf::from("./src/rust/theme_engine/target/debug/theme_engine");
        let _ = Command::new(engine_path).spawn();
    }
}

impl eframe::App for SettingsApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        egui::SidePanel::left("tabs").show(ctx, |ui| {
            ui.heading("LumiWeb");
            ui.separator();
            ui.selectable_value(&mut self.active_tab, 0, "Ogólne");
            ui.selectable_value(&mut self.active_tab, 1, "Motyw (Lua)");
            ui.selectable_value(&mut self.active_tab, 2, "Mody");
            ui.selectable_value(&mut self.active_tab, 3, "Pluginy");
            ui.selectable_value(&mut self.active_tab, 4, "Wyszukiwarka");
        });

        egui::CentralPanel::default().show(ctx, |ui| {
            match self.active_tab {
                0 => {
                    ui.heading("Ustawienia ogólne");
                    ui.separator();
                    ui.add(egui::Slider::new(&mut self.zoom_level, 0.5..=2.0).text("Powiększenie"));
                    ui.checkbox(&mut self.block_ads, "Blokuj reklamy");
                }
                1 => {
                    ui.heading("Kalibracja Motywu");
                    ui.label("Wpisz wartość CSS lub skorzystaj z palety:");
                    
                    ui.horizontal(|ui| {
                        ui.label("Górny pasek (Gradient):");
                        ui.text_edit_singleline(&mut self.top_bar_gradient);
                    });
                    
                    ui.horizontal(|ui| {
                        ui.label("Tło paska bocznego:");
                        ui.text_edit_singleline(&mut self.sidebar_bg);
                    });

                    ui.horizontal(|ui| {
                        ui.label("Kolor tekstu:");
                        ui.text_edit_singleline(&mut self.text_color);
                    });

                    ui.add_space(20.0);
                    if ui.button("💾 Zapisz motyw i odśwież przeglądarkę").clicked() {
                        self.save_theme();
                    }
                }
                2 => {
                    ui.heading("Mody (Wygląd)");
                    ui.label("Umieść pliki .css w ~/.config/lumiweb/mods/");
                    ui.separator();
                    ui.label("(Lista modów pojawi się tutaj)");
                }
                3 => {
                    ui.heading("Pluginy (Automatyzacja)");
                    ui.label("Umieść pliki .js/.lua w ~/.config/lumiweb/plugins/");
                    ui.separator();
                    ui.label("(Lista pluginów pojawi się tutaj)");
                }
                4 => {
                    ui.heading("Preferowana wyszukiwarka");
                    ui.separator();
                    ui.label("Wybierz domyślną wyszukiwarkę:");
                    ui.add_space(10.0);
                    
                    let engines = [
                        ("google", "Google"),
                        ("duckduckgo", "DuckDuckGo"),
                        ("bing", "Bing"),
                        ("brave", "Brave Search"),
                        ("startpage", "Startpage"),
                    ];
                    
                    for (key, name) in engines {
                        if ui.radio(self.search_engine == key, name).clicked() {
                            self.search_engine = key.to_string();
                            self.save_search_engine();
                        }
                    }
                }
                _ => {}
            }
        });
    }
}

fn main() -> eframe::Result<()> {
    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_inner_size([600.0, 400.0])
            .with_title("LumiWeb - Ustawienia"),
        ..Default::default()
    };
    eframe::run_native(
        "LumiWeb Settings",
        options,
        Box::new(|_cc| Box::new(SettingsApp::default())),
    )
}
