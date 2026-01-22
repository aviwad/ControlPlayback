//
//  ContentView.swift
//  ControlPlayback
//
//  Created by Avi Wadhwa on 2026-01-20.
//

import SwiftUI
import MultipeerConnectivity
import CombineCoreBluetooth

struct ContentView: View {
    @Binding var viewModel: ViewModel
    var onPlayPause: (Bool) -> Void
    var onScrub: (Double) -> Void
    
    private var progressValue: Double {
        let total = viewModel.mediaLength.asSeconds
        let current = viewModel.currentProgress.asSeconds
        guard total > 0 else { return 0 }
        return min(max(current / total, 0), 1)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text(viewModel.currentTitle)
                .font(.headline)
            
            // Progress bar
            ProgressView(value: viewModel.currentProgress.asSeconds,
                         total: max(viewModel.mediaLength.asSeconds, 0.000_001))
                .progressViewStyle(.linear)
                .frame(maxWidth: 400)
            
            // Optional readable time labels
            HStack {
                Text(viewModel.currentProgress.formattedAsHMS)
                Spacer()
                Button {
                    onPlayPause(viewModel.isPlaying)
                } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                }
                Spacer()
                Text(viewModel.mediaLength.formattedAsHMS)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: 400)
        }
        .padding()
    }
}

private extension Duration {
    // Convert Duration to seconds as Double
    var asSeconds: Double {
        let comps = components
        return Double(comps.seconds) + Double(comps.attoseconds) / 1e18
    }
    
    // Format as mm:ss or hh:mm:ss
    var formattedAsHMS: String {
        let totalSeconds = Int((asSeconds).rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

