//
//  FormatSelector.swift
//  UniConv
//
//  A native macOS Tahoe format picker with Liquid Glass styling
//

import SwiftUI

struct FormatSelector: View {
    @ObservedObject var file: FileItem
    @State private var isHovering = false
    
    var body: some View {
        Menu {
            ForEach(file.availableFormats, id: \.self) { format in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        file.selectedFormat = format
                    }
                }) {
                    HStack {
                        Text(format.uppercased())
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        if file.selectedFormat == format {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(file.selectedFormat.uppercased())
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            isHovering ? Color.accentColor.opacity(0.5) : .white.opacity(0.2),
                            lineWidth: 1
                        )
                }
            }
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 10))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(file.status == .converting)
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
