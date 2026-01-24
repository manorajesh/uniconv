//
//  ProgressBarView.swift
//  UniConv
//
//  Created on 1/22/2026.
//

import SwiftUI

struct ProgressBarView: View {
    let progress: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                    .fill(.ultraThinMaterial)
                    .opacity(0.5)
                
                // Progress fill with gradient
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(0.8),
                                Color.accentColor
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * (progress / 100))
                    .shadow(color: Color.accentColor.opacity(0.5), radius: 3, x: 0, y: 0)
            }
        }
        .frame(height: 6)
    }
}
