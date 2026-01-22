//
//  PlaybackInformation.swift
//  ControlPlayback
//
//  Created by Avi Wadhwa on 2025-12-25.
//
import Foundation

struct PlaybackInformation: Codable {
    let title: String
    let currentTimestamp: Duration
    let TotalTimestamp: Duration
    let isPlaying: Bool
//    let currentArt: Data?
//    
//    func data() -> Data? {
//        try? JSONEncoder().encode(self)
//    }
}

struct UpdatedPlaybackInput: Codable {
    let isPlaying: Bool?
    let scrubbedTime: Duration?
    
    func data() -> Data? {
        try? JSONEncoder().encode(self)
    }
}
