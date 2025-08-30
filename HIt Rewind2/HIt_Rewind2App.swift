//
//  HIt_Rewind2App.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/24/25.
//

import SwiftUI

@main
struct HIt_Rewind2App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .onAppear {
                    // Attempt to register the Ticketing font if bundled
                    FontLoader.registerFonts(containing: ["ticketing"]) // matches filenames like Ticketing-Regular.ttf
                }
        }
    }
}
