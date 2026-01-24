//
//  ConversionLogView.swift
//  UniConv
//
//  View for displaying conversion command logs
//

import SwiftUI

struct ConversionLogView: View {
    @ObservedObject var file: FileItem
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if file.conversionLog.isEmpty {
                            ContentUnavailableView {
                                Label("No Log Data", systemImage: "doc.text")
                            } description: {
                                Text("Conversion output will appear here")
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            Text(file.conversionLog)
                                .font(.system(size: 11, design: .monospaced))
                                .textSelection(.enabled)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id("bottom")
                        }
                    }
                }
                .background(Color(nsColor: .textBackgroundColor))
                .onChange(of: file.conversionLog) { _, _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            .navigationTitle("Conversion Log")
            .navigationSubtitle(file.name)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: copyLog) {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .disabled(file.conversionLog.isEmpty)
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: clearLog) {
                        Label("Clear", systemImage: "trash")
                    }
                    .disabled(file.conversionLog.isEmpty)
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                }
            }
        }
        .frame(width: 700, height: 500)
    }
    
    private func copyLog() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(file.conversionLog, forType: .string)
    }
    
    private func clearLog() {
        file.conversionLog = ""
    }
}


#Preview {
    ConversionLogView(file: {
        let file = FileItem(
            path: "/test/video.mp4",
            name: "video.mp4",
            type: .video,
            selectedFormat: "mp4",
            availableFormats: ["mp4", "webm"]
        )
        file.conversionLog = """
        [FFmpeg] Starting conversion...
        Input #0, mov,mp4,m4a,3gp,3g2,mj2, from 'input.mp4':
          Duration: 00:01:30.00, start: 0.000000, bitrate: 5000 kb/s
          Stream #0:0(und): Video: h264, 1920x1080, 29.97 fps
        Output #0, mp4, to 'output.mp4':
          Stream #0:0(und): Video: libx264, 1920x1080, 29.97 fps
        frame=  100 fps= 45 q=28.0 size=    1024kB time=00:00:03.33 bitrate=2516.3kbits/s speed=1.5x
        """
        return file
    }())
}
