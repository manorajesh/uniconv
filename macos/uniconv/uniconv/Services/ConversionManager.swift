//
//  ConversionManager.swift
//  UniConv
//
//  Created on 1/22/2026.
//

import Foundation
import Combine

class ConversionManager: ObservableObject {
    static let shared = ConversionManager()
    
    private var runningProcesses: [UUID: Process] = [:]
    private let queue = DispatchQueue(label: "com.uniconv.conversion", attributes: .concurrent)
    
    // Dynamically discovered paths to external tools
    private var ffmpegPath: String?
    private var magickPath: String?
    
    private init() {
        // Find executables in PATH
        ffmpegPath = findExecutable(name: "ffmpeg")
        magickPath = findExecutable(name: "magick")
        
        print("Found ffmpeg at: \(ffmpegPath ?? "not found")")
        print("Found magick at: \(magickPath ?? "not found")")
    }
    
    // Find executable in common paths
    private func findExecutable(name: String) -> String? {
        let commonPaths = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            NSHomeDirectory() + "/.local/bin"
        ]
        
        // Try common paths first
        for path in commonPaths {
            let fullPath = "\(path)/\(name)"
            if FileManager.default.isExecutableFile(atPath: fullPath) {
                return fullPath
            }
        }
        
        // Try using 'which' command (run on background queue during init)
        let process = Process()
        let pipe = Pipe()
        
        process.launchPath = "/usr/bin/which"
        process.arguments = [name]
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            // This is acceptable during init as it's a quick one-time check
            // and happens before UI is displayed
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !output.isEmpty {
                    return output
                }
            }
        } catch {
            print("Error finding \(name): \(error)")
        }
        
        return nil
    }
    
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
            try await convertWithImageMagick(fileId: file.id, inputPath: file.path, outputPath: outputPath, file: file)
        } else {
            throw ConversionError(message: "Unsupported output format: \(format)")
        }
        
        return outputPath
    }
    
    private func convertWithFFmpeg(fileId: UUID, inputPath: String, outputPath: String, format: String, file: FileItem) async throws {
        guard let ffmpegPath = ffmpegPath else {
            throw ConversionError(message: "FFmpeg not found. Please install FFmpeg using: brew install ffmpeg")
        }
        
        // Add initial log entry
        await MainActor.run {
            file.conversionLog += "[\(Date().formatted(date: .omitted, time: .standard))] Starting FFmpeg conversion\n"
            file.conversionLog += "Input: \(inputPath)\n"
            file.conversionLog += "Output: \(outputPath)\n"
            file.conversionLog += "Format: \(format)\n\n"
        }
        
        // First, get the duration for progress calculation
        let duration = try await getMediaDuration(inputPath: inputPath)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        
        var arguments = ["-i", inputPath, "-y"]
        
        // Determine if this is video or audio conversion
        let isVideo = FormatUtils.videoOutputFormats.contains(format)
        let isAudio = FormatUtils.audioOutputFormats.contains(format)
        
        if isVideo {
            // Video codec
            if let codec = file.options.video.codec.ffmpegCodec {
                arguments += ["-c:v", codec]
            } else {
                // Default codec based on format
                switch format {
                case "mp4": arguments += ["-c:v", "libx264"]
                case "webm": arguments += ["-c:v", "libvpx-vp9"]
                case "gif": arguments += ["-c:v", "gif"]
                default: break
                }
            }
            
            // Video quality (CRF)
            if format != "gif" {
                arguments += ["-crf", "\(file.options.video.quality.crf)"]
            }
            
            // Resolution scaling
            var videoFilters: [String] = []
            if let scale = file.options.video.resolution.ffmpegScale {
                videoFilters.append("scale=\(scale):force_original_aspect_ratio=decrease")
            }
            
            // FPS limit
            if let fps = file.options.video.fps {
                videoFilters.append("fps=\(fps)")
            }
            
            // GIF specific filters
            if format == "gif" {
                if videoFilters.isEmpty {
                    videoFilters.append("scale=480:-1:flags=lanczos")
                }
            }
            
            if !videoFilters.isEmpty {
                arguments += ["-vf", videoFilters.joined(separator: ",")]
            }
            
            // Audio in video
            if format != "gif" {
                arguments += ["-c:a", "aac", "-b:a", file.options.audio.bitrate.value]
            }
            
            // Preset for encoding speed
            if file.options.video.codec == .h264 || file.options.video.codec == .auto {
                arguments += ["-preset", "medium"]
            }
        } else if isAudio {
            // Audio-only conversion
            arguments += ["-vn"] // No video
            
            switch format {
            case "mp3":
                arguments += ["-c:a", "libmp3lame", "-b:a", file.options.audio.bitrate.value]
            case "wav":
                arguments += ["-c:a", "pcm_s16le"]
            case "flac":
                arguments += ["-c:a", "flac"]
            case "aac", "m4a":
                arguments += ["-c:a", "aac", "-b:a", file.options.audio.bitrate.value]
            case "ogg":
                arguments += ["-c:a", "libvorbis", "-b:a", file.options.audio.bitrate.value]
            default:
                break
            }
            
            // Sample rate
            if let sampleRate = file.options.audio.sampleRate {
                arguments += ["-ar", "\(sampleRate)"]
            }
        }
        
        arguments.append(outputPath)
        process.arguments = arguments
        
        // Log the command
        await MainActor.run {
            file.conversionLog += "Command: \(ffmpegPath) \(arguments.joined(separator: " "))\n\n"
        }
        
        // Set up progress monitoring
        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = Pipe()
        
        // Collected stderr for error parsing
        var collectedStderr = ""
        let stderrLock = NSLock()
        
        // Store the process
        queue.sync(flags: .barrier) {
            runningProcesses[fileId] = process
        }
        
        // Monitor progress in background
        Task {
            await monitorFFmpegProgress(pipe: stderrPipe, duration: duration, file: file, collectedOutput: &collectedStderr, lock: stderrLock)
        }
        
        do {
            try process.run()
            
            // Wait for process on background thread to avoid blocking main thread
            await withCheckedContinuation { continuation in
                queue.async {
                    process.waitUntilExit()
                    continuation.resume()
                }
            }
            
            queue.sync(flags: .barrier) {
                runningProcesses.removeValue(forKey: fileId)
            }
            
            if process.terminationStatus != 0 {
                // Parse the error for a user-friendly message
                stderrLock.lock()
                let stderr = collectedStderr
                stderrLock.unlock()
                
                let parsedError = ErrorParser.parseFFmpegError(from: stderr, exitCode: process.terminationStatus)
                
                await MainActor.run {
                    file.conversionLog += "\n[ERROR] FFmpeg exited with status \(process.terminationStatus)\n"
                    if let details = parsedError.details {
                        file.conversionLog += "\(details)\n"
                    }
                }
                throw ConversionError(message: parsedError.displayMessage)
            } else {
                await MainActor.run {
                    file.conversionLog += "\n[SUCCESS] Conversion completed successfully\n"
                }
            }
        } catch let error as ConversionError {
            queue.sync(flags: .barrier) {
                runningProcesses.removeValue(forKey: fileId)
            }
            throw error
        } catch {
            queue.sync(flags: .barrier) {
                runningProcesses.removeValue(forKey: fileId)
            }
            await MainActor.run {
                file.conversionLog += "\n[ERROR] \(error.localizedDescription)\n"
            }
            throw ConversionError(message: "Failed to execute FFmpeg: \(error.localizedDescription)")
        }
    }
    
    private func convertWithImageMagick(fileId: UUID, inputPath: String, outputPath: String, file: FileItem) async throws {
        guard let magickPath = magickPath else {
            throw ConversionError(message: "ImageMagick not found. Please install ImageMagick using: brew install imagemagick")
        }
        
        // Add initial log entry
        await MainActor.run {
            file.conversionLog += "[\(Date().formatted(date: .omitted, time: .standard))] Starting ImageMagick conversion\n"
            file.conversionLog += "Input: \(inputPath)\n"
            file.conversionLog += "Output: \(outputPath)\n\n"
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: magickPath)
        
        var arguments = ["convert", inputPath]
        
        // Auto-orient based on EXIF
        if file.options.image.autoOrient {
            arguments.append("-auto-orient")
        }
        
        // Strip metadata
        if file.options.image.stripMetadata {
            arguments.append("-strip")
        }
        
        // Resize if specified
        if let maxDim = file.options.image.maxDimension {
            arguments += ["-resize", "\(maxDim)x\(maxDim)>"]
        }
        
        // Quality setting
        arguments += ["-quality", "\(file.options.image.quality)"]
        
        arguments.append(outputPath)
        process.arguments = arguments
        
        // Log the command
        await MainActor.run {
            file.conversionLog += "Command: \(magickPath) \(arguments.joined(separator: " "))\n\n"
        }
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Collected stderr for error parsing
        var collectedStderr = ""
        let stderrLock = NSLock()
        
        queue.sync(flags: .barrier) {
            runningProcesses[fileId] = process
        }
        
        // Monitor output in background
        Task {
            await monitorImageMagickOutput(outputPipe: outputPipe, errorPipe: errorPipe, file: file, collectedStderr: &collectedStderr, lock: stderrLock)
        }
        
        do {
            try process.run()
            
            // Wait for process on background thread to avoid blocking main thread
            await withCheckedContinuation { continuation in
                queue.async {
                    process.waitUntilExit()
                    continuation.resume()
                }
            }
            
            queue.sync(flags: .barrier) {
                runningProcesses.removeValue(forKey: fileId)
            }
            
            if process.terminationStatus != 0 {
                // Read any remaining error output
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let additionalError = String(data: errorData, encoding: .utf8) ?? ""
                
                stderrLock.lock()
                collectedStderr += additionalError
                let stderr = collectedStderr
                stderrLock.unlock()
                
                let parsedError = ErrorParser.parseImageMagickError(from: stderr, exitCode: process.terminationStatus)
                
                await MainActor.run {
                    file.conversionLog += "\n[ERROR] ImageMagick exited with status \(process.terminationStatus)\n"
                    if !stderr.isEmpty {
                        file.conversionLog += stderr + "\n"
                    }
                }
                throw ConversionError(message: parsedError.displayMessage)
            } else {
                await MainActor.run {
                    file.conversionLog += "\n[SUCCESS] Conversion completed successfully\n"
                }
            }
        } catch let error as ConversionError {
            queue.sync(flags: .barrier) {
                runningProcesses.removeValue(forKey: fileId)
            }
            throw error
        } catch {
            queue.sync(flags: .barrier) {
                runningProcesses.removeValue(forKey: fileId)
            }
            await MainActor.run {
                file.conversionLog += "\n[ERROR] \(error.localizedDescription)\n"
            }
            throw ConversionError(message: "Failed to execute ImageMagick: \(error.localizedDescription)")
        }
    }
    
    private func getMediaDuration(inputPath: String) async throws -> Double {
        guard let ffmpegPath = ffmpegPath else {
            throw ConversionError(message: "FFmpeg not found")
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = ["-i", inputPath, "-hide_banner"]
        
        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()
        
        try process.run()
        
        // Wait for process on background thread to avoid blocking main thread
        await withCheckedContinuation { continuation in
            queue.async {
                process.waitUntilExit()
                continuation.resume()
            }
        }
        
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
    
    private func monitorFFmpegProgress(pipe: Pipe, duration: Double, file: FileItem, collectedOutput: inout String, lock: NSLock) async {
        let handle = pipe.fileHandleForReading
        
        // Use a class to capture the output since we can't use inout in closures
        class OutputCollector {
            var output = ""
            let lock: NSLock
            
            init(lock: NSLock) {
                self.lock = lock
            }
            
            func append(_ text: String) {
                lock.lock()
                output += text
                lock.unlock()
            }
        }
        
        let collector = OutputCollector(lock: lock)
        
        handle.readabilityHandler = { [collector] fileHandle in
            let data = fileHandle.availableData
            guard let output = String(data: data, encoding: .utf8) else { return }
            
            // Collect output for error parsing
            collector.append(output)
            
            // Log the output
            Task { @MainActor in
                file.conversionLog += output
            }
            
            self.parseFFmpegOutput(output, duration: duration, file: file)
        }
        
        // Copy collected output back
        lock.lock()
        collectedOutput = collector.output
        lock.unlock()
    }
    
    private func monitorImageMagickOutput(outputPipe: Pipe, errorPipe: Pipe, file: FileItem, collectedStderr: inout String, lock: NSLock) async {
        let outputHandle = outputPipe.fileHandleForReading
        let errorHandle = errorPipe.fileHandleForReading
        
        // Use a class to capture the stderr since we can't use inout in closures
        class StderrCollector {
            var stderr = ""
            let lock: NSLock
            
            init(lock: NSLock) {
                self.lock = lock
            }
            
            func append(_ text: String) {
                lock.lock()
                stderr += text
                lock.unlock()
            }
        }
        
        let collector = StderrCollector(lock: lock)
        
        outputHandle.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            guard let output = String(data: data, encoding: .utf8), !output.isEmpty else { return }
            
            Task { @MainActor in
                file.conversionLog += output
            }
        }
        
        errorHandle.readabilityHandler = { [collector] fileHandle in
            let data = fileHandle.availableData
            guard let output = String(data: data, encoding: .utf8), !output.isEmpty else { return }
            
            // Collect stderr for error parsing
            collector.append(output)
            
            Task { @MainActor in
                file.conversionLog += output
            }
        }
        
        // Copy collected stderr back
        lock.lock()
        collectedStderr = collector.stderr
        lock.unlock()
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

