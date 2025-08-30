//
//  Array+SafeAccess.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/26/25.
//

import Foundation

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}