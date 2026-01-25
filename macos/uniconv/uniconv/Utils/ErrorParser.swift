//
//  ErrorParser.swift
//  UniConv
//
//  Utility for parsing and extracting meaningful errors from FFmpeg and ImageMagick output
//

import Foundation

struct ParsedError {
    let summary: String
    let details: String?
    let suggestion: String?
    
    var displayMessage: String {
        var message = summary
        if let suggestion = suggestion {
            message += "\n\n💡 \(suggestion)"
        }
        return message
    }
}

class ErrorParser {
    
    // MARK: - FFmpeg Error Parsing
    
    static func parseFFmpegError(from output: String, exitCode: Int32) -> ParsedError {
        let lines = output.components(separatedBy: .newlines)
        
        // Look for specific error patterns
        for line in lines.reversed() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Codec/encoder errors
            if trimmed.contains("Unknown encoder") || trimmed.contains("Encoder") && trimmed.contains("not found") {
                if let codec = extractQuoted(from: trimmed) {
                    return ParsedError(
                        summary: "Encoder '\(codec)' not found",
                        details: trimmed,
                        suggestion: "Install FFmpeg with additional codecs: brew reinstall ffmpeg --with-all-codecs"
                    )
                }
            }
            
            // Decoder errors
            if trimmed.contains("Decoder") && trimmed.contains("not found") {
                if let codec = extractQuoted(from: trimmed) {
                    return ParsedError(
                        summary: "Decoder '\(codec)' not found",
                        details: trimmed,
                        suggestion: "The input file uses a codec that FFmpeg cannot decode"
                    )
                }
            }
            
            // Invalid input
            if trimmed.contains("Invalid data found") || trimmed.contains("Invalid data when processing input") {
                return ParsedError(
                    summary: "Invalid or corrupted input file",
                    details: trimmed,
                    suggestion: "The file may be corrupted or in an unsupported format"
                )
            }
            
            // File not found
            if trimmed.contains("No such file or directory") {
                return ParsedError(
                    summary: "Input file not found",
                    details: trimmed,
                    suggestion: "Ensure the file exists and the path is correct"
                )
            }
            
            // Permission errors
            if trimmed.contains("Permission denied") {
                return ParsedError(
                    summary: "Permission denied",
                    details: trimmed,
                    suggestion: "Check file permissions or choose a different output location"
                )
            }
            
            // Output format errors
            if trimmed.contains("Could not write header") {
                return ParsedError(
                    summary: "Could not write output file",
                    details: trimmed,
                    suggestion: "The output format may not support the specified codecs or options"
                )
            }
            
            // Filter errors
            if trimmed.contains("Invalid filter") || trimmed.contains("No such filter") {
                return ParsedError(
                    summary: "Invalid video/audio filter",
                    details: trimmed,
                    suggestion: "One of the conversion options uses an unsupported filter"
                )
            }
            
            // Resolution/scaling errors
            if trimmed.contains("not divisible by") || trimmed.contains("Invalid too big or non positive size") {
                return ParsedError(
                    summary: "Invalid output resolution",
                    details: trimmed,
                    suggestion: "Try a different resolution setting"
                )
            }
            
            // Disk space
            if trimmed.contains("No space left") || trimmed.contains("disk full") {
                return ParsedError(
                    summary: "Insufficient disk space",
                    details: trimmed,
                    suggestion: "Free up disk space and try again"
                )
            }
            
            // Generic "Error" lines
            if trimmed.lowercased().hasPrefix("error:") || trimmed.lowercased().hasPrefix("[error]") {
                let errorMessage = trimmed
                    .replacingOccurrences(of: "Error:", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "[error]", with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespaces)
                
                if !errorMessage.isEmpty {
                    return ParsedError(
                        summary: errorMessage.prefix(100).description + (errorMessage.count > 100 ? "..." : ""),
                        details: trimmed,
                        suggestion: nil
                    )
                }
            }
            
            // Last line with meaningful error
            if trimmed.contains("Conversion failed") {
                // Look for the previous error line
                continue
            }
        }
        
        // Fallback based on exit code
        return ParsedError(
            summary: "FFmpeg conversion failed (exit code: \(exitCode))",
            details: getLastMeaningfulLines(from: output, count: 3),
            suggestion: "Check the conversion log for more details"
        )
    }
    
    // MARK: - ImageMagick Error Parsing
    
    static func parseImageMagickError(from output: String, exitCode: Int32) -> ParsedError {
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines.reversed() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // File not found
            if trimmed.contains("unable to open image") || trimmed.contains("No such file") {
                return ParsedError(
                    summary: "Input file not found or cannot be opened",
                    details: trimmed,
                    suggestion: "Ensure the file exists and is a valid image"
                )
            }
            
            // Corrupted image
            if trimmed.contains("corrupt") || trimmed.contains("Corrupt") {
                return ParsedError(
                    summary: "Image file is corrupted",
                    details: trimmed,
                    suggestion: "The image file may be damaged or incomplete"
                )
            }
            
            // Unsupported format
            if trimmed.contains("no decode delegate") || trimmed.contains("Unknown format") {
                return ParsedError(
                    summary: "Unsupported image format",
                    details: trimmed,
                    suggestion: "ImageMagick cannot read this image format"
                )
            }
            
            // Permission errors
            if trimmed.contains("Permission denied") || trimmed.contains("unable to create") {
                return ParsedError(
                    summary: "Permission denied",
                    details: trimmed,
                    suggestion: "Check file permissions or choose a different output location"
                )
            }
            
            // Memory errors
            if trimmed.contains("memory allocation failed") || trimmed.contains("cache resources exhausted") {
                return ParsedError(
                    summary: "Insufficient memory",
                    details: trimmed,
                    suggestion: "The image may be too large. Try reducing the output size"
                )
            }
            
            // Disk space
            if trimmed.contains("No space left") || trimmed.contains("disk full") {
                return ParsedError(
                    summary: "Insufficient disk space",
                    details: trimmed,
                    suggestion: "Free up disk space and try again"
                )
            }
            
            // Generic error pattern
            if trimmed.contains("error/") || trimmed.lowercased().contains("@ error") {
                // Extract the meaningful part after the error marker
                if let range = trimmed.range(of: #":\s*(.+)$"#, options: .regularExpression) {
                    let errorPart = String(trimmed[range])
                        .trimmingCharacters(in: CharacterSet(charactersIn: ": "))
                    if !errorPart.isEmpty {
                        return ParsedError(
                            summary: errorPart,
                            details: trimmed,
                            suggestion: nil
                        )
                    }
                }
            }
        }
        
        // Fallback
        return ParsedError(
            summary: "ImageMagick conversion failed (exit code: \(exitCode))",
            details: getLastMeaningfulLines(from: output, count: 3),
            suggestion: "Check the conversion log for more details"
        )
    }
    
    // MARK: - Helpers
    
    private static func extractQuoted(from text: String) -> String? {
        if let match = text.range(of: #"'([^']+)'"#, options: .regularExpression) {
            let quoted = String(text[match])
            return String(quoted.dropFirst().dropLast())
        }
        if let match = text.range(of: #""([^"]+)""#, options: .regularExpression) {
            let quoted = String(text[match])
            return String(quoted.dropFirst().dropLast())
        }
        return nil
    }
    
    private static func getLastMeaningfulLines(from output: String, count: Int) -> String {
        let lines = output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        let lastLines = Array(lines.suffix(count))
        return lastLines.joined(separator: "\n")
    }
}
