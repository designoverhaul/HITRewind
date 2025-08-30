//
//  AppFont.swift
//  HIt Rewind2
//
//  Created by Assistant on 8/25/25.
//

import UIKit

enum AppFont {
    /// Returns the best matching Ticketing font PostScript name if available, otherwise a sensible default family name.
    static func ticketingName() -> String {
        // Prefer any registered font with family or name containing "ticketing"
        let families = UIFont.familyNames
        for family in families {
            if family.lowercased().contains("ticketing") {
                let names = UIFont.fontNames(forFamilyName: family)
                if let match = names.first { return match }
                return family
            }
        }
        // Fallback: scan all font names for a match
        for family in families {
            let names = UIFont.fontNames(forFamilyName: family)
            if let match = names.first(where: { $0.lowercased().contains("ticketing") }) {
                return match
            }
        }
        // Final fallback: the common family name we expect
        return "Ticketing"
    }
}



