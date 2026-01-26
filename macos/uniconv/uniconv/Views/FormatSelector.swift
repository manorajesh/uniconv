//
//  FormatSelector.swift
//  UniConv
//
//  A native macOS Tahoe format picker with Liquid Glass
//

import SwiftUI

struct FormatSelector: View {
    @ObservedObject var file: FileItem
    @State private var isHovering = false
    
    var body: some View {
        Menu {
            ForEach(file.availableFormats, id: \.self) { format in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        file.selectedFormat = format
                    }
                }) {
                    HStack {
                        Text(format.uppercased())
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                        if file.selectedFormat == format {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(file.selectedFormat.uppercased())
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .contentTransition(.numericText())
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
        .disabled(file.status == .converting)
        .opacity(file.status == .converting ? 0.6 : 1.0)
    }
}
