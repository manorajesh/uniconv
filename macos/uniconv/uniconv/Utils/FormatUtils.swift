//
//  FormatUtils.swift
//  UniConv
//
//  Created on 1/22/2026.
//

import Foundation

struct FormatUtils {
    static let videoExtensions = ["mp4", "mkv", "avi", "mov", "webm", "flv", "wmv", "m4v"]
    static let audioExtensions = ["mp3", "wav", "flac", "aac", "ogg", "m4a", "wma"]
    
    // Standard image formats
    static let imageExtensions = [
        "png", "jpg", "jpeg", "gif", "webp", "bmp", "tiff", "tif", "svg",
        "heic", "heif", "ico", "icns", "psd", "jp2"
    ]
    
    // RAW image formats from cameras
    static let rawImageExtensions = [
        "dng", "cr2", "cr3", "nef", "arw", "orf", "rw2",
        "raf", "pef", "srw", "3fr", "fff", "iiq", "rwl",
        "raw", "bay", "crw", "dcr", "erf", "kdc", "mdc",
        "mos", "mrw", "nrw", "ptx", "pxn", "r3d", "sr2",
        "srf", "x3f"
    ]
    
    // All supported image formats (standard + raw)
    static let allImageExtensions: [String] = {
        var all = imageExtensions
        all.append(contentsOf: rawImageExtensions)
        return all
    }()
    
    static let videoOutputFormats = ["mp4", "webm", "mkv", "mov", "gif", "mp3"]
    static let audioOutputFormats = ["mp3", "wav", "flac", "aac", "ogg", "m4a"]
    static let imageOutputFormats = ["png", "jpg", "webp", "pdf", "bmp", "tiff", "heic"]
    
    static func getFileType(_ extension: String) -> FileType {
        let ext = `extension`.lowercased()
        
        if videoExtensions.contains(ext) { return .video }
        if audioExtensions.contains(ext) { return .audio }
        if allImageExtensions.contains(ext) { return .image }
        
        return .unknown
    }
    
    static func getOutputFormats(_ fileType: FileType) -> [String] {
        switch fileType {
        case .video:
            return videoOutputFormats
        case .audio:
            return audioOutputFormats
        case .image:
            return imageOutputFormats
        case .unknown:
            return []
        }
    }
    
    static func getFileTypeIcon(_ fileType: FileType) -> String {
        switch fileType {
        case .video:
            return "film"
        case .audio:
            return "music.note"
        case .image:
            return "photo"
        case .unknown:
            return "doc"
        }
    }
    
    /// Check if the extension is a RAW camera format
    static func isRAWFormat(_ extension: String) -> Bool {
        return rawImageExtensions.contains(`extension`.lowercased())
    }
}