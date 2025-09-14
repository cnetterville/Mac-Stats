//
//  View+Snapshot.swift
//  Mac Stats
//
//  Created by Curtis Netterville on 8/29/25.
//

import SwiftUI

extension View {
    @MainActor
    func snapshot() -> NSImage? {
        let renderer = ImageRenderer(content: self)
        
        // Set the scale to match the main screen for a crisp image on Retina displays.
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
        
        // The .nsImage property provides a ready-to-use NSImage.
        return renderer.nsImage
    }
}