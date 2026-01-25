//
//  FileQueueView.swift
//  UniConv
//
//  A native macOS Tahoe file queue with Liquid Glass effects
//

import SwiftUI

struct FileQueueView: View {
    @Binding var files: [FileItem]
    @StateObject private var conversionManager = ConversionManager.shared
    @Namespace private var headerNamespace
    
    private var pendingFiles: [FileItem] {
        files.filter { $0.status == .pending }
    }
    
    private var hasFinished: Bool {
        files.contains { $0.status == .completed || $0.status == .cancelled || $0.status == .error }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with actions - using GlassEffectContainer for morph transitions
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    if !pendingFiles.isEmpty {
                        Button(action: convertAll) {
                            Label("Convert All", systemImage: "play.fill")
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .glassEffectID("convertAll", in: headerNamespace)
                    }
                    
                    if hasFinished {
                        Button(action: clearCompleted) {
                            Label("Clear Done", systemImage: "xmark.circle")
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .glassEffectID("clearDone", in: headerNamespace)
                    }
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: pendingFiles.isEmpty)
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: hasFinished)
            
            Divider()
                .padding(.horizontal, 16)
            
            // File list
            LazyVStack(spacing: 8) {
                ForEach(files) { file in
                    FileRowView(file: file, onRemove: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            removeFile(file)
                        }
                    }, onRetry: {
                        retryConversion(file)
                    }, onCancel: {
                        cancelConversion(file)
                    })
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
                }
            }
            .padding(16)
        }
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.background.secondary)
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
    
    private func convertAll() {
        for file in pendingFiles {
            Task {
                await conversionManager.startConversion(for: file)
            }
        }
    }
    
    private func clearCompleted() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            files.removeAll { file in
                file.status == .completed || file.status == .cancelled || file.status == .error
            }
        }
    }
    
    private func removeFile(_ file: FileItem) {
        if file.status == .converting {
            conversionManager.cancelConversion(for: file.id)
        }
        files.removeAll { $0.id == file.id }
    }
    
    private func retryConversion(_ file: FileItem) {
        Task {
            await conversionManager.startConversion(for: file)
        }
    }
    
    private func cancelConversion(_ file: FileItem) {
        conversionManager.cancelConversion(for: file.id)
        file.status = .cancelled
    }
}

struct FileRowView: View {
    @ObservedObject var file: FileItem
    let onRemove: () -> Void
    let onRetry: () -> Void
    let onCancel: () -> Void
    
    @State private var isHovering = false
    @State private var showOptionsSheet = false
    @State private var showLogSheet = false
    @State private var showInfoSheet = false
    @Namespace private var actionNamespace
    
    var body: some View {
        HStack(spacing: 12) {
            // File type icon with background
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(iconBackgroundColor)
                    .frame(width: 36, height: 36)
                
                Image(systemName: FormatUtils.getFileTypeIcon(file.type))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(iconColor)
                    .symbolEffect(.pulse, isActive: file.status == .converting)
            }
            
            // File info
            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(file.name)
                
                statusView
            }
            .frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)
            
            Spacer(minLength: 12)
            
            // Format selector or status indicator
            if file.status == .pending || file.status == .error {
                FormatSelector(file: file)
                
                // Options button
                Button(action: {
                    showOptionsSheet = true
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Conversion options")
            }
            
            // Action buttons
            actionButtons
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isHovering ? Color.secondary.opacity(0.1) : Color.clear)
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .sheet(isPresented: $showOptionsSheet) {
            ConversionOptionsView(file: file)
        }
        .sheet(isPresented: $showLogSheet) {
            ConversionLogView(file: file)
        }
        .sheet(isPresented: $showInfoSheet) {
            FileInfoView(file: file)
        }
    }
    
    @ViewBuilder
    private var statusView: some View {
        switch file.status {
        case .converting:
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: file.progress, total: 100)
                    .progressViewStyle(.linear)
                    .tint(Color.accentColor)
                
                Text(progressText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        case .error:
            HStack(alignment: .top, spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                Text(file.error ?? "Unknown error")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 200, alignment: .leading)
        case .completed:
            Label("Completed", systemImage: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.green)
        case .cancelled:
            Label("Cancelled", systemImage: "xmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
        case .pending:
            Text("Ready to convert")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        // GlassEffectContainer enables morphing between button states
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                // Primary action button - morphs between play/stop/retry
                switch file.status {
                case .pending:
                    Button(action: {
                        Task {
                            await ConversionManager.shared.startConversion(for: file)
                        }
                    }) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.tint(.accentColor).interactive(), in: .circle)
                    .glassEffectID("primaryAction", in: actionNamespace)
                    .help("Start conversion")
                    
                case .converting:
                    Button(action: {
                        onCancel()
                    }) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.orange)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.tint(.orange).interactive(), in: .circle)
                    .glassEffectID("primaryAction", in: actionNamespace)
                    .help("Cancel conversion")
                    
                case .error:
                    Button(action: {
                        onRetry()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.tint(.accentColor).interactive(), in: .circle)
                    .glassEffectID("primaryAction", in: actionNamespace)
                    .help("Retry conversion")
                    
                case .completed, .cancelled:
                    EmptyView()
                }
                
                // Log viewer button - morphs in when available
                if file.status == .converting || file.status == .error || file.status == .completed {
                    Button(action: {
                        showLogSheet = true
                    }) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .glassEffectID("logButton", in: actionNamespace)
                    .help("View conversion log")
                }
                
                // File info button
                Button(action: {
                    showInfoSheet = true
                }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .glassEffectID("infoButton", in: actionNamespace)
                .help("View file info")
                
                // Reveal in Finder button - show for completed files
                if file.status == .completed, let outputPath = file.outputPath {
                    Button(action: {
                        revealInFinder(path: outputPath)
                    }) {
                        Image(systemName: "arrow.up.forward.square")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.green)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.tint(.green).interactive(), in: .circle)
                    .glassEffectID("revealButton", in: actionNamespace)
                    .help("Show in Finder")
                }
                
                // Remove button - always present, morphs with others
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .glassEffectID("removeButton", in: actionNamespace)
                .opacity(isHovering || file.status == .completed || file.status == .cancelled || file.status == .error ? 1 : 0.5)
                .help("Remove")
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: file.status)
    }
    
    private var iconBackgroundColor: Color {
        switch file.type {
        case .video: return .purple.opacity(0.15)
        case .audio: return .pink.opacity(0.15)
        case .image: return .blue.opacity(0.15)
        case .unknown: return .gray.opacity(0.15)
        }
    }
    
    private var iconColor: Color {
        switch file.type {
        case .video: return .purple
        case .audio: return .pink
        case .image: return .blue
        case .unknown: return .gray
        }
    }
    
    private var progressText: String {
        var parts: [String] = ["\(Int(file.progress))%"]
        
        if let speed = file.speed, speed > 0, speed.isFinite {
            parts.append("\(String(format: "%.1f", speed))×")
        }
        
        if let eta = formatEta(file.etaSeconds) {
            parts.append(eta)
        }
        
        return parts.joined(separator: " · ")
    }
    
    private func formatEta(_ seconds: Double?) -> String? {
        guard let seconds = seconds, seconds > 0, seconds.isFinite else { return nil }
        
        if seconds < 60 {
            return "\(Int(seconds))s left"
        } else if seconds < 3600 {
            let mins = Int(seconds / 60)
            let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
            return "\(mins)m \(secs)s left"
        } else {
            let hours = Int(seconds / 3600)
            let mins = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(mins)m left"
        }
    }
    
    private func revealInFinder(path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

#Preview {
    FileQueueView(files: .constant([]))
}
