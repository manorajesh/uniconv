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
    static let imageExtensions = ["png", "jpg", "jpeg", "gif", "webp", "bmp", "tiff", "svg"]
    
    static let videoOutputFormats = ["mp4", "webm", "mkv", "mov", "gif", "mp3"]
    static let audioOutputFormats = ["mp3", "wav", "flac", "aac", "ogg", "m4a"]
    static let imageOutputFormats = ["png", "jpg", "webp", "pdf", "bmp", "tiff"]
    
    static func getFileType(_ extension: String) -> FileType {
        let ext = `extension`.lowercased()
        
        if videoExtensions.contains(ext) { return .video }
        if audioExtensions.contains(ext) { return .audio }
        if imageExtensions.contains(ext) { return .image }
        
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
}
