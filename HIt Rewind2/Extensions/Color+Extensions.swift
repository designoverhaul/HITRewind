//
//  Color+Extensions.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/24/25.
//

import SwiftUI

extension Color {
    // Hit Rewind purple color from Apple TV app (#A789FD)
    static let hitRewindPurple = Color(red: 167/255, green: 137/255, blue: 253/255)
    
    // Dark gray color from Apple TV app (#292631)
    static let hitRewindDarkGray = Color(red: 41/255, green: 38/255, blue: 49/255)
    
    // Background colors for dark theme
    static let hitRewindBackground = Color.black
    static let hitRewindSecondaryBackground = Color(red: 28/255, green: 28/255, blue: 30/255)
    static let hitRewindCardBackground = Color(red: 44/255, green: 44/255, blue: 46/255)
    
    // Text colors
    static let hitRewindPrimaryText = Color.white
    static let hitRewindSecondaryText = Color.gray
}

extension Color {
    // Initializer for hex colors
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}