//
//  FileItem.swift
//  UniConv
//
//  Created on 1/22/2026.
//

import Foundation
import Combine

enum FileType: String, Codable {
    case video
    case audio
    case image
    case unknown
}

enum ConversionStatus: String, Codable {
    case pending
    case converting
    case completed
    case error
    case cancelled
}

class FileItem: ObservableObject, Identifiable {
    let id: UUID
    let path: String
    let name: String
    let type: FileType
    
    @Published var status: ConversionStatus = .pending
    @Published var progress: Double = 0.0
    @Published var selectedFormat: String
    @Published var availableFormats: [String]
    @Published var outputPath: String?
    @Published var error: String?
    @Published var options: ConversionOptions = .default
    
    // FFmpeg progress details
    @Published var fps: Double?
    @Published var frame: Int?
    @Published var speed: Double?
    @Published var etaSeconds: Double?
    @Published var conversionLog: String = ""
    
    init(id: UUID = UUID(), path: String, name: String, type: FileType, 
         selectedFormat: String, availableFormats: [String]) {
        self.id = id
        self.path = path
        self.name = name
        self.type = type
        self.selectedFormat = selectedFormat
        self.availableFormats = availableFormats
    }
}

struct ConversionProgress {
    let fileId: UUID
    let percent: Double
    let currentTime: Double?
    let totalDuration: Double?
    let fps: Double?
    let frame: Int?
    let speed: Double?
    let etaSeconds: Double?
}
