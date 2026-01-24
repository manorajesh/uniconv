//
//  FormatSelector.swift
//  UniConv
//
//  A native macOS Tahoe format picker
//

import SwiftUI

struct FormatSelector: View {
    @ObservedObject var file: FileItem
    
    var body: some View {
        Picker("Format", selection: $file.selectedFormat) {
            ForEach(file.availableFormats, id: \.self) { format in
                Text(format.uppercased())
                    .tag(format)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .fixedSize()
        .disabled(file.status == .converting)
    }
}
