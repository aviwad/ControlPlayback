//
//  DurationExtension.swift
//  ControlPlayback
//
//  Created by Avi Wadhwa on 2025-12-25.
//

extension Duration {
    var secondsAsDouble: Double {
        let components = self.components
        return Double(components.seconds)
             + Double(components.attoseconds) / 1_000_000_000_000_000_000
    }
}
