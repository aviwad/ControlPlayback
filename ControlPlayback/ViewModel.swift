//
//  ViewModel.swift
//  ControlPlayback
//
//  Created by Avi Wadhwa on 2025-12-24.
//


import Swift
import SwiftUI
import MediaRemoteAdapter
import MultipeerConnectivity

@Observable class ViewModel {
    @ObservationIgnored let mediaController = MediaController()
    @ObservationIgnored var currentBrowser: SupportedBrowsers = .safari
    var currentTitle: String = ""
    var mediaLength: Duration = .seconds(0)
    var currentProgress: Duration = .seconds(0)
    var isPlaying: Bool = false
    var trackInfoUpdate: Bool = false
    
    init() {
        print("ViewModel: Init")
        mediaController.onTrackInfoReceived = { trackInfo, _ in
            guard let trackInfo = trackInfo else {
                print("No media playing")
                return
            }
            print("Now Playing: \(trackInfo.title ?? "N/A")")
            print("Current progress: \(trackInfo.elapsedTimeMicros ?? 0)")
            self.currentTitle = trackInfo.title ?? ""
            self.mediaLength = .microseconds(trackInfo.durationMicros ?? 0)
            self.currentProgress = .microseconds(trackInfo.elapsedTimeMicros ?? 0)
            self.isPlaying = trackInfo.isPlaying ?? false
            self.trackInfoUpdate.toggle()
        }

        // Handle listener termination
        mediaController.onListenerTerminated = {
            print("Listener terminated")
        }
        
        mediaController.startListening()
    }
    
    func setPosition(_ seconds: Int) {
        print("calling set time with \(seconds) on media controller...")
        mediaController.setTime(seconds: Double(seconds))
    }
    
    func playPause() {
        mediaController.togglePlayPause()
    }
    

    
}
