//
//  FileInfo.swift
//  UniConv
//
//  Model for storing file metadata information
//

import Foundation

struct FileInfo: Identifiable {
    let id = UUID()
    let path: String
    let filename: String
    let fileSize: Int64
    let formattedSize: String
    
    // Media info (video/audio)
    var duration: String?
    var bitrate: String?
    var codec: String?
    var resolution: String?
    var frameRate: String?
    var audioCodec: String?
    var audioSampleRate: String?
    var audioChannels: String?
    
    // Image info
    var dimensions: String?
    var colorSpace: String?
    var format: String?
    var depth: String?
    
    // Common
    var creationDate: Date?
    var modificationDate: Date?
    
    init(path: String) {
        self.path = path
        self.filename = URL(fileURLWithPath: path).lastPathComponent
        
        // Get file size
        if let attrs = try? FileManager.default.attributesOfItem(atPath: path) {
            self.fileSize = attrs[.size] as? Int64 ?? 0
            self.creationDate = attrs[.creationDate] as? Date
            self.modificationDate = attrs[.modificationDate] as? Date
        } else {
            self.fileSize = 0
        }
        
        self.formattedSize = FileInfo.formatFileSize(fileSize)
    }
    
    static func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: bytes)
    }
}

struct MediaStreamInfo {
    let type: String // "video", "audio", "subtitle"
    let codec: String
    let details: String
}
