use std::process::Stdio;
use tauri::AppHandle;
use tokio::process::Command;

// Use system-installed ImageMagick
const MAGICK_PATH: &str = "/opt/homebrew/bin/magick";

/// Convert image using system ImageMagick
pub async fn convert(
    _app: &AppHandle,
    _file_id: &str,
    input_path: &str,
    output_path: &str,
) -> Result<String, String> {
    let output = Command::new(MAGICK_PATH)
        .args([
            "convert",
            input_path,
            // Auto-orient based on EXIF data
            "-auto-orient",
            // Strip metadata for smaller files
            "-strip",
            output_path,
        ])
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .await
        .map_err(|e| format!("Failed to execute ImageMagick: {}", e))?;

    if output.status.success() {
        Ok(output_path.to_string())
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr);
        Err(format!("ImageMagick conversion failed: {}", stderr))
    }
}
