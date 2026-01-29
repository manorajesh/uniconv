//
//  ConversionOptions.swift
//  UniConv
//
//  Conversion options for different file types
//

import Foundation

// MARK: - Video Options
struct VideoOptions: Codable {
    var quality: VideoQuality = .balanced
    var resolution: VideoResolution = .original
    var codec: VideoCodec = .auto
    var fps: Int?
    
    enum VideoQuality: String, Codable, CaseIterable {
        case high = "High Quality"
        case balanced = "Balanced"
        case low = "Low Quality"
        case custom = "Custom"
        
        var crf: Int {
            switch self {
            case .high: return 18
            case .balanced: return 23
            case .low: return 28
            case .custom: return 23
            }
        }
    }
    
    enum VideoResolution: String, Codable, CaseIterable {
        case original = "Original"
        case uhd = "4K (3840×2160)"
        case fullHD = "1080p (1920×1080)"
        case hd = "720p (1280×720)"
        case sd = "480p (854×480)"
        
        var ffmpegScale: String? {
            switch self {
            case .original: return nil
            case .uhd: return "3840:2160"
            case .fullHD: return "1920:1080"
            case .hd: return "1280:720"
            case .sd: return "854:480"
            }
        }
    }
    
    enum VideoCodec: String, Codable, CaseIterable {
        case auto = "Auto"
        case h264 = "H.264"
        case h265 = "H.265/HEVC"
        case vp9 = "VP9"
        
        var ffmpegCodec: String? {
            switch self {
            case .auto: return nil
            case .h264: return "libx264"
            case .h265: return "libx265"
            case .vp9: return "libvpx-vp9"
            }
        }
    }
}

// MARK: - Audio Options
struct AudioOptions: Codable {
    var quality: AudioQuality = .high
    var bitrate: AudioBitrate = .k192
    var sampleRate: Int?
    
    enum AudioQuality: String, Codable, CaseIterable {
        case highest = "Highest"
        case high = "High"
        case medium = "Medium"
        case low = "Low"
    }
    
    enum AudioBitrate: String, Codable, CaseIterable {
        case k320 = "320 kbps"
        case k256 = "256 kbps"
        case k192 = "192 kbps"
        case k128 = "128 kbps"
        case k96 = "96 kbps"
        
        var value: String {
            switch self {
            case .k320: return "320k"
            case .k256: return "256k"
            case .k192: return "192k"
            case .k128: return "128k"
            case .k96: return "96k"
            }
        }
    }
}

// MARK: - Image Options
struct ImageOptions: Codable {
    var quality: Int = 90
    var maxDimension: Int?
    var stripMetadata: Bool = true
    var autoOrient: Bool = true
    var engine: ImageConversionEngine = .auto
    
    /// Determines whether to use native conversion based on input/output formats
    func shouldUseNativeConversion(inputExtension: String, outputExtension: String) -> Bool {
        switch engine {
        case .native:
            return true
        case .imagemagick:
            return false
        case .auto:
            return NativeImageConverter.canConvertNatively(from: inputExtension, to: outputExtension)
        }
    }
}

// MARK: - Combined Options
struct ConversionOptions: Codable {
    var video: VideoOptions = VideoOptions()
    var audio: AudioOptions = AudioOptions()
    var image: ImageOptions = ImageOptions()
    
    static let `default` = ConversionOptions()
}
