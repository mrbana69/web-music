use sha1::{Digest, Sha1};
use std::fs::OpenOptions;
use std::io::Write;
use std::net::TcpStream;
use std::path::{Path, PathBuf};
use std::process::{Child, Command};
use std::sync::Mutex;
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use tauri::{AppHandle, Manager, WebviewUrl, WebviewWindowBuilder};

#[cfg(windows)]
use std::os::windows::process::CommandExt;

#[cfg(windows)]
const CREATE_NO_WINDOW: u32 = 0x08000000;

struct ServerState(Mutex<Option<Child>>);

#[derive(serde::Serialize, serde::Deserialize, Clone, Debug)]
pub struct AuthResponse {
    pub success: bool,
    pub cookie_string: Option<String>,
    pub sapisid: Option<String>,
    pub error: Option<String>,
}

fn log_msg(msg: &str) {
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs();
    let line = format!("[{}] [Preluded Desktop] {}\n", now, msg);
    print!("{}", line);

    // 1. Try logging next to the executable
    if let Ok(exe_path) = std::env::current_exe() {
        if let Some(parent) = exe_path.parent() {
            let log_file = parent.join("preluded.log");
            if let Ok(mut f) = OpenOptions::new().create(true).append(true).open(&log_file) {
                let _ = f.write_all(line.as_bytes());
            }
        }
    }

    // 2. Also try logging in current working directory
    let _ = OpenOptions::new()
        .create(true)
        .append(true)
        .open("preluded.log")
        .and_then(|mut f| f.write_all(line.as_bytes()));
}

fn is_server_alive() -> bool {
    let addr = "127.0.0.1:3000".parse().unwrap();
    TcpStream::connect_timeout(&addr, Duration::from_millis(200)).is_ok()
}

fn find_server_js() -> Option<PathBuf> {
    // 1. Check current directory
    if let Ok(cwd) = std::env::current_dir() {
        let p = cwd.join("server.js");
        if p.exists() {
            return Some(p);
        }
    }

    // 2. Search upwards from executable location
    if let Ok(exe_path) = std::env::current_exe() {
        let mut curr = exe_path.parent();
        for _ in 0..7 {
            if let Some(dir) = curr {
                let p = dir.join("server.js");
                if p.exists() {
                    return Some(p);
                }
                curr = dir.parent();
            }
        }
    }

    // 3. Fallback to default local dev workspace path
    let fallback = PathBuf::from(r"C:\Users\emiba\web-music\server.js");
    if fallback.exists() {
        return Some(fallback);
    }

    None
}

fn spawn_backend_server() -> Option<Child> {
    log_msg("=== Starting Preluded Desktop Application ===");
    log_msg("Checking if backend server is already listening on port 3000...");
    if is_server_alive() {
        log_msg("Backend server is already active on http://127.0.0.1:3000!");
        return None;
    }

    log_msg("Backend server not running. Locating server.js...");
    let server_path = match find_server_js() {
        Some(p) => {
            log_msg(&format!("Found server.js at: {:?}", p));
            p
        }
        None => {
            log_msg("WARNING: Could not find server.js in search paths.");
            return None;
        }
    };

    let working_dir = server_path.parent().unwrap_or_else(|| Path::new("."));
    log_msg(&format!("Spawning 'node server.js' from working dir: {:?}", working_dir));

    let mut cmd = Command::new("node");
    cmd.arg(&server_path);
    cmd.current_dir(working_dir);

    #[cfg(windows)]
    cmd.creation_flags(CREATE_NO_WINDOW);

    match cmd.spawn() {
        Ok(child) => {
            log_msg(&format!("Spawned backend process successfully (PID: {})", child.id()));
            log_msg("Waiting for http://127.0.0.1:3000 to become ready...");

            for attempt in 1..=25 {
                std::thread::sleep(Duration::from_millis(200));
                if is_server_alive() {
                    log_msg(&format!("Backend server responded successfully on attempt {} (http://127.0.0.1:3000 is READY)!", attempt));
                    return Some(child);
                }
            }
            log_msg("WARNING: Backend process started but port 3000 did not respond within 5s.");
            Some(child)
        }
        Err(e) => {
            log_msg(&format!("ERROR: Failed to spawn node process: {}. Is Node.js installed in PATH?", e));
            None
        }
    }
}

/// Computes authentic SAPISIDHASH header for YouTube Music (SimpMusic standard)
#[tauri::command]
fn get_sapisid_hash(sapisid: String, origin: Option<String>) -> String {
    let org = origin.unwrap_or_else(|| "https://music.youtube.com".to_string());
    let start = SystemTime::now();
    let since_the_epoch = start
        .duration_since(UNIX_EPOCH)
        .expect("Time went backwards");
    let timestamp = since_the_epoch.as_secs();

    let mut hasher = Sha1::new();
    let payload = format!("{} {} {}", timestamp, sapisid, org);
    hasher.update(payload.as_bytes());
    let result = hasher.finalize();
    let hex_str = hex::encode(result);

    format!("SAPISIDHASH {}_{}", timestamp, hex_str)
}

/// Opens an isolated Google/YouTube Music login Webview and intercepts cookies
#[tauri::command]
async fn open_google_login(app: AppHandle) -> Result<AuthResponse, String> {
    log_msg("Opening Google/YouTube Music login window...");
    let login_url = "https://accounts.google.com/ServiceLogin?service=youtube&continue=https%3A%2F%2Fmusic.youtube.com%2F";
    let window_label = "google-login";

    // Close any existing login window
    if let Some(existing_win) = app.get_webview_window(window_label) {
        let _ = existing_win.close();
    }

    let parsed_url = login_url.parse::<tauri::Url>().map_err(|e| e.to_string())?;

    let win = WebviewWindowBuilder::new(&app, window_label, WebviewUrl::External(parsed_url))
        .title("Accedi con Google - Preluded Desktop")
        .inner_size(620.0, 750.0)
        .resizable(true)
        .center()
        .build()
        .map_err(|e| e.to_string())?;

    let _ = win.show();
    log_msg("Google login window opened.");

    Ok(AuthResponse {
        success: true,
        cookie_string: None,
        sapisid: None,
        error: None,
    })
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let child_server = spawn_backend_server();

    tauri::Builder::default()
        .manage(ServerState(Mutex::new(child_server)))
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![
            get_sapisid_hash,
            open_google_login
        ])
        .on_window_event(|window, event| {
            if let tauri::WindowEvent::Destroyed = event {
                if window.label() == "main" {
                    log_msg("Main window closed. Terminating spawned backend process if any...");
                    let state = window.state::<ServerState>();
                    let mut lock = state.0.lock().unwrap();
                    if let Some(mut child) = lock.take() {
                        let _ = child.kill();
                        log_msg("Backend process terminated cleanly.");
                    }
                }
            }
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
