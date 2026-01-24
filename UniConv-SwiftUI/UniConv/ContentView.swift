//
//  ContentView.swift
//  UniConv
//
//  A native macOS Tahoe application with Liquid Glass effects
//

import SwiftUI

struct ContentView: View {
    @State private var files: [FileItem] = []
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    DropZoneView(files: $files)
                        .padding(.top, 8)
                    
                    if !files.isEmpty {
                        FileQueueView(files: $files)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: files.isEmpty)
            }
            .scrollContentBackground(.hidden)
            .background(.background)
            .navigationTitle("UniConv")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if !files.isEmpty {
                        Text("\(files.count) \(files.count == 1 ? "file" : "files")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 620, height: 720)
}
