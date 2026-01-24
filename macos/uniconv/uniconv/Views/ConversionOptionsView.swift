//
//  ConversionOptionsView.swift
//  UniConv
//
//  Options editor with Liquid Glass effects
//

import SwiftUI

struct ConversionOptionsView: View {
    @ObservedObject var file: FileItem
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                MeshGradient(
                    width: 2,
                    height: 2,
                    points: [
                        [0.0, 0.0], [1.0, 0.0],
                        [0.0, 1.0], [1.0, 1.0]
                    ],
                    colors: [
                        .purple.opacity(0.08), .blue.opacity(0.08),
                        .pink.opacity(0.08), .cyan.opacity(0.08)
                    ]
                )
                .ignoresSafeArea()
                
                Form {
                    switch file.type {
                    case .video:
                        videoOptionsSection
                    case .audio:
                        audioOptionsSection
                    case .image:
                        imageOptionsSection
                    case .unknown:
                        Section {
                            ContentUnavailableView {
                                Label("No Options", systemImage: "slider.horizontal.3")
                            } description: {
                                Text("No options available for this file type")
                            }
                        }
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Conversion Options")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { dismiss() }) {
                        Text("Done")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.return)
                }
            }
        }
        .frame(width: 520, height: 480)
    }
    
    // MARK: - Video Options
    
    @ViewBuilder
    private var videoOptionsSection: some View {
        Section("Video Quality") {
            Picker("Quality Preset", selection: $file.options.video.quality) {
                ForEach(VideoOptions.VideoQuality.allCases, id: \.self) { quality in
                    Text(quality.rawValue).tag(quality)
                }
            }
            
            if file.options.video.quality == .custom {
                LabeledContent("CRF (lower = better)") {
                    Text("Use advanced settings")
                        .foregroundStyle(.secondary)
                }
            }
        }
        
        Section("Video Settings") {
            Picker("Resolution", selection: $file.options.video.resolution) {
                ForEach(VideoOptions.VideoResolution.allCases, id: \.self) { res in
                    Text(res.rawValue).tag(res)
                }
            }
            
            Picker("Codec", selection: $file.options.video.codec) {
                ForEach(VideoOptions.VideoCodec.allCases, id: \.self) { codec in
                    Text(codec.rawValue).tag(codec)
                }
            }
            
            Toggle("Limit FPS", isOn: Binding(
                get: { file.options.video.fps != nil },
                set: { if $0 { file.options.video.fps = 30 } else { file.options.video.fps = nil } }
            ))
            
            if file.options.video.fps != nil {
                Stepper(value: Binding(
                    get: { file.options.video.fps ?? 30 },
                    set: { file.options.video.fps = $0 }
                ), in: 10...60, step: 5) {
                    Text("FPS: \(file.options.video.fps ?? 30)")
                }
            }
        }
        
        Section("Audio (in video)") {
            Picker("Audio Bitrate", selection: $file.options.audio.bitrate) {
                ForEach(AudioOptions.AudioBitrate.allCases, id: \.self) { bitrate in
                    Text(bitrate.rawValue).tag(bitrate)
                }
            }
        }
        
        Section {
            previewDescription
        }
    }
    
    // MARK: - Audio Options
    
    @ViewBuilder
    private var audioOptionsSection: some View {
        Section("Audio Quality") {
            Picker("Quality", selection: $file.options.audio.quality) {
                ForEach(AudioOptions.AudioQuality.allCases, id: \.self) { quality in
                    Text(quality.rawValue).tag(quality)
                }
            }
            
            Picker("Bitrate", selection: $file.options.audio.bitrate) {
                ForEach(AudioOptions.AudioBitrate.allCases, id: \.self) { bitrate in
                    Text(bitrate.rawValue).tag(bitrate)
                }
            }
        }
        
        Section("Audio Settings") {
            Toggle("Custom Sample Rate", isOn: Binding(
                get: { file.options.audio.sampleRate != nil },
                set: { if $0 { file.options.audio.sampleRate = 44100 } else { file.options.audio.sampleRate = nil } }
            ))
            
            if file.options.audio.sampleRate != nil {
                Picker("Sample Rate", selection: Binding(
                    get: { file.options.audio.sampleRate ?? 44100 },
                    set: { file.options.audio.sampleRate = $0 }
                )) {
                    Text("22.05 kHz").tag(22050)
                    Text("44.1 kHz").tag(44100)
                    Text("48 kHz").tag(48000)
                    Text("96 kHz").tag(96000)
                }
            }
        }
        
        Section {
            previewDescription
        }
    }
    
    // MARK: - Image Options
    
    @ViewBuilder
    private var imageOptionsSection: some View {
        Section("Image Quality") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Quality: \(file.options.image.quality)%")
                    Spacer()
                    Text(qualityDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Slider(value: Binding(
                    get: { Double(file.options.image.quality) },
                    set: { file.options.image.quality = Int($0) }
                ), in: 1...100, step: 1)
            }
        }
        
        Section("Image Settings") {
            Toggle("Auto-orient (fix rotation)", isOn: $file.options.image.autoOrient)
            Toggle("Strip metadata", isOn: $file.options.image.stripMetadata)
            
            Toggle("Resize", isOn: Binding(
                get: { file.options.image.maxDimension != nil },
                set: { if $0 { file.options.image.maxDimension = 1920 } else { file.options.image.maxDimension = nil } }
            ))
            
            if file.options.image.maxDimension != nil {
                Picker("Max dimension", selection: Binding(
                    get: { file.options.image.maxDimension ?? 1920 },
                    set: { file.options.image.maxDimension = $0 }
                )) {
                    Text("4K (3840px)").tag(3840)
                    Text("Full HD (1920px)").tag(1920)
                    Text("HD (1280px)").tag(1280)
                    Text("SD (640px)").tag(640)
                }
            }
        }
        
        Section {
            previewDescription
        }
    }
    
    // MARK: - Preview
    
    @ViewBuilder
    private var previewDescription: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Preview", systemImage: "info.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            
            Text(conversionDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
    
    private var qualityDescription: String {
        switch file.options.image.quality {
        case 90...100: return "Excellent"
        case 75..<90: return "Good"
        case 50..<75: return "Fair"
        default: return "Low"
        }
    }
    
    private var conversionDescription: String {
        switch file.type {
        case .video:
            var parts: [String] = []
            parts.append("Quality: \(file.options.video.quality.rawValue)")
            if file.options.video.resolution != .original {
                parts.append("Resolution: \(file.options.video.resolution.rawValue)")
            }
            if file.options.video.codec != .auto {
                parts.append("Codec: \(file.options.video.codec.rawValue)")
            }
            if let fps = file.options.video.fps {
                parts.append("FPS: \(fps)")
            }
            parts.append("Audio: \(file.options.audio.bitrate.rawValue)")
            return parts.joined(separator: " • ")
            
        case .audio:
            var parts: [String] = []
            parts.append("Quality: \(file.options.audio.quality.rawValue)")
            parts.append("Bitrate: \(file.options.audio.bitrate.rawValue)")
            if let sampleRate = file.options.audio.sampleRate {
                parts.append("Sample Rate: \(Double(sampleRate) / 1000) kHz")
            }
            return parts.joined(separator: " • ")
            
        case .image:
            var parts: [String] = []
            parts.append("Quality: \(file.options.image.quality)%")
            if let maxDim = file.options.image.maxDimension {
                parts.append("Max: \(maxDim)px")
            }
            if file.options.image.stripMetadata {
                parts.append("Strip metadata")
            }
            return parts.joined(separator: " • ")
            
        case .unknown:
            return "No options available"
        }
    }
}

#Preview {
    ConversionOptionsView(file: FileItem(
        path: "/test/video.mp4",
        name: "video.mp4",
        type: .video,
        selectedFormat: "mp4",
        availableFormats: ["mp4", "webm", "mkv"]
    ))
}
