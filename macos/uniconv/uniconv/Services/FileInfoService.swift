//
//  FileInfoService.swift
//  UniConv
//
//  Service for extracting file metadata using ffprobe and identify
//

import Foundation

class FileInfoService {
    static let shared = FileInfoService()
    
    private var ffprobePath: String?
    private var magickPath: String?
    
    private init() {
        ffprobePath = findExecutable(name: "ffprobe")
        magickPath = findExecutable(name: "magick")
    }
    
    private func findExecutable(name: String) -> String? {
        let commonPaths = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            NSHomeDirectory() + "/.local/bin"
        ]
        
        for path in commonPaths {
            let fullPath = "\(path)/\(name)"
            if FileManager.default.isExecutableFile(atPath: fullPath) {
                return fullPath
            }
        }
        
        return nil
    }
    
    // MARK: - Get File Info
    
    func getFileInfo(for path: String, type: FileType) async -> FileInfo {
        var info = FileInfo(path: path)
        
        switch type {
        case .video, .audio:
            await populateMediaInfo(&info)
        case .image:
            await populateImageInfo(&info)
        case .unknown:
            break
        }
        
        return info
    }
    
    // MARK: - Media Info (FFprobe)
    
    private func populateMediaInfo(_ info: inout FileInfo) async {
        guard let ffprobePath = ffprobePath else { return }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffprobePath)
        process.arguments = [
            "-v", "quiet",
            "-print_format", "json",
            "-show_format",
            "-show_streams",
            info.path
        ]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Parse format info
                if let format = json["format"] as? [String: Any] {
                    if let durationStr = format["duration"] as? String,
                       let duration = Double(durationStr) {
                        info.duration = formatDuration(duration)
                    }
                    
                    if let bitrateStr = format["bit_rate"] as? String,
                       let bitrate = Int(bitrateStr) {
                        info.bitrate = formatBitrate(bitrate)
                    }
                    
                    if let formatName = format["format_long_name"] as? String {
                        info.format = formatName
                    }
                }
                
                // Parse streams
                if let streams = json["streams"] as? [[String: Any]] {
                    for stream in streams {
                        guard let codecType = stream["codec_type"] as? String else { continue }
                        
                        if codecType == "video" {
                            if let codec = stream["codec_name"] as? String {
                                info.codec = codec.uppercased()
                            }
                            
                            if let width = stream["width"] as? Int,
                               let height = stream["height"] as? Int {
                                info.resolution = "\(width) × \(height)"
                            }
                            
                            if let fpsStr = stream["r_frame_rate"] as? String {
                                let parts = fpsStr.split(separator: "/")
                                if parts.count == 2,
                                   let num = Double(parts[0]),
                                   let den = Double(parts[1]),
                                   den > 0 {
                                    let fps = num / den
                                    info.frameRate = String(format: "%.2f fps", fps)
                                }
                            }
                        } else if codecType == "audio" {
                            if let codec = stream["codec_name"] as? String {
                                info.audioCodec = codec.uppercased()
                            }
                            
                            if let sampleRate = stream["sample_rate"] as? String {
                                if let rate = Int(sampleRate) {
                                    info.audioSampleRate = "\(rate / 1000) kHz"
                                }
                            }
                            
                            if let channels = stream["channels"] as? Int {
                                info.audioChannels = channels == 1 ? "Mono" : channels == 2 ? "Stereo" : "\(channels) channels"
                            }
                        }
                    }
                }
            }
        } catch {
            print("Error getting media info: \(error)")
        }
    }
    
    // MARK: - Image Info (ImageMagick identify)
    
    private func populateImageInfo(_ info: inout FileInfo) async {
        guard let magickPath = magickPath else { return }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: magickPath)
        process.arguments = [
            "identify",
            "-verbose",
            info.path
        ]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                parseImageMagickOutput(output, into: &info)
            }
        } catch {
            print("Error getting image info: \(error)")
        }
    }
    
    private func parseImageMagickOutput(_ output: String, into info: inout FileInfo) {
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("Geometry:") {
                // Parse geometry: "1920x1080+0+0"
                let value = trimmed.replacingOccurrences(of: "Geometry:", with: "").trimmingCharacters(in: .whitespaces)
                if let match = value.range(of: #"(\d+)x(\d+)"#, options: .regularExpression) {
                    let dims = String(value[match])
                    info.dimensions = dims.replacingOccurrences(of: "x", with: " × ")
                }
            } else if trimmed.hasPrefix("Colorspace:") {
                info.colorSpace = trimmed.replacingOccurrences(of: "Colorspace:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Type:") && info.format == nil {
                info.format = trimmed.replacingOccurrences(of: "Type:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Depth:") {
                info.depth = trimmed.replacingOccurrences(of: "Depth:", with: "").trimmingCharacters(in: .whitespaces)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatDuration(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        let ms = Int((seconds.truncatingRemainder(dividingBy: 1)) * 100)
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d.%02d", hours, minutes, secs, ms)
        } else {
            return String(format: "%02d:%02d.%02d", minutes, secs, ms)
        }
    }
    
    private func formatBitrate(_ bps: Int) -> String {
        if bps >= 1_000_000 {
            return String(format: "%.1f Mbps", Double(bps) / 1_000_000)
        } else {
            return String(format: "%d kbps", bps / 1000)
        }
    }
}
