//
//  FileQueueView.swift
//  UniConv
//
//  A native macOS Tahoe file queue with bold Liquid Glass effects
//

import SwiftUI

struct FileQueueView: View {
    @Binding var files: [FileItem]
    @StateObject private var conversionManager = ConversionManager.shared
    
    private var pendingFiles: [FileItem] {
        files.filter { $0.status == .pending }
    }
    
    private var hasFinished: Bool {
        files.contains { $0.status == .completed || $0.status == .cancelled || $0.status == .error }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with liquid glass action buttons
            HStack(spacing: 16) {
                LiquidSplitButton(
                    showConvertAll: !pendingFiles.isEmpty,
                    showClearDone: hasFinished,
                    onConvertAll: convertAll,
                    onClearDone: clearCompleted
                )
                
                Spacer()
                
                // File count badge
                Text("\(files.count) file\(files.count == 1 ? "" : "s")")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background {
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                    }
                    .glassEffect(.regular, in: .capsule)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            // Divider with gradient
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.2), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .padding(.horizontal, 20)
            
            // File list
            LazyVStack(spacing: 12) {
                ForEach(files) { file in
                    FileRowView(file: file, onRemove: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            removeFile(file)
                        }
                    }, onRetry: {
                        retryConversion(file)
                    }, onCancel: {
                        cancelConversion(file)
                    })
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.92).combined(with: .opacity).combined(with: .blur(radius: 8)),
                        removal: .scale(scale: 0.92).combined(with: .opacity).combined(with: .blur(radius: 8))
                    ))
                }
            }
            .padding(20)
        }
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 10)
    }
    
    private func convertAll() {
        for file in pendingFiles {
            Task {
                await conversionManager.startConversion(for: file)
            }
        }
    }
    
    private func clearCompleted() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
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

// MARK: - Liquid Split Button (splits from one into two with liquid animation)

struct LiquidSplitButton: View {
    let showConvertAll: Bool
    let showClearDone: Bool
    let onConvertAll: () -> Void
    let onClearDone: () -> Void
    
    @State private var convertHovering = false
    @State private var clearHovering = false
    @State private var convertPressed = false
    @State private var clearPressed = false
    
    private var showBoth: Bool {
        showConvertAll && showClearDone
    }
    
    var body: some View {
        HStack(spacing: showBoth ? 12 : 0) {
            // Convert All Button
            if showConvertAll {
                actionButton(
                    title: "Convert All",
                    icon: "play.fill",
                    gradient: [.blue, .purple],
                    isHovering: $convertHovering,
                    isPressed: $convertPressed,
                    action: onConvertAll
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.5, anchor: showClearDone ? .trailing : .center)
                        .combined(with: .opacity)
                        .combined(with: .blur(radius: 10)),
                    removal: .scale(scale: 0.5, anchor: showClearDone ? .trailing : .center)
                        .combined(with: .opacity)
                        .combined(with: .blur(radius: 10))
                ))
            }
            
            // Clear Done Button
            if showClearDone {
                actionButton(
                    title: "Clear Done",
                    icon: "xmark.circle.fill",
                    gradient: [.gray, .gray.opacity(0.7)],
                    isHovering: $clearHovering,
                    isPressed: $clearPressed,
                    action: onClearDone
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.5, anchor: showConvertAll ? .leading : .center)
                        .combined(with: .opacity)
                        .combined(with: .blur(radius: 10)),
                    removal: .scale(scale: 0.5, anchor: showConvertAll ? .leading : .center)
                        .combined(with: .opacity)
                        .combined(with: .blur(radius: 10))
                ))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.3), value: showConvertAll)
        .animation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.3), value: showClearDone)
    }
    
    @ViewBuilder
    private func actionButton(
        title: String,
        icon: String,
        gradient: [Color],
        isHovering: Binding<Bool>,
        isPressed: Binding<Bool>,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                isPressed.wrappedValue = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed.wrappedValue = false
                }
            }
            action()
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background {
                ZStack {
                    // Glow effect
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: gradient.map { $0.opacity(0.6) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blur(radius: isHovering.wrappedValue ? 15 : 8)
                        .offset(y: 4)
                    
                    // Main button
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Glass overlay
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.25), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                    
                    // Border
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                }
            }
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed.wrappedValue ? 0.92 : (isHovering.wrappedValue ? 1.03 : 1.0))
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isHovering.wrappedValue)
        .animation(.spring(response: 0.2, dampingFraction: 0.5), value: isPressed.wrappedValue)
        .onHover { hovering in
            isHovering.wrappedValue = hovering
        }
    }
}

// MARK: - File Row View

struct FileRowView: View {
    @ObservedObject var file: FileItem
    let onRemove: () -> Void
    let onRetry: () -> Void
    let onCancel: () -> Void
    
    @State private var isHovering = false
    @State private var showOptionsSheet = false
    @State private var showLogSheet = false
    
    var body: some View {
        HStack(spacing: 14) {
            // File type icon with glass effect
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(iconGradient)
                    .frame(width: 44, height: 44)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                    }
                    .shadow(color: iconColor.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Image(systemName: FormatUtils.getFileTypeIcon(file.type))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, isActive: file.status == .converting)
            }
            
            // File info
            VStack(alignment: .leading, spacing: 6) {
                Text(file.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                statusView
            }
            
            Spacer(minLength: 8)
            
            // Format selector or status indicator
            if file.status == .pending || file.status == .error {
                FormatSelector(file: file)
                
                // Options button with glass effect
                GlassIconButton(icon: "gearshape.fill", color: .gray) {
                    showOptionsSheet = true
                }
                .help("Conversion options")
            }
            
            // Action buttons
            actionButtons
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(isHovering ? 1 : 0.5))
                
                if isHovering {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .scaleEffect(isHovering ? 1.01 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .sheet(isPresented: $showOptionsSheet) {
            ConversionOptionsView(file: file)
        }
        .sheet(isPresented: $showLogSheet) {
            ConversionLogView(file: file)
        }
    }
    
    @ViewBuilder
    private var statusView: some View {
        switch file.status {
        case .converting:
            VStack(alignment: .leading, spacing: 6) {
                // Custom glass progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.quaternary)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * (file.progress / 100))
                            .animation(.spring(response: 0.3), value: file.progress)
                    }
                }
                .frame(height: 6)
                
                Text(progressText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        case .error:
            Label(file.error ?? "Unknown error", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.red)
                .lineLimit(1)
        case .completed:
            Label("Completed", systemImage: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.green)
        case .cancelled:
            Label("Cancelled", systemImage: "xmark.circle.fill")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.orange)
        case .pending:
            Text("Ready to convert")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 8) {
            switch file.status {
            case .pending:
                GlassIconButton(icon: "play.fill", color: .blue, size: .large) {
                    Task {
                        await ConversionManager.shared.startConversion(for: file)
                    }
                }
                .help("Start conversion")
                
            case .converting:
                GlassIconButton(icon: "stop.fill", color: .orange, size: .large) {
                    onCancel()
                }
                .help("Cancel conversion")
                
            case .error:
                GlassIconButton(icon: "arrow.clockwise", color: .blue, size: .large) {
                    onRetry()
                }
                .help("Retry conversion")
                
            case .completed, .cancelled:
                EmptyView()
            }
            
            // Log viewer button
            if file.status == .converting || file.status == .error || file.status == .completed {
                GlassIconButton(icon: "doc.text.fill", color: .gray) {
                    showLogSheet = true
                }
                .help("View conversion log")
            }
            
            // Remove button
            GlassIconButton(icon: "xmark", color: .gray) {
                onRemove()
            }
            .opacity(isHovering || file.status == .completed || file.status == .cancelled || file.status == .error ? 1 : 0.5)
            .help("Remove")
        }
    }
    
    private var iconGradient: LinearGradient {
        switch file.type {
        case .video:
            return LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .audio:
            return LinearGradient(colors: [.pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .image:
            return LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .unknown:
            return LinearGradient(colors: [.gray, .gray.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
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
}

// MARK: - Glass Icon Button

struct GlassIconButton: View {
    let icon: String
    let color: Color
    var size: ButtonSize = .regular
    let action: () -> Void
    
    enum ButtonSize {
        case regular, large
        
        var iconSize: CGFloat {
            switch self {
            case .regular: return 14
            case .large: return 16
            }
        }
        
        var padding: CGFloat {
            switch self {
            case .regular: return 8
            case .large: return 10
            }
        }
    }
    
    @State private var isHovering = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    isPressed = false
                }
            }
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: size.iconSize, weight: .semibold))
                .foregroundStyle(isHovering ? color : .secondary)
                .padding(size.padding)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial.opacity(isHovering ? 1 : 0.6))
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    isHovering ? color.opacity(0.5) : .white.opacity(0.2),
                                    lineWidth: 1
                                )
                        }
                }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.85 : (isHovering ? 1.1 : 1.0))
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isHovering)
        .animation(.spring(response: 0.15, dampingFraction: 0.5), value: isPressed)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

extension AnyTransition {
    static func blur(radius: CGFloat) -> AnyTransition {
        AnyTransition.modifier(
            active: BlurTransitionModifier(radius: radius),
            identity: BlurTransitionModifier(radius: 0)
        )
    }
}
private struct BlurTransitionModifier: ViewModifier {
    let radius: CGFloat
    func body(content: Content) -> some View {
        content.blur(radius: radius)
    }
}

