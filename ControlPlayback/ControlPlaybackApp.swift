//
//  ControlPlaybackApp.swift
//  ControlPlayback
//
//  Created by Avi Wadhwa on 2025-12-24.
//

import SwiftUI

@main
struct ControlPlaybackApp: App {
    var body: some Scene {
        MenuBarExtra {
            ContentView2()
        } label: {
            Image(systemName: "appletvremote.gen1")
        }
        .menuBarExtraStyle(.window)
    }
}
