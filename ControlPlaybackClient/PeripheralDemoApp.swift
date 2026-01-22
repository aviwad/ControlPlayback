//
//  PeripheralDemoApp.swift
//  PeripheralDemo
//
//  Created by Kevin Lundberg on 3/25/22.
//

import SwiftUI


struct ContentView2: View {
  var header: LocalizedStringKey {
    #if targetEnvironment(simulator)
    return "WARNING: if you run this in the simulator, live bluetooth communication will not work, as CoreBluetooth does not function in the simulator. Run as a mac/mac catalyst app instead."
    #else
    return ""
    #endif
  }
  
  var body: some View {
    NavigationView {
        PeripheralView()
          .navigationTitle("Peripheral")
    }
  }
}
