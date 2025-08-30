//
//  LegendaryCategory.swift
//  HIt Rewind2
//
//  Created by AI on 8/27/25.
//

import Foundation

struct LegendaryCategory: Identifiable, Equatable {
    let id: String
    let name: String
    var shows: [LegendaryShow]
    
    init(id: String = UUID().uuidString, name: String, shows: [LegendaryShow]) {
        self.id = id
        self.name = name
        self.shows = shows
    }

    static func == (lhs: LegendaryCategory, rhs: LegendaryCategory) -> Bool {
        // Categories are considered equal by stable name
        return lhs.name == rhs.name
    }
}


