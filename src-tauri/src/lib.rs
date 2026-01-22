mod commands;
mod converter;

use commands::convert::{cancel_conversion, convert_file, get_media_duration};
use converter::ffmpeg;
use tauri::Manager;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![
            convert_file,
            get_media_duration,
            cancel_conversion
        ])
        .on_window_event(|window, event| {
            if let tauri::WindowEvent::CloseRequested { .. } = event {
                // Kill all running FFmpeg processes when window closes
                let handle = window.app_handle().clone();
                tauri::async_runtime::spawn(async move {
                    ffmpeg::kill_all_processes().await;
                    handle.exit(0);
                });
            }
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
