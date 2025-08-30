//
//  FontLoader.swift
//  HIt Rewind2
//
//  Created by Assistant on 8/25/25.
//

import Foundation
import CoreText

enum FontLoader {
    /// Registers bundled custom fonts whose filenames contain provided keywords (case-insensitive).
    static func registerFonts(containing keywords: [String]) {
        let lowercaseKeywords = keywords.map { $0.lowercased() }
        let ttfs = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        let otfs = Bundle.main.urls(forResourcesWithExtension: "otf", subdirectory: nil) ?? []
        let all = (ttfs + otfs).filter { url in
            let name = url.lastPathComponent.lowercased()
            return lowercaseKeywords.contains(where: { name.contains($0) })
        }

        for url in all {
            var error: Unmanaged<CFError>?
            let success = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            if !success, let error = error?.takeRetainedValue() {
                let message = CFErrorCopyDescription(error) as String
                print("⚠️ Failed to register font at \(url.lastPathComponent): \(message)")
            } else {
                print("✅ Registered font: \(url.lastPathComponent)")
            }
        }
    }
}



