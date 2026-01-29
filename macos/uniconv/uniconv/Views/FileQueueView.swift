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
            
            // File list with glass morphing transitions
            LazyVStack(spacing: 8) {
                ForEach(files) { file in
                    FileRowView(file: file, onRemove: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            removeFile(file)
                        }
                    }, onRetry: {
                        retryConversion(file)
                    }, onCancel: {
                        cancelConversion(file)
                    })
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity).combined(with: .move(edge: .top)),
                            removal: .scale(scale: 0.85).combined(with: .opacity)
                        )
                    )
                }
            }
            .padding(16)
        }
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.background.secondary.opacity(0.5))
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
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
    @State private var isEditingName = false
    @State private var editedName: String = ""
    @State private var showReplaceAlert = false
    @State private var renameError: String? = nil
    @Namespace private var actionNamespace
    @FocusState private var isNameFieldFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // File type icon with background and glass effect
            ZStack {
                Image(systemName: FormatUtils.getFileTypeIcon(file.type))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(iconColor)
                    .symbolEffect(.pulse, isActive: file.status == .converting)
                    .frame(width: 36, height: 36)
            }
            .glassEffect(.regular.tint(iconColor.opacity(0.3)), in: .rect(cornerRadius: 10))
            
            // File info
            VStack(alignment: .leading, spacing: 4) {
                if isEditingName {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            HStack(spacing: 0) {
                                TextField("Filename", text: $editedName)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 13, weight: .medium))
                                    .focused($isNameFieldFocused)
                                    .onSubmit {
                                        commitRename()
                                    }
                                    .onChange(of: editedName) { _, _ in
                                        renameError = nil // Clear error when user types
                                    }
                                Text(".\(file.selectedFormat)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.primary.opacity(0.1))
                            }
                            
                            // Cancel button
                            Button {
                                cancelRename()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Cancel rename")
                        }
                        
                        if let error = renameError {
                            Text(error)
                                .font(.system(size: 10))
                                .foregroundStyle(.red)
                        }
                    }
                    .onAppear {
                        isNameFieldFocused = true
                    }
                } else {
                    Text(file.outputDisplayName)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help("Output: \(file.outputDisplayName)\nOriginal: \(file.name)")
                        .onTapGesture(count: 2) {
                            startRename()
                        }
                        .contextMenu {
                            Button {
                                startRename()
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            
                            Divider()
                            
                            Button {
                                showInfoSheet = true
                            } label: {
                                Label("Get Info", systemImage: "info.circle")
                            }
                            
                            if file.status == .completed, let outputPath = file.outputPath {
                                Button {
                                    revealInFinder(path: outputPath)
                                } label: {
                                    Label("Show in Finder", systemImage: "arrow.up.forward.square")
                                }
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                onRemove()
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                }
                
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
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isHovering ? Color.secondary.opacity(0.08) : Color.clear)
        }
        .glassEffect(isHovering ? .regular : .identity, in: .rect(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
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
        .alert("File Already Exists", isPresented: $showReplaceAlert) {
            Button("Replace", role: .destructive) {
                forceCommitRename()
            }
            Button("Cancel", role: .cancel) {
                // Keep editing mode active so user can change the name
            }
        } message: {
            Text("A file named \"\(editedName).\(file.selectedFormat)\" already exists in the output folder. Do you want to replace it?")
        }
    }
    
    @ViewBuilder
    private var statusView: some View {
        Group {
            switch file.status {
            case .converting:
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: file.progress, total: 100)
                        .progressViewStyle(.linear)
                        .tint(Color.accentColor)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: file.progress)
                    
                    HStack(spacing: 0) {
                        Text("\(Int(file.progress))%")
                            .contentTransition(.numericText(countsDown: false))
                        
                        if let speed = file.speed, speed > 0, speed.isFinite {
                            Text(" · ")
                            Text("\(String(format: "%.1f", speed))×")
                                .contentTransition(.numericText())
                        }
                        
                        if let eta = formattedEta {
                            Text(" · ")
                            Text(eta)
                                .contentTransition(.numericText(countsDown: true))
                        }
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: file.progress)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: file.speed)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: file.etaSeconds)
                }
            case .error:
                ErrorStatusView(errorMessage: file.error)
            case .completed:
                Label("Completed", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: file.status)
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
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: file.status)
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
    
    private var formattedEta: String? {
        formatEta(file.etaSeconds)
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
    
    private func startRename() {
        // Get the base name without extension for editing
        if let custom = file.customOutputName, !custom.isEmpty {
            editedName = custom
        } else {
            editedName = (file.name as NSString).deletingPathExtension
        }
        renameError = nil
        isEditingName = true
    }
    
    private func cancelRename() {
        isEditingName = false
        renameError = nil
    }
    
    private func commitRename() {
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate filename
        if trimmed.isEmpty {
            renameError = "Filename cannot be empty"
            return
        }
        
        // Check for invalid characters (macOS filesystem restrictions)
        let invalidCharacters = CharacterSet(charactersIn: "/:\\")
        if trimmed.unicodeScalars.contains(where: { invalidCharacters.contains($0) }) {
            renameError = "Filename cannot contain / : or \\"
            return
        }
        
        // Check if filename starts with a dot (hidden file)
        if trimmed.hasPrefix(".") {
            renameError = "Filename cannot start with a dot"
            return
        }
        
        // Check if the output file already exists
        if checkOutputFileExists(filename: trimmed) {
            showReplaceAlert = true
            return
        }
        
        // All validations passed
        forceCommitRename()
    }
    
    private func forceCommitRename() {
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        file.customOutputName = trimmed
        isEditingName = false
        renameError = nil
    }
    
    private func checkOutputFileExists(filename: String) -> Bool {
        let inputURL = URL(fileURLWithPath: file.path)
        
        // Determine output directory
        let defaultOutputFolder = UserDefaults.standard.string(forKey: "defaultOutputFolder") ?? ""
        let directory: URL
        if !defaultOutputFolder.isEmpty && FileManager.default.fileExists(atPath: defaultOutputFolder) {
            directory = URL(fileURLWithPath: defaultOutputFolder)
        } else {
            directory = inputURL.deletingLastPathComponent()
        }
        
        let outputPath = directory.appendingPathComponent("\(filename).\(file.selectedFormat)").path
        return FileManager.default.fileExists(atPath: outputPath)
    }
    
    private func revealInFinder(path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

// MARK: - Error Status View

struct ErrorStatusView: View {
    let errorMessage: String?
    @State private var isExpanded = false
    
    private var errorParts: (summary: String, suggestion: String?) {
        guard let message = errorMessage else {
            return ("Unknown error", nil)
        }
        
        // Split by the suggestion marker
        let parts = message.components(separatedBy: "\n\n💡 ")
        if parts.count >= 2 {
            return (parts[0], parts[1])
        }
        return (message, nil)
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.red)
                .symbolEffect(.pulse, options: .repeating)
            
            Text(errorParts.summary)
                .font(.system(size: 11))
                .foregroundStyle(.red)
                .lineLimit(1)
            
            if errorParts.suggestion != nil {
                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $isExpanded, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(errorParts.summary, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.red)
                        
                        if let suggestion = errorParts.suggestion {
                            Divider()
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.yellow)
                                Text(suggestion)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(12)
                    .frame(width: 280)
                }
                .help("Show error details")
            }
        }
    }
}

