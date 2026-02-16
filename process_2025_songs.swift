#!/usr/bin/env swift

import Foundation

// MARK: - Models
struct Song {
    let rank: Int
    let title: String
    let artist: String
}

struct YouTubeSearchResponse: Codable {
    let items: [YouTubeSearchItem]
}

struct YouTubeSearchItem: Codable {
    let id: YouTubeSearchId
    let snippet: YouTubeSearchSnippet
}

struct YouTubeSearchId: Codable {
    let videoId: String
}

struct YouTubeSearchSnippet: Codable {
    let title: String
    let channelTitle: String
}

struct AirtableRecord: Codable {
    let fields: AirtableFields
}

struct AirtableFields: Codable {
    let title: String
    let url: String
    let Rank: Double
    let artistName: String
    let Year: String

    enum CodingKeys: String, CodingKey {
        case title, url, Rank, artistName, Year
    }
}

// MARK: - Configuration
// NOTE: Replace with your actual API keys from Constants.swift
let youtubeAPIKey = "YOUR_YOUTUBE_API_KEY"
let airtableAPIKey = "YOUR_AIRTABLE_API_KEY"
let airtableBaseId = "appxCBIOkiJEZiph7"
let airtableTableId = "tblNwqwVyflL8hNDy"

// MARK: - Songs Data
let songs = [
    Song(rank: 1, title: "Die with a Smile", artist: "Lady Gaga and Bruno Mars"),
    Song(rank: 2, title: "Luther", artist: "Kendrick Lamar and SZA"),
    Song(rank: 3, title: "A Bar Song (Tipsy)", artist: "Shaboozey"),
    Song(rank: 4, title: "Lose Control", artist: "Teddy Swims"),
    Song(rank: 5, title: "Birds of a Feather", artist: "Billie Eilish"),
    Song(rank: 6, title: "Beautiful Things", artist: "Benson Boone"),
    Song(rank: 7, title: "Ordinary", artist: "Alex Warren"),
    Song(rank: 8, title: "I Had Some Help", artist: "Post Malone featuring Morgan Wallen"),
    Song(rank: 9, title: "APT.", artist: "Rosé and Bruno Mars"),
    Song(rank: 10, title: "Pink Pony Club", artist: "Chappell Roan"),
    Song(rank: 11, title: "Love Somebody", artist: "Morgan Wallen"),
    Song(rank: 12, title: "Espresso", artist: "Sabrina Carpenter"),
    Song(rank: 13, title: "I'm the Problem", artist: "Morgan Wallen"),
    Song(rank: 14, title: "That's So True", artist: "Gracie Abrams"),
    Song(rank: 15, title: "TV Off", artist: "Kendrick Lamar featuring Lefty Gunplay"),
    Song(rank: 16, title: "Timeless", artist: "The Weeknd and Playboi Carti"),
    Song(rank: 17, title: "Not Like Us", artist: "Kendrick Lamar"),
    Song(rank: 18, title: "Just in Case", artist: "Morgan Wallen"),
    Song(rank: 19, title: "Taste", artist: "Sabrina Carpenter"),
    Song(rank: 20, title: "Squabble Up", artist: "Kendrick Lamar"),
    Song(rank: 21, title: "30 for 30", artist: "SZA and Kendrick Lamar"),
    Song(rank: 22, title: "Mutt", artist: "Leon Thomas"),
    Song(rank: 23, title: "Good News", artist: "Shaboozey"),
    Song(rank: 24, title: "Nokia", artist: "Drake"),
    Song(rank: 25, title: "Golden", artist: "Huntrix: Ejae, Audrey Nuna and Rei Ami"),
    Song(rank: 26, title: "Wildflower", artist: "Billie Eilish"),
    Song(rank: 27, title: "What I Want", artist: "Morgan Wallen featuring Tate McRae"),
    Song(rank: 28, title: "Messy", artist: "Lola Young"),
    Song(rank: 29, title: "Stargazing", artist: "Myles Smith"),
    Song(rank: 30, title: "Love Me Not", artist: "Ravn Lenae"),
    Song(rank: 31, title: "Good Luck, Babe!", artist: "Chappell Roan"),
    Song(rank: 32, title: "No One Noticed", artist: "The Marías"),
    Song(rank: 33, title: "All the Way", artist: "BigXthaPlug featuring Bailey Zimmerman"),
    Song(rank: 34, title: "Too Sweet", artist: "Hozier"),
    Song(rank: 35, title: "Worst Way", artist: "Riley Green"),
    Song(rank: 36, title: "Sailor Song", artist: "Gigi Perez"),
    Song(rank: 37, title: "Sorry I'm Here for Someone Else", artist: "Benson Boone"),
    Song(rank: 38, title: "Manchild", artist: "Sabrina Carpenter"),
    Song(rank: 39, title: "Anxiety", artist: "Doechii"),
    Song(rank: 40, title: "I Got Better", artist: "Morgan Wallen"),
    Song(rank: 41, title: "Sticky", artist: "Tyler, the Creator featuring GloRilla, Sexyy Red and Lil Wayne"),
    Song(rank: 42, title: "Undressed", artist: "Sombr"),
    Song(rank: 43, title: "I Never Lie", artist: "Zach Top"),
    Song(rank: 44, title: "Back to Friends", artist: "Sombr"),
    Song(rank: 45, title: "Bed Chem", artist: "Sabrina Carpenter"),
    Song(rank: 46, title: "Sports Car", artist: "Tate McRae"),
    Song(rank: 47, title: "Mystical Magical", artist: "Benson Boone"),
    Song(rank: 48, title: "Whatchu Kno About Me", artist: "GloRilla and Sexyy Red"),
    Song(rank: 49, title: "Indigo", artist: "Sam Barber featuring Avery Anna"),
    Song(rank: 50, title: "Please Please Please", artist: "Sabrina Carpenter"),
    Song(rank: 51, title: "DTMF", artist: "Bad Bunny"),
    Song(rank: 52, title: "Blue Strips", artist: "Jessie Murph"),
    Song(rank: 53, title: "Peekaboo", artist: "Kendrick Lamar featuring AzChike"),
    Song(rank: 54, title: "Your Idol", artist: "Saja Boys: Andrew Choi, Neckwav, Danny Chung, Kevin Woo and Samuil Lee"),
    Song(rank: 55, title: "High Road", artist: "Koe Wetzel featuring Jessie Murph"),
    Song(rank: 56, title: "Abracadabra", artist: "Lady Gaga"),
    Song(rank: 57, title: "Who", artist: "Jimin"),
    Song(rank: 58, title: "Burning Blue", artist: "Mariah the Scientist"),
    Song(rank: 59, title: "All I Want for Christmas Is You", artist: "Mariah Carey"),
    Song(rank: 60, title: "Daisies", artist: "Justin Bieber"),
    Song(rank: 61, title: "Soda Pop", artist: "Saja Boys: Andrew Choi, Neckwav, Danny Chung, Kevin Woo and Samuil Lee"),
    Song(rank: 62, title: "Like Him", artist: "Tyler, the Creator featuring Lola Young"),
    Song(rank: 63, title: "Residuals", artist: "Chris Brown"),
    Song(rank: 64, title: "Smile", artist: "Morgan Wallen"),
    Song(rank: 65, title: "Last Christmas", artist: "Wham!"),
    Song(rank: 66, title: "Am I Okay?", artist: "Megan Moroney"),
    Song(rank: 67, title: "Rockin' Around the Christmas Tree", artist: "Brenda Lee"),
    Song(rank: 68, title: "How It's Done", artist: "Huntrix: Ejae, Audrey Nuna and Rei Ami"),
    Song(rank: 69, title: "Happen to Me", artist: "Russell Dickerson"),
    Song(rank: 70, title: "Baile Inolvidable", artist: "Bad Bunny"),
    Song(rank: 71, title: "Weren't for the Wind", artist: "Ella Langley"),
    Song(rank: 72, title: "I Ain't Comin' Back", artist: "Morgan Wallen featuring Post Malone"),
    Song(rank: 73, title: "Cry for Me", artist: "The Weeknd"),
    Song(rank: 74, title: "Bad Dreams", artist: "Teddy Swims"),
    Song(rank: 75, title: "Denial Is a River", artist: "Doechii")
]

// MARK: - Helper Functions
func extractMainArtist(from artist: String) -> String {
    // Remove everything after "featuring", "feat.", "ft.", "and"
    let patterns = [" featuring ", " feat\\.", " ft\\.", " and ", ": "]
    var mainArtist = artist

    for pattern in patterns {
        if let range = mainArtist.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
            mainArtist = String(mainArtist[..<range.lowerBound])
            break
        }
    }

    return mainArtist.trimmingCharacters(in: .whitespaces)
}

func searchYouTubeVideo(title: String, artist: String) async throws -> String? {
    let query = "\(title) \(artist) official video".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    let urlString = "https://www.googleapis.com/youtube/v3/search?part=snippet&type=video&q=\(query)&maxResults=1&key=\(youtubeAPIKey)"

    guard let url = URL(string: urlString) else {
        throw NSError(domain: "Invalid URL", code: -1)
    }

    let (data, response) = try await URLSession.shared.data(from: url)

    guard let httpResponse = response as? HTTPURLResponse else {
        throw NSError(domain: "Invalid response", code: -1)
    }

    if httpResponse.statusCode == 403 {
        throw NSError(domain: "YouTube API quota exceeded", code: 403)
    }

    guard httpResponse.statusCode == 200 else {
        throw NSError(domain: "HTTP error \(httpResponse.statusCode)", code: httpResponse.statusCode)
    }

    let searchResponse = try JSONDecoder().decode(YouTubeSearchResponse.self, from: data)

    guard let firstResult = searchResponse.items.first else {
        return nil
    }

    return "https://www.youtube.com/watch?v=\(firstResult.id.videoId)"
}

func addToAirtable(record: AirtableFields) async throws {
    let urlString = "https://api.airtable.com/v0/\(airtableBaseId)/\(airtableTableId)"

    guard let url = URL(string: urlString) else {
        throw NSError(domain: "Invalid URL", code: -1)
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(airtableAPIKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let airtableRecord = AirtableRecord(fields: record)
    let jsonData = try JSONEncoder().encode(airtableRecord)
    request.httpBody = jsonData

    let (_, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
        throw NSError(domain: "Invalid response", code: -1)
    }

    guard httpResponse.statusCode == 200 else {
        throw NSError(domain: "HTTP error \(httpResponse.statusCode)", code: httpResponse.statusCode)
    }
}

// MARK: - Main Processing
struct ProcessingResult {
    var successCount = 0
    var failedVideos: [(rank: Int, title: String, artist: String, reason: String)] = []
    var addedSongs: [(rank: Int, title: String, artist: String, url: String)] = []
}

func processSongs() async -> ProcessingResult {
    var result = ProcessingResult()

    print("Starting to process \(songs.count) songs from 2025...")
    print("Processing in batches to avoid API quota limits...\n")

    for (index, song) in songs.enumerated() {
        let progress = index + 1
        print("[\(progress)/\(songs.count)] Processing: \(song.title) by \(song.artist)")

        do {
            // Search for YouTube video
            guard let youtubeURL = try await searchYouTubeVideo(title: song.title, artist: song.artist) else {
                let reason = "No YouTube video found"
                print("  ❌ \(reason)")
                result.failedVideos.append((song.rank, song.title, song.artist, reason))
                continue
            }

            print("  ✅ Found video: \(youtubeURL)")

            // Extract main artist name
            let mainArtist = extractMainArtist(from: song.artist)

            // Create Airtable record
            let airtableFields = AirtableFields(
                title: song.title,
                url: youtubeURL,
                Rank: Double(song.rank),
                artistName: mainArtist,
                Year: "2025"
            )

            // Add to Airtable
            try await addToAirtable(record: airtableFields)
            print("  ✅ Added to Airtable")

            result.successCount += 1
            result.addedSongs.append((song.rank, song.title, song.artist, youtubeURL))

            // Small delay to avoid rate limiting
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        } catch let error as NSError {
            let reason = error.domain
            print("  ❌ Error: \(reason)")
            result.failedVideos.append((song.rank, song.title, song.artist, reason))

            // If quota exceeded, stop processing
            if error.code == 403 {
                print("\n⚠️ YouTube API quota exceeded. Stopping processing.")
                break
            }
        } catch {
            let reason = error.localizedDescription
            print("  ❌ Error: \(reason)")
            result.failedVideos.append((song.rank, song.title, song.artist, reason))
        }

        print("")
    }

    return result
}

// MARK: - Run Script
Task {
    let result = await processSongs()

    print("\n" + String(repeating: "=", count: 60))
    print("PROCESSING COMPLETE")
    print(String(repeating: "=", count: 60))
    print("\nSummary:")
    print("  ✅ Successfully added: \(result.successCount) songs")
    print("  ❌ Failed: \(result.failedVideos.count) songs")

    if !result.failedVideos.isEmpty {
        print("\nFailed songs:")
        for failed in result.failedVideos {
            print("  \(failed.rank). \(failed.title) by \(failed.artist)")
            print("     Reason: \(failed.reason)")
        }
    }

    if !result.addedSongs.isEmpty {
        print("\nSuccessfully added songs:")
        for added in result.addedSongs.prefix(10) {
            print("  \(added.rank). \(added.title) by \(added.artist)")
        }
        if result.addedSongs.count > 10 {
            print("  ... and \(result.addedSongs.count - 10) more")
        }
    }

    print("\n" + String(repeating: "=", count: 60))

    exit(0)
}

// Keep the script running
RunLoop.main.run()
