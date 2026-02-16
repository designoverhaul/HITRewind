#!/usr/bin/env swift

import Foundation

let YOUTUBE_API_KEY = "AIzaSyChKL0fUHEfc1AlKe0ks53Y2wT78gxLiJE"

struct YouTubeSearchResponse: Codable {
    let items: [YouTubeSearchItem]
}

struct YouTubeSearchItem: Codable {
    let id: YouTubeVideoId
}

struct YouTubeVideoId: Codable {
    let videoId: String
}

let remainingSongs = [
    (61, "Gotta Get thru This", "Daniel Bedingfield"),
    (62, "Pass the Courvoisier, Part II", "Busta Rhymes featuring P. Diddy and Pharrell"),
    (63, "Lose Yourself", "Eminem"),
    (64, "Butterflies", "Michael Jackson"),
    (65, "What About Us?", "Brandy"),
    (66, "Underneath Your Clothes", "Shakira"),
    (67, "Rainy Dayz", "Mary J. Blige featuring Ja Rule"),
    (68, "Differences", "Ginuwine"),
    (69, "If I Could Go!", "Angie Martinez featuring Lil' Mo and Sacario"),
    (70, "The Whole World", "Outkast featuring Killer Mike"),
    (71, "Underneath It All", "No Doubt featuring Lady Saw"),
    (72, "Caramel", "City High featuring Eve"),
    (73, "Luv U Better", "LL Cool J"),
    (74, "Gimme the Light", "Sean Paul"),
    (75, "Gone", "NSYNC")
]

func searchYouTube(query: String) async throws -> String? {
    let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
    let urlString = "https://www.googleapis.com/youtube/v3/search?part=snippet&type=video&q=\(encodedQuery)&maxResults=1&key=\(YOUTUBE_API_KEY)"

    guard let url = URL(string: urlString) else { return nil }

    let (data, _) = try await URLSession.shared.data(from: url)
    let searchResponse = try JSONDecoder().decode(YouTubeSearchResponse.self, from: data)

    return searchResponse.items.first?.id.videoId
}

Task {
    print("Finding remaining 15 video IDs...\n")

    for (rank, title, artist) in remainingSongs {
        let query = "\(title) \(artist) official video"

        do {
            if let videoId = try await searchYouTube(query: query) {
                print("  {\"rank\": \(rank), \"title\": \"\(title)\", \"artist\": \"\(artist)\", \"videoId\": \"\(videoId)\"},")
            }
            try await Task.sleep(nanoseconds: 500_000_000)
        } catch {
            print("  // Error for rank \(rank): \(title)")
        }
    }

    print("\nDone!")
    exit(0)
}

RunLoop.main.run()
