//
//  NativeImageConverter.swift
//  UniConv
//
//  Native macOS image conversion using Apple's ImageIO framework
//  with LibRaw fallback for RAW image formats.
//

import Foundation
import ImageIO
import CoreImage
import AppKit
import UniformTypeIdentifiers

/// Image conversion engine preference
enum ImageConversionEngine: String, Codable, CaseIterable {
    case native = "Apple ImageIO (Native)"
    case imagemagick = "ImageMagick"
    case auto = "Auto (Native with fallback)"
    
    var description: String {
        switch self {
        case .native:
            return "Uses Apple's native ImageIO framework for best macOS integration and performance"
        case .imagemagick:
            return "Uses ImageMagick for maximum format compatibility"
        case .auto:
            return "Uses native ImageIO when possible, falls back to ImageMagick for unsupported formats"
        }
    }
}

/// Native image converter using Apple's ImageIO framework
class NativeImageConverter {
    
    // MARK: - Supported Formats
    
    /// Formats that ImageIO can read natively
    static let nativeReadFormats: Set<String> = {
        var formats: Set<String> = [
            "png", "jpg", "jpeg", "gif", "bmp", "tiff", "tif",
            "heic", "heif", "webp", "ico", "icns", "psd",
            "jp2", "j2k", "jpf", "jpx", "jpm", "mj2"
        ]
        
        // Apple RAW formats supported via ImageIO
        let rawFormats: Set<String> = [
            "dng", "cr2", "cr3", "nef", "arw", "orf", "rw2",
            "raf", "pef", "srw", "3fr", "fff", "iiq", "rwl"
        ]
        formats.formUnion(rawFormats)
        
        return formats
    }()
    
    /// Formats that ImageIO can write natively
    static let nativeWriteFormats: Set<String> = [
        "png", "jpg", "jpeg", "gif", "bmp", "tiff", "tif",
        "heic", "jp2", "pdf"
    ]
    
    /// RAW formats that may need LibRaw for better quality
    static let rawFormats: Set<String> = [
        "dng", "cr2", "cr3", "nef", "arw", "orf", "rw2",
        "raf", "pef", "srw", "3fr", "fff", "iiq", "rwl",
        "raw", "bay", "crw", "dcr", "erf", "kdc", "mdc",
        "mos", "mrw", "nrw", "ptx", "pxn", "r3d", "sr2",
        "srf", "x3f"
    ]
    
    // MARK: - Public Methods
    
    /// Check if native conversion is available for the given input/output format combination
    static func canConvertNatively(from inputExtension: String, to outputExtension: String) -> Bool {
        let input = inputExtension.lowercased()
        let output = outputExtension.lowercased()
        
        return nativeReadFormats.contains(input) && nativeWriteFormats.contains(output)
    }
    
    /// Check if the format is a RAW format
    static func isRAWFormat(_ extension: String) -> Bool {
        return rawFormats.contains(`extension`.lowercased())
    }
    
    /// Convert an image using Apple's native ImageIO framework
    /// - Parameters:
    ///   - inputPath: Path to the source image
    ///   - outputPath: Path for the converted image
    ///   - options: Image conversion options
    ///   - progressHandler: Optional handler for progress updates
    /// - Returns: True if conversion was successful
    static func convert(
        inputPath: String,
        outputPath: String,
        options: ImageOptions,
        progressHandler: ((Double, String) -> Void)? = nil
    ) throws {
        let inputURL = URL(fileURLWithPath: inputPath)
        let outputURL = URL(fileURLWithPath: outputPath)
        let outputExtension = outputURL.pathExtension.lowercased()
        
        progressHandler?(0.1, "Loading image...")
        
        // Try to create image source
        guard let imageSource = CGImageSourceCreateWithURL(inputURL as CFURL, nil) else {
            throw NativeConversionError.failedToLoadImage("Could not create image source from file")
        }
        
        // Get the primary image
        guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw NativeConversionError.failedToLoadImage("Could not extract image from source")
        }
        
        progressHandler?(0.3, "Processing image...")
        
        // Apply transformations
        var processedImage = cgImage
        
        // Auto-orient based on EXIF
        if options.autoOrient {
            processedImage = applyExifOrientation(cgImage, from: imageSource) ?? cgImage
        }
        
        // Resize if needed
        if let maxDim = options.maxDimension, maxDim > 0 {
            processedImage = resizeImage(processedImage, maxDimension: maxDim) ?? processedImage
        }
        
        progressHandler?(0.6, "Encoding output...")
        
        // Determine output type
        guard let outputType = getUTType(for: outputExtension) else {
            throw NativeConversionError.unsupportedFormat("Unsupported output format: \(outputExtension)")
        }
        
        // Create destination
        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            outputType,
            1,
            nil
        ) else {
            throw NativeConversionError.failedToWrite("Could not create image destination")
        }
        
        // Set up destination options
        var destinationOptions: [CFString: Any] = [:]
        
        // Quality (for lossy formats)
        let quality = Double(options.quality) / 100.0
        destinationOptions[kCGImageDestinationLossyCompressionQuality] = quality
        
        // Strip metadata if requested
        if options.stripMetadata {
            destinationOptions[kCGImageDestinationMetadata] = nil
            destinationOptions[kCGImagePropertyExifDictionary] = nil
            destinationOptions[kCGImagePropertyGPSDictionary] = nil
            destinationOptions[kCGImagePropertyIPTCDictionary] = nil
        } else {
            // Copy metadata from source
            if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) {
                destinationOptions[kCGImageDestinationMetadata] = properties
            }
        }
        
        // Add the image to destination
        CGImageDestinationAddImage(destination, processedImage, destinationOptions as CFDictionary)
        
        progressHandler?(0.9, "Finalizing...")
        
        // Write to file
        guard CGImageDestinationFinalize(destination) else {
            throw NativeConversionError.failedToWrite("Failed to write image to destination")
        }
        
        progressHandler?(1.0, "Complete")
    }
    
    /// Convert a RAW image using LibRaw (dcraw_emu) as fallback
    /// - Parameters:
    ///   - inputPath: Path to the RAW file
    ///   - outputPath: Path for the converted image
    ///   - options: Image conversion options
    ///   - librawPath: Path to the LibRaw dcraw_emu executable
    ///   - progressHandler: Optional handler for progress updates
    static func convertWithLibRaw(
        inputPath: String,
        outputPath: String,
        options: ImageOptions,
        librawPath: String,
        progressHandler: ((Double, String) -> Void)? = nil
    ) async throws {
        let outputURL = URL(fileURLWithPath: outputPath)
        let outputExtension = outputURL.pathExtension.lowercased()
        
        progressHandler?(0.1, "Processing RAW with LibRaw...")
        
        // LibRaw outputs to TIFF by default, we may need to convert afterwards
        let tempTiffPath = NSTemporaryDirectory() + UUID().uuidString + ".tiff"
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: librawPath)
        
        // LibRaw arguments for quality output
        var arguments = [
            "-w",           // Use camera white balance
            "-q", "3",      // Use AHD interpolation (high quality)
            "-6",           // Write 16-bit output
            "-T",           // Output TIFF
            "-o", "1",      // sRGB colorspace
            inputPath
        ]
        
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        progressHandler?(0.3, "Running LibRaw...")
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw NativeConversionError.librawFailed(errorString)
        }
        
        // LibRaw creates output file based on input name
        let inputURL = URL(fileURLWithPath: inputPath)
        let librawOutputName = inputURL.deletingPathExtension().lastPathComponent + ".tiff"
        let librawOutputPath = NSTemporaryDirectory() + librawOutputName
        
        progressHandler?(0.6, "Converting to final format...")
        
        // If output is TIFF and file exists, just move it
        if outputExtension == "tiff" || outputExtension == "tif" {
            if FileManager.default.fileExists(atPath: librawOutputPath) {
                try FileManager.default.moveItem(atPath: librawOutputPath, toPath: outputPath)
            }
        } else {
            // Convert TIFF to final format using ImageIO
            if FileManager.default.fileExists(atPath: librawOutputPath) {
                try convert(
                    inputPath: librawOutputPath,
                    outputPath: outputPath,
                    options: options,
                    progressHandler: { progress, message in
                        // Adjust progress to fit in remaining range
                        progressHandler?(0.6 + progress * 0.4, message)
                    }
                )
                
                // Clean up temp file
                try? FileManager.default.removeItem(atPath: librawOutputPath)
            } else {
                throw NativeConversionError.librawFailed("LibRaw output file not found")
            }
        }
        
        progressHandler?(1.0, "Complete")
    }
    
    // MARK: - Private Helpers
    
    /// Get the UTType identifier for a file extension
    private static func getUTType(for extension: String) -> CFString? {
        switch `extension`.lowercased() {
        case "jpg", "jpeg":
            return kUTTypeJPEG
        case "png":
            return kUTTypePNG
        case "gif":
            return kUTTypeGIF
        case "tiff", "tif":
            return kUTTypeTIFF
        case "bmp":
            return kUTTypeBMP
        case "heic", "heif":
            if #available(macOS 10.13, *) {
                return "public.heic" as CFString
            }
            return nil
        case "jp2":
            return kUTTypeJPEG2000
        case "pdf":
            return kUTTypePDF
        default:
            return nil
        }
    }
    
    /// Apply EXIF orientation to an image
    private static func applyExifOrientation(_ image: CGImage, from source: CGImageSource) -> CGImage? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let orientationValue = properties[kCGImagePropertyOrientation] as? UInt32,
              let orientation = CGImagePropertyOrientation(rawValue: orientationValue) else {
            return image
        }
        
        // If orientation is normal, no transformation needed
        if orientation == .up {
            return image
        }
        
        let width = image.width
        let height = image.height
        
        var transform = CGAffineTransform.identity
        var newWidth = width
        var newHeight = height
        
        switch orientation {
        case .up:
            return image
        case .upMirrored:
            transform = CGAffineTransform(translationX: CGFloat(width), y: 0).scaledBy(x: -1, y: 1)
        case .down:
            transform = CGAffineTransform(translationX: CGFloat(width), y: CGFloat(height)).rotated(by: .pi)
        case .downMirrored:
            transform = CGAffineTransform(translationX: 0, y: CGFloat(height)).scaledBy(x: 1, y: -1)
        case .leftMirrored:
            newWidth = height
            newHeight = width
            transform = CGAffineTransform(translationX: CGFloat(height), y: CGFloat(width)).scaledBy(x: -1, y: 1).rotated(by: 3 * .pi / 2)
        case .left:
            newWidth = height
            newHeight = width
            transform = CGAffineTransform(translationX: 0, y: CGFloat(width)).rotated(by: 3 * .pi / 2)
        case .rightMirrored:
            newWidth = height
            newHeight = width
            transform = CGAffineTransform(scaleX: -1, y: 1).rotated(by: .pi / 2)
        case .right:
            newWidth = height
            newHeight = width
            transform = CGAffineTransform(translationX: CGFloat(height), y: 0).rotated(by: .pi / 2)
        }
        
        guard let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: newWidth,
                height: newHeight,
                bitsPerComponent: image.bitsPerComponent,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: image.bitmapInfo.rawValue
              ) else {
            return image
        }
        
        context.concatenate(transform)
        
        switch orientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            context.draw(image, in: CGRect(x: 0, y: 0, width: height, height: width))
        default:
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        
        return context.makeImage()
    }
    
    /// Resize an image to fit within a maximum dimension
    private static func resizeImage(_ image: CGImage, maxDimension: Int) -> CGImage? {
        let width = image.width
        let height = image.height
        
        // Check if resizing is needed
        if width <= maxDimension && height <= maxDimension {
            return image
        }
        
        // Calculate new dimensions maintaining aspect ratio
        let aspectRatio = Double(width) / Double(height)
        var newWidth: Int
        var newHeight: Int
        
        if width > height {
            newWidth = maxDimension
            newHeight = Int(Double(maxDimension) / aspectRatio)
        } else {
            newHeight = maxDimension
            newWidth = Int(Double(maxDimension) * aspectRatio)
        }
        
        guard let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: newWidth,
                height: newHeight,
                bitsPerComponent: image.bitsPerComponent,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: image.bitmapInfo.rawValue
              ) else {
            return image
        }
        
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        
        return context.makeImage()
    }
}

// MARK: - Errors

enum NativeConversionError: LocalizedError {
    case failedToLoadImage(String)
    case unsupportedFormat(String)
    case failedToWrite(String)
    case librawFailed(String)
    case librawNotFound
    
    var errorDescription: String? {
        switch self {
        case .failedToLoadImage(let detail):
            return "Failed to load image: \(detail)"
        case .unsupportedFormat(let format):
            return "Unsupported format: \(format)"
        case .failedToWrite(let detail):
            return "Failed to write image: \(detail)"
        case .librawFailed(let detail):
            return "LibRaw processing failed: \(detail)"
        case .librawNotFound:
            return "LibRaw not found. Install with: brew install libraw"
        }
    }
}
