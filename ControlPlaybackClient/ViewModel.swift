//
//  ViewModel.swift
//  ControlPlayback
//
//  Created by Avi Wadhwa on 2025-12-25.
//

import MediaPlayer
import SwiftUI
import MultipeerConnectivity

@Observable class ViewModel {
    var sendIsPlaying: ((Bool) -> Void)
    var sendScrubposition: ((TimeInterval) -> Void)
    var currentTitle: String = ""
//    var currentArt: NSImage?
    var mediaLength: Duration = .seconds(0)
    var currentProgress: Duration = .seconds(0)
    var isPlaying: Bool = false
    
    let player: AVAudioPlayer
    
    init(sendIsPlaying: @escaping (Bool) -> Void, sendScrubposition: @escaping (TimeInterval) -> Void) {
        self.sendIsPlaying = sendIsPlaying
        self.sendScrubposition = sendScrubposition
        guard let url = Bundle.main.url(forResource: "2-minutes-and-30-seconds-of-silence", withExtension: "mp3") else {
            fatalError("Missing silence file in bundle")
        }
        player = try! AVAudioPlayer(contentsOf: url)
        
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { event in
            // Handle play command
            self.sendIsPlaying(self.isPlaying)
            return .success
        }

        commandCenter.pauseCommand.addTarget { event in
            // Handle pause command
            self.sendIsPlaying(self.isPlaying)
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { event in
            let positionEvent = event as! MPChangePlaybackPositionCommandEvent
            print("NEW POSITION TIME IS: \(positionEvent.positionTime)")
            // Seek your player to positionEvent.positionTime
            self.sendScrubposition(positionEvent.positionTime)
            return .success
        }

        UIApplication.shared.beginReceivingRemoteControlEvents()
        
    }
    
    
    func playPause() {
        
    }
    
    func apply(_ info: PlaybackInformation) {
        currentTitle = info.title
        mediaLength = info.TotalTimestamp
        currentProgress = info.currentTimestamp
        isPlaying = info.isPlaying
        
        if isPlaying {
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            player.numberOfLoops = -1
            player.play()
        }
        
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: currentTitle,
            MPNowPlayingInfoPropertyIsLiveStream: false,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentProgress.components.seconds,
            MPMediaItemPropertyPlaybackDuration: mediaLength.components.seconds,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]

        // Optional extras
        // info[MPMediaItemPropertyArtist] = …
        // info[MPMediaItemPropertyAlbumTitle] = …
        // info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: size) { _ in image }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        
        if !isPlaying {
            player.stop()
        }
//        player.stop()
    }
}
