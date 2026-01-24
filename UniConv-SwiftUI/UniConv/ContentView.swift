//
//  ContentView.swift
//  UniConv
//
//  Created on 1/22/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var files: [FileItem] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Title bar spacer (for draggable area)
            Color.clear
                .frame(height: 28)
            
            // Main content
            ScrollView {
                VStack(spacing: 16) {
                    DropZoneView(files: $files)
                    
                    if !files.isEmpty {
                        FileQueueView(files: $files)
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(VisualEffectBackground(material: .underWindowBackground, blendingMode: .behindWindow))
    }
}

// Native macOS visual effect view for liquid glass effect
struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

#Preview {
    ContentView()
        .frame(width: 600, height: 700)
}
