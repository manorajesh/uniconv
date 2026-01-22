use regex::Regex;
use std::collections::HashMap;
use std::process::Stdio;
use std::sync::Arc;
use tauri::{AppHandle, Emitter};
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::process::{Child, Command};
use tokio::sync::Mutex;

use crate::commands::convert::ConversionProgress;

// Use system-installed FFmpeg
const FFMPEG_PATH: &str = "/opt/homebrew/bin/ffmpeg";

// Global process tracker
lazy_static::lazy_static! {
    pub static ref RUNNING_PROCESSES: Arc<Mutex<HashMap<String, Child>>> = Arc::new(Mutex::new(HashMap::new()));
}

/// Kill all running FFmpeg processes (called on app quit)
pub async fn kill_all_processes() {
    let mut processes = RUNNING_PROCESSES.lock().await;
    for (file_id, mut child) in processes.drain() {
        eprintln!("Killing FFmpeg process for file: {}", file_id);
        let _ = child.kill().await;
    }
}

/// Cancel a specific conversion
pub async fn cancel_process(file_id: &str) -> Result<(), String> {
    let mut processes = RUNNING_PROCESSES.lock().await;
    if let Some(mut child) = processes.remove(file_id) {
        child.kill().await.map_err(|e| format!("Failed to kill process: {}", e))?;
        Ok(())
    } else {
        Err("No running conversion found for this file".to_string())
    }
}

/// Parse FFmpeg progress output
#[derive(Default)]
pub struct FFmpegProgress {
    pub time: Option<f64>,
    pub frame: Option<u64>,
    pub fps: Option<f64>,
    pub speed: Option<f64>,
    pub bitrate: Option<String>,
}

/// Parse FFmpeg progress output to extract all metrics
pub fn parse_progress_line(line: &str) -> FFmpegProgress {
    let mut progress = FFmpegProgress::default();

    // Parse time=00:01:23.45 or time=83.45
    if let Some(caps) = Regex::new(r"time=(\d{2}):(\d{2}):(\d{2})\.(\d{2})")
        .ok()
        .and_then(|re| re.captures(line))
    {
        let hours: f64 = caps.get(1).unwrap().as_str().parse().unwrap_or(0.0);
        let minutes: f64 = caps.get(2).unwrap().as_str().parse().unwrap_or(0.0);
        let seconds: f64 = caps.get(3).unwrap().as_str().parse().unwrap_or(0.0);
        let centiseconds: f64 = caps.get(4).unwrap().as_str().parse().unwrap_or(0.0);
        progress.time = Some(hours * 3600.0 + minutes * 60.0 + seconds + centiseconds / 100.0);
    }

    // Parse frame=1234
    if let Some(caps) = Regex::new(r"frame=\s*(\d+)")
        .ok()
        .and_then(|re| re.captures(line))
    {
        progress.frame = caps.get(1).and_then(|m| m.as_str().parse().ok());
    }

    // Parse fps=29.97
    if let Some(caps) = Regex::new(r"fps=\s*([\d.]+)")
        .ok()
        .and_then(|re| re.captures(line))
    {
        progress.fps = caps.get(1).and_then(|m| m.as_str().parse().ok());
    }

    // Parse speed=1.5x
    if let Some(caps) = Regex::new(r"speed=\s*([\d.]+)x")
        .ok()
        .and_then(|re| re.captures(line))
    {
        progress.speed = caps.get(1).and_then(|m| m.as_str().parse().ok());
    }

    // Parse bitrate=1234kbits/s
    if let Some(caps) = Regex::new(r"bitrate=\s*([\d.]+\s*\w+/s)")
        .ok()
        .and_then(|re| re.captures(line))
    {
        progress.bitrate = caps.get(1).map(|m| m.as_str().to_string());
    }

    progress
}

/// Calculate ETA based on progress and speed
pub fn calculate_eta(current_time: f64, duration: f64, speed: Option<f64>) -> Option<f64> {
    if duration <= 0.0 || current_time <= 0.0 {
        return None;
    }

    let remaining_time = duration - current_time;
    if remaining_time <= 0.0 {
        return Some(0.0);
    }

    match speed {
        Some(s) if s > 0.0 => Some(remaining_time / s),
        _ => None,
    }
}

/// Get media duration using ffmpeg
pub async fn get_duration(_app: &AppHandle, input_path: &str) -> Result<f64, String> {
    let output = Command::new(FFMPEG_PATH)
        .args(["-i", input_path, "-hide_banner"])
        .stderr(Stdio::piped())
        .stdout(Stdio::null())
        .output()
        .await
        .map_err(|e| format!("Failed to execute ffmpeg: {}", e))?;

    let stderr = String::from_utf8_lossy(&output.stderr);

    let duration_regex = Regex::new(r"Duration:\s*(\d{2}):(\d{2}):(\d{2})\.(\d{2})")
        .map_err(|e| format!("Regex error: {}", e))?;

    if let Some(caps) = duration_regex.captures(&stderr) {
        let hours: f64 = caps.get(1).unwrap().as_str().parse().unwrap_or(0.0);
        let minutes: f64 = caps.get(2).unwrap().as_str().parse().unwrap_or(0.0);
        let seconds: f64 = caps.get(3).unwrap().as_str().parse().unwrap_or(0.0);
        let centiseconds: f64 = caps.get(4).unwrap().as_str().parse().unwrap_or(0.0);
        return Ok(hours * 3600.0 + minutes * 60.0 + seconds + centiseconds / 100.0);
    }

    Err("Could not determine media duration".to_string())
}

/// Convert media using system FFmpeg
pub async fn convert(
    app: &AppHandle,
    file_id: &str,
    input_path: &str,
    output_path: &str,
    format: &str,
) -> Result<String, String> {
    let duration = get_duration(app, input_path).await.unwrap_or(0.0);

    let mut args = vec![
        "-i".to_string(),
        input_path.to_string(),
        "-y".to_string(),
        "-progress".to_string(),
        "pipe:1".to_string(),
    ];

    match format {
        "gif" => {
            args.extend([
                "-vf".to_string(),
                "fps=15,scale=480:-1:flags=lanczos".to_string(),
            ]);
        }
        "mp3" => {
            args.extend(["-vn".to_string(), "-acodec".to_string(), "libmp3lame".to_string()]);
        }
        "wav" => {
            args.extend(["-vn".to_string()]);
        }
        "mp4" => {
            args.extend([
                "-c:v".to_string(),
                "h264_videotoolbox".to_string(),
                "-c:a".to_string(),
                "aac".to_string(),
            ]);
        }
        "webm" => {
            args.extend([
                "-c:v".to_string(),
                "libvpx-vp9".to_string(),
                "-c:a".to_string(),
                "libopus".to_string(),
            ]);
        }
        _ => {}
    }

    args.push(output_path.to_string());

    let mut child = Command::new(FFMPEG_PATH)
        .args(&args)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| format!("Failed to spawn FFmpeg: {}", e))?;

    let stdout = child.stdout.take().ok_or("Failed to capture stdout")?;

    // Store the process for cancellation
    {
        let mut processes = RUNNING_PROCESSES.lock().await;
        processes.insert(file_id.to_string(), child);
    }

    let mut reader = BufReader::new(stdout).lines();
    let app_clone = app.clone();
    let file_id_clone = file_id.to_string();

    while let Ok(Some(line)) = reader.next_line().await {
        let ffmpeg_progress = parse_progress_line(&line);

        if let Some(current_time) = ffmpeg_progress.time {
            let percent = if duration > 0.0 {
                (current_time / duration * 100.0).min(100.0)
            } else {
                0.0
            };

            let eta = calculate_eta(current_time, duration, ffmpeg_progress.speed);

            let progress = ConversionProgress {
                file_id: file_id_clone.clone(),
                percent,
                current_time: Some(current_time),
                total_duration: Some(duration),
                fps: ffmpeg_progress.fps,
                frame: ffmpeg_progress.frame,
                speed: ffmpeg_progress.speed,
                eta_seconds: eta,
            };
            let _ = app_clone.emit("conversion:progress", progress);
        }
    }

    // Get the child back and wait for it
    let status = {
        let mut processes = RUNNING_PROCESSES.lock().await;
        if let Some(mut child) = processes.remove(&file_id_clone) {
            child.wait().await.map_err(|e| format!("FFmpeg error: {}", e))?
        } else {
            // Process was cancelled
            return Err("Conversion was cancelled".to_string());
        }
    };

    if status.success() {
        Ok(output_path.to_string())
    } else {
        Err(format!("FFmpeg exited with code: {:?}", status.code()))
    }
}
