//
//  ConversionManager.swift
//  UniConv
//
//  Created on 1/22/2026.
//

import Foundation

class ConversionManager: ObservableObject {
    static let shared = ConversionManager()
    
    private var runningProcesses: [UUID: Process] = [:]
    private let queue = DispatchQueue(label: "com.uniconv.conversion", attributes: .concurrent)
    
    // Paths to external tools (using Homebrew paths for macOS)
    private let ffmpegPath = "/opt/homebrew/bin/ffmpeg"
    private let magickPath = "/opt/homebrew/bin/magick"
    
    private init() {}
    
    // MARK: - Public Methods
    
    func startConversion(for file: FileItem) async {
        await MainActor.run {
            file.status = .converting
            file.progress = 0.0
        }
        
        do {
            let outputPath = try await performConversion(for: file)
            
            await MainActor.run {
                file.status = .completed
                file.progress = 100.0
                file.outputPath = outputPath
            }
        } catch let error as ConversionError {
            await MainActor.run {
                file.status = .error
                file.error = error.message
            }
        } catch {
            await MainActor.run {
                file.status = .error
                file.error = error.localizedDescription
            }
        }
    }
    
    func cancelConversion(for fileId: UUID) {
        queue.sync(flags: .barrier) {
            if let process = runningProcesses[fileId] {
                process.terminate()
                runningProcesses.removeValue(forKey: fileId)
            }
        }
    }
    
    func cancelAllConversions() {
        queue.sync(flags: .barrier) {
            for (_, process) in runningProcesses {
                process.terminate()
            }
            runningProcesses.removeAll()
        }
    }
    
    // MARK: - Private Methods
    
    private func performConversion(for file: FileItem) async throws -> String {
        let inputURL = URL(fileURLWithPath: file.path)
        let outputPath = generateOutputPath(for: inputURL, format: file.selectedFormat)
        
        let format = file.selectedFormat.lowercased()
        
        // Determine which tool to use
        if FormatUtils.videoOutputFormats.contains(format) || FormatUtils.audioOutputFormats.contains(format) {
            try await convertWithFFmpeg(fileId: file.id, inputPath: file.path, outputPath: outputPath, format: format, file: file)
        } else if FormatUtils.imageOutputFormats.contains(format) {
            try await convertWithImageMagick(fileId: file.id, inputPath: file.path, outputPath: outputPath)
        } else {
            throw ConversionError(message: "Unsupported output format: \(format)")
        }
        
        return outputPath
    }
    
    private func convertWithFFmpeg(fileId: UUID, inputPath: String, outputPath: String, format: String, file: FileItem) async throws {
        // First, get the duration for progress calculation
        let duration = try await getMediaDuration(inputPath: inputPath)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        
        var arguments = ["-i", inputPath, "-y"]
        
        // Add format-specific arguments
        switch format {
        case "mp4":
            arguments += ["-c:v", "libx264", "-preset", "medium", "-crf", "23", "-c:a", "aac", "-b:a", "128k"]
        case "webm":
            arguments += ["-c:v", "libvpx-vp9", "-crf", "30", "-b:v", "0", "-c:a", "libopus"]
        case "gif":
            arguments += ["-vf", "fps=10,scale=480:-1:flags=lanczos", "-c:v", "gif"]
        case "mp3":
            arguments += ["-vn", "-c:a", "libmp3lame", "-b:a", "192k"]
        case "wav":
            arguments += ["-vn", "-c:a", "pcm_s16le"]
        case "flac":
            arguments += ["-vn", "-c:a", "flac"]
        case "aac":
            arguments += ["-vn", "-c:a", "aac", "-b:a", "192k"]
        case "m4a":
            arguments += ["-vn", "-c:a", "aac", "-b:a", "192k"]
        default:
            break
        }
        
        arguments.append(outputPath)
        process.arguments = arguments
        
        // Set up progress monitoring
        let outputPipe = Pipe()
        process.standardError = outputPipe
        process.standardOutput = Pipe()
        
        // Store the process
        queue.sync(flags: .barrier) {
            runningProcesses[fileId] = process
        }
        
        // Monitor progress in background
        Task {
            await monitorFFmpegProgress(pipe: outputPipe, duration: duration, file: file)
        }
        
        do {
            try process.run()
            process.waitUntilExit()
            
            queue.sync(flags: .barrier) {
                runningProcesses.removeValue(forKey: fileId)
            }
            
            if process.terminationStatus != 0 {
                throw ConversionError(message: "FFmpeg conversion failed with status \(process.terminationStatus)")
            }
        } catch {
            queue.sync(flags: .barrier) {
                runningProcesses.removeValue(forKey: fileId)
            }
            throw ConversionError(message: "Failed to execute FFmpeg: \(error.localizedDescription)")
        }
    }
    
    private func convertWithImageMagick(fileId: UUID, inputPath: String, outputPath: String) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: magickPath)
        process.arguments = [
            "convert",
            inputPath,
            "-auto-orient",
            "-strip",
            outputPath
        ]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        queue.sync(flags: .barrier) {
            runningProcesses[fileId] = process
        }
        
        do {
            try process.run()
            process.waitUntilExit()
            
            queue.sync(flags: .barrier) {
                runningProcesses.removeValue(forKey: fileId)
            }
            
            if process.terminationStatus != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                throw ConversionError(message: "ImageMagick conversion failed: \(errorString)")
            }
        } catch {
            queue.sync(flags: .barrier) {
                runningProcesses.removeValue(forKey: fileId)
            }
            throw ConversionError(message: "Failed to execute ImageMagick: \(error.localizedDescription)")
        }
    }
    
    private func getMediaDuration(inputPath: String) async throws -> Double {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = ["-i", inputPath, "-hide_banner"]
        
        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()
        
        try process.run()
        process.waitUntilExit()
        
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: errorData, encoding: .utf8) ?? ""
        
        // Parse duration from FFmpeg output: Duration: HH:MM:SS.MS
        let pattern = #"Duration:\s*(\d{2}):(\d{2}):(\d{2})\.(\d{2})"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)) {
            
            let hours = Double((output as NSString).substring(with: match.range(at: 1))) ?? 0
            let minutes = Double((output as NSString).substring(with: match.range(at: 2))) ?? 0
            let seconds = Double((output as NSString).substring(with: match.range(at: 3))) ?? 0
            let centiseconds = Double((output as NSString).substring(with: match.range(at: 4))) ?? 0
            
            return hours * 3600 + minutes * 60 + seconds + centiseconds / 100
        }
        
        return 0
    }
    
    private func monitorFFmpegProgress(pipe: Pipe, duration: Double, file: FileItem) async {
        let handle = pipe.fileHandleForReading
        
        handle.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            guard let output = String(data: data, encoding: .utf8) else { return }
            
            self.parseFFmpegOutput(output, duration: duration, file: file)
        }
    }
    
    private func parseFFmpegOutput(_ output: String, duration: Double, file: FileItem) {
        // Parse time=HH:MM:SS.MS
        if let timeMatch = output.range(of: #"time=(\d{2}):(\d{2}):(\d{2})\.(\d{2})"#, options: .regularExpression) {
            let timeString = String(output[timeMatch])
            let components = timeString.replacingOccurrences(of: "time=", with: "").split(separator: ":")
            
            if components.count == 3 {
                let hours = Double(components[0]) ?? 0
                let minutes = Double(components[1]) ?? 0
                let secondsParts = components[2].split(separator: ".")
                let seconds = Double(secondsParts[0]) ?? 0
                let centiseconds = secondsParts.count > 1 ? (Double(secondsParts[1]) ?? 0) : 0
                
                let currentTime = hours * 3600 + minutes * 60 + seconds + centiseconds / 100
                let progress = duration > 0 ? (currentTime / duration) * 100 : 0
                
                Task { @MainActor in
                    file.progress = min(progress, 100)
                }
            }
        }
        
        // Parse fps
        if let fpsMatch = output.range(of: #"fps=\s*([\d.]+)"#, options: .regularExpression) {
            let fpsString = String(output[fpsMatch]).replacingOccurrences(of: "fps=", with: "").trimmingCharacters(in: .whitespaces)
            if let fps = Double(fpsString) {
                Task { @MainActor in
                    file.fps = fps
                }
            }
        }
        
        // Parse speed
        if let speedMatch = output.range(of: #"speed=\s*([\d.]+)x"#, options: .regularExpression) {
            let speedString = String(output[speedMatch]).replacingOccurrences(of: "speed=", with: "").replacingOccurrences(of: "x", with: "").trimmingCharacters(in: .whitespaces)
            if let speed = Double(speedString) {
                Task { @MainActor in
                    file.speed = speed
                    
                    // Calculate ETA
                    if duration > 0 && file.progress > 0 {
                        let currentTime = (file.progress / 100) * duration
                        let remainingTime = duration - currentTime
                        file.etaSeconds = speed > 0 ? remainingTime / speed : nil
                    }
                }
            }
        }
    }
    
    private func generateOutputPath(for inputURL: URL, format: String) -> String {
        let directory = inputURL.deletingLastPathComponent()
        let filename = inputURL.deletingPathExtension().lastPathComponent
        return directory.appendingPathComponent("\(filename).\(format)").path
    }
}

struct ConversionError: Error {
    let message: String
}
