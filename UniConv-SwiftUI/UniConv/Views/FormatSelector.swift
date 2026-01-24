//
//  FormatSelector.swift
//  UniConv
//
//  Created on 1/22/2026.
//

import SwiftUI

struct FormatSelector: View {
    @ObservedObject var file: FileItem
    
    var body: some View {
        Menu {
            ForEach(file.availableFormats, id: \.self) { format in
                Button(format.uppercased()) {
                    file.selectedFormat = format
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(file.selectedFormat.uppercased())
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
            }
            .foregroundColor(.accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor.opacity(0.12))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 0.5)
            )
        }
        .disabled(file.status == .converting)
    }
}
