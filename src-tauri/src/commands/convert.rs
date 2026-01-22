use serde::{Deserialize, Serialize};
use tauri::{AppHandle, Emitter};

use crate::converter::{ffmpeg, imagemagick};

#[derive(Clone, Serialize, Deserialize)]
pub struct ConversionProgress {
    pub file_id: String,
    pub percent: f64,
    pub current_time: Option<f64>,
    pub total_duration: Option<f64>,
    pub fps: Option<f64>,
    pub frame: Option<u64>,
    pub speed: Option<f64>,
    pub eta_seconds: Option<f64>,
}

#[derive(Clone, Serialize, Deserialize)]
pub struct ConversionComplete {
    pub file_id: String,
    pub output_path: String,
}

#[derive(Clone, Serialize, Deserialize)]
pub struct ConversionError {
    pub file_id: String,
    pub message: String,
}

#[derive(Clone, Serialize, Deserialize)]
pub struct ConversionCancelled {
    pub file_id: String,
}

/// Get media duration using FFprobe
#[tauri::command]
pub async fn get_media_duration(app: AppHandle, input_path: String) -> Result<f64, String> {
    ffmpeg::get_duration(&app, &input_path).await
}

/// Cancel a running conversion
#[tauri::command]
pub async fn cancel_conversion(app: AppHandle, file_id: String) -> Result<(), String> {
    ffmpeg::cancel_process(&file_id).await?;

    let cancelled = ConversionCancelled {
        file_id: file_id.clone(),
    };
    let _ = app.emit("conversion:cancelled", cancelled);

    Ok(())
}

/// Main conversion command
#[tauri::command]
pub async fn convert_file(
    app: AppHandle,
    file_id: String,
    input_path: String,
    output_format: String,
    output_path: Option<String>,
) -> Result<String, String> {
    let input = std::path::Path::new(&input_path);

    if !input.exists() {
        let error = ConversionError {
            file_id: file_id.clone(),
            message: "Input file does not exist".to_string(),
        };
        let _ = app.emit("conversion:error", error);
        return Err("Input file does not exist".to_string());
    }

    // Determine output path
    let output = match output_path {
        Some(p) => std::path::PathBuf::from(p),
        None => {
            let parent = input.parent().unwrap_or(std::path::Path::new("."));
            let stem = input.file_stem().unwrap_or_default().to_string_lossy();
            parent.join(format!("{}.{}", stem, output_format))
        }
    };

    // Determine which converter to use based on format
    let result = match output_format.to_lowercase().as_str() {
        // Video formats - use FFmpeg
        "mp4" | "webm" | "mkv" | "avi" | "mov" | "gif" => {
            ffmpeg::convert(&app, &file_id, &input_path, output.to_str().unwrap(), &output_format).await
        }
        // Audio formats - use FFmpeg
        "mp3" | "wav" | "flac" | "aac" | "ogg" | "m4a" => {
            ffmpeg::convert(&app, &file_id, &input_path, output.to_str().unwrap(), &output_format).await
        }
        // Image formats - use ImageMagick
        "png" | "jpg" | "jpeg" | "webp" | "bmp" | "tiff" | "pdf" => {
            imagemagick::convert(&app, &file_id, &input_path, output.to_str().unwrap()).await
        }
        _ => Err(format!("Unsupported output format: {}", output_format)),
    };

    match result {
        Ok(output_path) => {
            let complete = ConversionComplete {
                file_id: file_id.clone(),
                output_path: output_path.clone(),
            };
            let _ = app.emit("conversion:complete", complete);
            Ok(output_path)
        }
        Err(e) => {
            // Don't emit error for cancellation
            if !e.contains("cancelled") {
                let error = ConversionError {
                    file_id: file_id.clone(),
                    message: e.clone(),
                };
                let _ = app.emit("conversion:error", error);
            }
            Err(e)
        }
    }
}
