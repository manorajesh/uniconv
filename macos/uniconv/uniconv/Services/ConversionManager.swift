//
//  ConversionManager.swift
//  UniConv
//
//  Created on 1/22/2026.
//

import Foundation
import Combine

// Thread-safe output collector for async process monitoring
private final class OutputCollector: @unchecked Sendable {
    private var _output = ""
    private let lock = NSLock()
    
    var output: String {
        lock.withLock { _output }
    }
    
    func append(_ text: String) {
        lock.withLock { _output += text }
    }
}

// Thread-safe process storage
private final class ProcessStorage: @unchecked Sendable {
    private var processes: [UUID: Process] = [:]
    private let lock = NSLock()
    
    func store(_ process: Process, for id: UUID) {
        lock.withLock { processes[id] = process }
    }
    
    func remove(for id: UUID) {
        lock.withLock { processes.removeValue(forKey: id) }
    }
    
    func get(for id: UUID) -> Process? {
        lock.withLock { processes[id] }
    }
    
    func terminate(for id: UUID) {
        lock.withLock {
            if let process = processes[id], process.isRunning {
                process.terminate()
            }
        }
    }
}

@MainActor
class ConversionManager: ObservableObject {
    static let shared = ConversionManager()
    
    private let processStorage = ProcessStorage()
    
    // Dynamically discovered paths to external tools
    private var ffmpegPath: String?
    private var magickPath: String?
    private var librawPath: String?
    
    private init() {
        // Find executables in PATH
        ffmpegPath = findExecutable(name: "ffmpeg")
        magickPath = findExecutable(name: "magick")
        librawPath = findExecutable(name: "dcraw_emu") ?? findExecutable(name: "dcraw")
        
        print("Found ffmpeg at: \(ffmpegPath ?? "not found")")
        print("Found magick at: \(magickPath ?? "not found")")
        print("Found libraw at: \(librawPath ?? "not found")")
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
                // Don't overwrite cancelled status with error
                if file.status != .cancelled {
                    if error.message == "Conversion cancelled" {
                        file.status = .cancelled
                    } else {
                        file.status = .error
                        file.error = error.message
                    }
                }
            }
        } catch {
            await MainActor.run {
                // Don't overwrite cancelled status with error
                if file.status != .cancelled {
                    file.status = .error
                    file.error = error.localizedDescription
                }
            }
        }
    }
    
    func cancelConversion(for fileId: UUID) {
        processStorage.terminate(for: fileId)
    }
    
    nonisolated func cancelAllConversions() {
        // Individual cancellations are handled through cancelConversion
    }
    
    // MARK: - Private Methods
    
    private func performConversion(for file: FileItem) async throws -> String {
        let inputURL = URL(fileURLWithPath: file.path)
        let outputPath = generateOutputPath(for: inputURL, format: file.selectedFormat, customName: file.customOutputName)
        
        let format = file.selectedFormat.lowercased()
        let inputExtension = inputURL.pathExtension.lowercased()
        
        // Determine which tool to use
        if FormatUtils.videoOutputFormats.contains(format) || FormatUtils.audioOutputFormats.contains(format) {
            try await convertWithFFmpeg(fileId: file.id, inputPath: file.path, outputPath: outputPath, format: format, file: file)
        } else if FormatUtils.imageOutputFormats.contains(format) {
            // Check if we should use native conversion
            let useNative = file.options.image.shouldUseNativeConversion(
                inputExtension: inputExtension,
                outputExtension: format
            )
            
            if useNative {
                try await convertWithNativeImageIO(fileId: file.id, inputPath: file.path, outputPath: outputPath, file: file)
            } else {
                try await convertWithImageMagick(fileId: file.id, inputPath: file.path, outputPath: outputPath, file: file)
            }
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
        let stderrHandle = stderrPipe.fileHandleForReading
        process.standardError = stderrPipe
        process.standardOutput = Pipe()
        
        // Collected stderr for error parsing  
        let collector = OutputCollector()
        
        // Store the process
        processStorage.store(process, for: fileId)
        
        // Capture file weakly for the closure
        weak var weakFile = file
        
        // Set up stderr monitoring with readability handler
        stderrHandle.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let output = String(data: data, encoding: .utf8) else { return }
            
            collector.append(output)
            
            Task { @MainActor in
                weakFile?.conversionLog += output
            }
            
            Task { @MainActor [weak self] in
                self?.parseFFmpegOutput(output, duration: duration, file: weakFile)
            }
        }
        
        // Use terminationHandler instead of waitUntilExit to avoid blocking
        let storage = processStorage
        let result: (status: Int32, wasCancelled: Bool) = try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { proc in
                // Clean up the readability handler immediately
                stderrHandle.readabilityHandler = nil
                
                // Remove from running processes
                storage.remove(for: fileId)
                
                // SIGKILL = 9, process was forcefully killed (cancelled)
                let wasCancelled = proc.terminationStatus == 9 || proc.terminationReason == .uncaughtSignal
                continuation.resume(returning: (proc.terminationStatus, wasCancelled))
            }
            
            do {
                try process.run()
            } catch {
                stderrHandle.readabilityHandler = nil
                storage.remove(for: fileId)
                continuation.resume(throwing: error)
            }
        }
        
        if result.wasCancelled {
            await MainActor.run {
                file.conversionLog += "\n[CANCELLED] Conversion was cancelled\n"
            }
            throw ConversionError(message: "Conversion cancelled")
        } else if result.status != 0 {
            // Parse the error for a user-friendly message
            let stderr = collector.output
            
            let parsedError = ErrorParser.parseFFmpegError(from: stderr, exitCode: result.status)
            
            await MainActor.run {
                file.conversionLog += "\n[ERROR] FFmpeg exited with status \(result.status)\n"
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
        let outputHandle = outputPipe.fileHandleForReading
        let errorHandle = errorPipe.fileHandleForReading
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Collected stderr for error parsing
        let collector = OutputCollector()
        
        processStorage.store(process, for: fileId)
        
        // Capture file weakly for closures
        weak var weakFile = file
        
        // Set up output monitoring
        outputHandle.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let output = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in
                weakFile?.conversionLog += output
            }
        }
        
        errorHandle.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let output = String(data: data, encoding: .utf8) else { return }
            collector.append(output)
            Task { @MainActor in
                weakFile?.conversionLog += output
            }
        }
        
        // Use terminationHandler instead of waitUntilExit to avoid blocking
        let storage = processStorage
        let result: (status: Int32, wasCancelled: Bool) = try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { proc in
                // Clean up the readability handlers immediately
                outputHandle.readabilityHandler = nil
                errorHandle.readabilityHandler = nil
                
                // Remove from running processes
                storage.remove(for: fileId)
                
                // SIGKILL = 9, process was forcefully killed (cancelled)
                let wasCancelled = proc.terminationStatus == 9 || proc.terminationReason == .uncaughtSignal
                continuation.resume(returning: (proc.terminationStatus, wasCancelled))
            }
            
            do {
                try process.run()
            } catch {
                outputHandle.readabilityHandler = nil
                errorHandle.readabilityHandler = nil
                storage.remove(for: fileId)
                continuation.resume(throwing: error)
            }
        }
        
        if result.wasCancelled {
            await MainActor.run {
                file.conversionLog += "\n[CANCELLED] Conversion was cancelled\n"
            }
            throw ConversionError(message: "Conversion cancelled")
        } else if result.status != 0 {
            let stderr = collector.output
            let parsedError = ErrorParser.parseImageMagickError(from: stderr, exitCode: result.status)
            
            await MainActor.run {
                file.conversionLog += "\n[ERROR] ImageMagick exited with status \(result.status)\n"
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
    }
    
    private func convertWithNativeImageIO(fileId: UUID, inputPath: String, outputPath: String, file: FileItem) async throws {
        let inputURL = URL(fileURLWithPath: inputPath)
        let inputExtension = inputURL.pathExtension.lowercased()
        let isRAW = FormatUtils.isRAWFormat(inputExtension)
        
        // Add initial log entry
        await MainActor.run {
            file.conversionLog += "[\(Date().formatted(date: .omitted, time: .standard))] Starting Native ImageIO conversion\n"
            file.conversionLog += "Input: \(inputPath)\n"
            file.conversionLog += "Output: \(outputPath)\n"
            file.conversionLog += "Engine: Apple ImageIO\(isRAW ? " (RAW format detected)" : "")\n\n"
        }
        
        // Capture file weakly for progress handler
        weak var weakFile = file
        
        do {
            // For RAW files, try LibRaw first for better quality if available
            if isRAW {
                if let librawPath = librawPath {
                    await MainActor.run {
                        weakFile?.conversionLog += "Using LibRaw for RAW processing...\n"
                    }
                    
                    try await NativeImageConverter.convertWithLibRaw(
                        inputPath: inputPath,
                        outputPath: outputPath,
                        options: file.options.image,
                        librawPath: librawPath
                    ) { progress, message in
                        Task { @MainActor in
                            weakFile?.progress = progress * 100
                            weakFile?.conversionLog += "[\(String(format: "%.0f%%", progress * 100))] \(message)\n"
                        }
                    }
                } else {
                    // Fall back to native ImageIO for RAW (may have reduced quality)
                    await MainActor.run {
                        weakFile?.conversionLog += "LibRaw not found, using native ImageIO for RAW...\n"
                        weakFile?.conversionLog += "Note: Install LibRaw (brew install libraw) for better RAW quality.\n"
                    }
                    
                    try NativeImageConverter.convert(
                        inputPath: inputPath,
                        outputPath: outputPath,
                        options: file.options.image
                    ) { progress, message in
                        Task { @MainActor in
                            weakFile?.progress = progress * 100
                            weakFile?.conversionLog += "[\(String(format: "%.0f%%", progress * 100))] \(message)\n"
                        }
                    }
                }
            } else {
                // Standard image conversion with native ImageIO
                try NativeImageConverter.convert(
                    inputPath: inputPath,
                    outputPath: outputPath,
                    options: file.options.image
                ) { progress, message in
                    Task { @MainActor in
                        weakFile?.progress = progress * 100
                        weakFile?.conversionLog += "[\(String(format: "%.0f%%", progress * 100))] \(message)\n"
                    }
                }
            }
            
            await MainActor.run {
                file.conversionLog += "\n[SUCCESS] Native ImageIO conversion completed successfully\n"
            }
            
        } catch let error as NativeConversionError {
            // Check if we should fall back to ImageMagick
            let shouldFallback = file.options.image.engine == .auto
            
            if shouldFallback, magickPath != nil {
                await MainActor.run {
                    file.conversionLog += "\n[WARNING] Native conversion failed: \(error.localizedDescription)\n"
                    file.conversionLog += "Falling back to ImageMagick...\n\n"
                }
                
                // Fall back to ImageMagick
                try await convertWithImageMagick(fileId: fileId, inputPath: inputPath, outputPath: outputPath, file: file)
            } else {
                await MainActor.run {
                    file.conversionLog += "\n[ERROR] Native conversion failed: \(error.localizedDescription)\n"
                }
                throw ConversionError(message: error.localizedDescription)
            }
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
        
        // Use terminationHandler for duration probing too
        let output: String = try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { _ in
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: errorData, encoding: .utf8) ?? ""
                continuation.resume(returning: output)
            }
            
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
        
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
    
    private func parseFFmpegOutput(_ output: String, duration: Double, file: FileItem?) {
        guard let file = file else { return }
        
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
    
    private func generateOutputPath(for inputURL: URL, format: String, customName: String? = nil) -> String {
        let filename: String
        if let custom = customName, !custom.isEmpty {
            filename = custom
        } else {
            filename = inputURL.deletingPathExtension().lastPathComponent
        }
        
        // Check if user has set a custom output folder
        let defaultOutputFolder = UserDefaults.standard.string(forKey: "defaultOutputFolder") ?? ""
        
        let directory: URL
        if !defaultOutputFolder.isEmpty && FileManager.default.fileExists(atPath: defaultOutputFolder) {
            directory = URL(fileURLWithPath: defaultOutputFolder)
        } else {
            // Fall back to same directory as source
            directory = inputURL.deletingLastPathComponent()
        }
        
        return directory.appendingPathComponent("\(filename).\(format)").path
    }
}

struct ConversionError: Error {
    let message: String
}

