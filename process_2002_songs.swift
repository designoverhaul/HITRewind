#!/usr/bin/env swift

import Foundation

// MARK: - Configuration
let YOUTUBE_API_KEY = "AIzaSyChKL0fUHEfc1AlKe0ks53Y2wT78gxLiJE"
let AIRTABLE_API_KEY = "pat9HXwt4uUaLl3SC.3a38959399a2a1d101c726e5e3ce154b37661244db837be7698a27cd18fd764b"
let BASE_ID = "appxCBIOkiJEZiph7"
let TABLE_ID = "tblNwqwVyflL8hNDy"

// MARK: - Models
struct Song {
    let rank: Int
    let title: String
    let artist: String

    var searchQuery: String {
        return "\(title) \(artist) official video"
    }

    var artistName: String {
        // Extract main artist before "featuring"
        let patterns = [" featuring ", " feat. ", " feat ", " ft. ", " ft ", " with "]
        var cleanArtist = artist

        for pattern in patterns {
            if let range = artist.range(of: pattern, options: .caseInsensitive) {
                cleanArtist = String(artist[..<range.lowerBound])
                break
            }
        }

        return cleanArtist.trimmingCharacters(in: .whitespaces)
    }
}

struct YouTubeSearchResponse: Codable {
    let items: [YouTubeSearchItem]
}

struct YouTubeSearchItem: Codable {
    let id: YouTubeVideoId
}

struct YouTubeVideoId: Codable {
    let videoId: String
}

struct AirtableRecord: Codable {
    let fields: AirtableFields
}

struct AirtableFields: Codable {
    let title: String
    let url: String
    let Rank: Int
    let artistName: String
    let Year: String
    let artistID: String
}

// MARK: - Songs Data
let songs2002: [Song] = [
    Song(rank: 1, title: "How You Remind Me", artist: "Nickelback"),
    Song(rank: 2, title: "Foolish", artist: "Ashanti"),
    Song(rank: 3, title: "Hot in Herre", artist: "Nelly"),
    Song(rank: 4, title: "Dilemma", artist: "Nelly featuring Kelly Rowland"),
    Song(rank: 5, title: "Wherever You Will Go", artist: "The Calling"),
    Song(rank: 6, title: "A Thousand Miles", artist: "Vanessa Carlton"),
    Song(rank: 7, title: "In the End", artist: "Linkin Park"),
    Song(rank: 8, title: "What's Luv?", artist: "Fat Joe featuring Ashanti"),
    Song(rank: 9, title: "U Got It Bad", artist: "Usher"),
    Song(rank: 10, title: "Blurry", artist: "Puddle of Mudd"),
    Song(rank: 11, title: "Complicated", artist: "Avril Lavigne"),
    Song(rank: 12, title: "Always on Time", artist: "Ja Rule featuring Ashanti"),
    Song(rank: 13, title: "Ain't It Funny (Murder Remix)", artist: "Jennifer Lopez featuring Ja Rule"),
    Song(rank: 14, title: "The Middle", artist: "Jimmy Eat World"),
    Song(rank: 15, title: "I Need a Girl (Part One)", artist: "P. Diddy featuring Usher and Loon"),
    Song(rank: 16, title: "U Don't Have to Call", artist: "Usher"),
    Song(rank: 17, title: "Family Affair", artist: "Mary J. Blige"),
    Song(rank: 18, title: "I Need a Girl (Part Two)", artist: "P. Diddy featuring Ginuwine, Loon and Mario Winans"),
    Song(rank: 19, title: "Gangsta Lovin'", artist: "Eve featuring Alicia Keys"),
    Song(rank: 20, title: "My Sacrifice", artist: "Creed"),
    Song(rank: 21, title: "Without Me", artist: "Eminem"),
    Song(rank: 22, title: "Hero", artist: "Enrique Iglesias"),
    Song(rank: 23, title: "All You Wanted", artist: "Michelle Branch"),
    Song(rank: 24, title: "Get the Party Started", artist: "Pink"),
    Song(rank: 25, title: "Hero", artist: "Chad Kroeger featuring Josey Scott"),
    Song(rank: 26, title: "Wasting My Time", artist: "Default"),
    Song(rank: 27, title: "One Last Breath", artist: "Creed"),
    Song(rank: 28, title: "Whenever, Wherever", artist: "Shakira"),
    Song(rank: 29, title: "I'm Gonna Be Alright", artist: "Jennifer Lopez featuring Nas"),
    Song(rank: 30, title: "Oh Boy", artist: "Cam'ron featuring Juelz Santana"),
    Song(rank: 31, title: "Heaven", artist: "DJ Sammy featuring Yanou and Do"),
    Song(rank: 32, title: "Hey Baby", artist: "No Doubt featuring Bounty Killer"),
    Song(rank: 33, title: "Girlfriend", artist: "NSYNC featuring Nelly"),
    Song(rank: 34, title: "Just a Friend 2002", artist: "Mario"),
    Song(rank: 35, title: "Soak Up the Sun", artist: "Sheryl Crow"),
    Song(rank: 36, title: "Don't Let Me Get Me", artist: "Pink"),
    Song(rank: 37, title: "Nothin'", artist: "N.O.R.E."),
    Song(rank: 38, title: "Oops (Oh My)", artist: "Tweet featuring Missy Elliott"),
    Song(rank: 39, title: "A Moment Like This", artist: "Kelly Clarkson"),
    Song(rank: 40, title: "Addictive", artist: "Truth Hurts featuring Rakim"),
    Song(rank: 41, title: "Happy", artist: "Ashanti"),
    Song(rank: 42, title: "No Such Thing", artist: "John Mayer"),
    Song(rank: 43, title: "Just Like a Pill", artist: "Pink"),
    Song(rank: 44, title: "Down 4 U", artist: "Ja Rule featuring Ashanti, Charli Baltimore and Vita"),
    Song(rank: 45, title: "Can't Get You Out of My Head", artist: "Kylie Minogue"),
    Song(rank: 46, title: "Superman (It's Not Easy)", artist: "Five for Fighting"),
    Song(rank: 47, title: "Cleanin' Out My Closet", artist: "Eminem"),
    Song(rank: 48, title: "Halfcrazy", artist: "Musiq Soulchild"),
    Song(rank: 49, title: "Lights, Camera, Action!", artist: "Mr. Cheeks"),
    Song(rank: 50, title: "Still Fly", artist: "Big Tymers"),
    Song(rank: 51, title: "A Woman's Worth", artist: "Alicia Keys"),
    Song(rank: 52, title: "7 Days", artist: "Craig David"),
    Song(rank: 53, title: "Hey Ma", artist: "Cam'ron featuring Juelz Santana and Freekey Zekey"),
    Song(rank: 54, title: "Work It", artist: "Missy Elliott"),
    Song(rank: 55, title: "Move Bitch", artist: "Ludacris featuring Mystikal and I-20"),
    Song(rank: 56, title: "Can't Fight the Moonlight", artist: "LeAnn Rimes"),
    Song(rank: 57, title: "Escape", artist: "Enrique Iglesias"),
    Song(rank: 58, title: "More Than A Woman", artist: "Aaliyah"),
    Song(rank: 59, title: "Hella Good", artist: "No Doubt"),
    Song(rank: 60, title: "I Love You", artist: "Faith Evans"),
    Song(rank: 61, title: "Gotta Get thru This", artist: "Daniel Bedingfield"),
    Song(rank: 62, title: "Pass the Courvoisier, Part II", artist: "Busta Rhymes featuring P. Diddy and Pharrell"),
    Song(rank: 63, title: "Lose Yourself", artist: "Eminem"),
    Song(rank: 64, title: "Butterflies", artist: "Michael Jackson"),
    Song(rank: 65, title: "What About Us?", artist: "Brandy"),
    Song(rank: 66, title: "Underneath Your Clothes", artist: "Shakira"),
    Song(rank: 67, title: "Rainy Dayz", artist: "Mary J. Blige featuring Ja Rule"),
    Song(rank: 68, title: "Differences", artist: "Ginuwine"),
    Song(rank: 69, title: "If I Could Go!", artist: "Angie Martinez featuring Lil' Mo and Sacario"),
    Song(rank: 70, title: "The Whole World", artist: "Outkast featuring Killer Mike"),
    Song(rank: 71, title: "Underneath It All", artist: "No Doubt featuring Lady Saw"),
    Song(rank: 72, title: "Caramel", artist: "City High featuring Eve"),
    Song(rank: 73, title: "Luv U Better", artist: "LL Cool J"),
    Song(rank: 74, title: "Gimme the Light", artist: "Sean Paul"),
    Song(rank: 75, title: "Gone", artist: "NSYNC")
]

// MARK: - API Functions
func searchYouTube(query: String) async throws -> String? {
    let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
    let urlString = "https://www.googleapis.com/youtube/v3/search?part=snippet&type=video&q=\(encodedQuery)&maxResults=1&key=\(YOUTUBE_API_KEY)"

    guard let url = URL(string: urlString) else {
        throw NSError(domain: "InvalidURL", code: -1)
    }

    let (data, response) = try await URLSession.shared.data(from: url)

    guard let httpResponse = response as? HTTPURLResponse else {
        throw NSError(domain: "InvalidResponse", code: -1)
    }

    if httpResponse.statusCode == 403 {
        throw NSError(domain: "QuotaExceeded", code: 403, userInfo: [NSLocalizedDescriptionKey: "YouTube API quota exceeded"])
    }

    guard httpResponse.statusCode == 200 else {
        throw NSError(domain: "HTTPError", code: httpResponse.statusCode)
    }

    let searchResponse = try JSONDecoder().decode(YouTubeSearchResponse.self, from: data)

    guard let firstResult = searchResponse.items.first else {
        return nil
    }

    return "https://www.youtube.com/watch?v=\(firstResult.id.videoId)"
}

func addToAirtable(song: Song, youtubeURL: String) async throws {
    let fields = AirtableFields(
        title: song.title,
        url: youtubeURL,
        Rank: song.rank,
        artistName: song.artistName,
        Year: "2002",
        artistID: ""
    )

    let record = AirtableRecord(fields: fields)
    let payload = ["records": [record]]

    let urlString = "https://api.airtable.com/v0/\(BASE_ID)/\(TABLE_ID)"
    guard let url = URL(string: urlString) else {
        throw NSError(domain: "InvalidURL", code: -1)
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(AIRTABLE_API_KEY)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(payload)

    let (_, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) else {
        throw NSError(domain: "AirtableError", code: -1)
    }
}

// MARK: - Processing Functions
struct ProcessingResult {
    var successful: [(song: Song, url: String)] = []
    var noVideoFound: [Song] = []
    var errors: [(song: Song, error: String)] = []
}

func processSongs(songs: [Song], batchSize: Int = 10, delayBetweenBatches: UInt64 = 2_000_000_000) async -> ProcessingResult {
    var result = ProcessingResult()

    print("🎵 Starting to process \(songs.count) songs from 2002")
    print("📦 Batch size: \(batchSize) songs")
    print("⏱️  Delay between batches: \(delayBetweenBatches / 1_000_000_000) seconds\n")

    let batches = songs.chunked(into: batchSize)

    for (batchIndex, batch) in batches.enumerated() {
        print("📦 Processing batch \(batchIndex + 1)/\(batches.count) (\(batch.count) songs)")

        for song in batch {
            print("  🔍 [\(song.rank)] \(song.title) - \(song.artistName)")

            do {
                // Search YouTube
                if let youtubeURL = try await searchYouTube(query: song.searchQuery) {
                    print("    ✅ Found: \(youtubeURL)")

                    // Add to Airtable
                    try await addToAirtable(song: song, youtubeURL: youtubeURL)
                    print("    💾 Added to Airtable")

                    result.successful.append((song: song, url: youtubeURL))

                    // Small delay between individual requests
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                } else {
                    print("    ⚠️  No video found")
                    result.noVideoFound.append(song)
                }
            } catch let error as NSError where error.code == 403 {
                print("    ❌ YouTube API quota exceeded - stopping")
                result.errors.append((song: song, error: "Quota exceeded"))
                return result // Stop processing immediately
            } catch {
                print("    ❌ Error: \(error.localizedDescription)")
                result.errors.append((song: song, error: error.localizedDescription))
            }
        }

        // Delay between batches (except after the last batch)
        if batchIndex < batches.count - 1 {
            print("  ⏸️  Waiting \(delayBetweenBatches / 1_000_000_000) seconds before next batch...\n")
            try? await Task.sleep(nanoseconds: delayBetweenBatches)
        }
    }

    return result
}

// MARK: - Array Extension
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Summary Report
func printSummary(result: ProcessingResult) {
    print("\n" + String(repeating: "=", count: 60))
    print("📊 PROCESSING SUMMARY")
    print(String(repeating: "=", count: 60))

    print("\n✅ Successfully Added: \(result.successful.count)")
    for (song, _) in result.successful {
        print("  [\(song.rank)] \(song.title) - \(song.artistName)")
    }

    if !result.noVideoFound.isEmpty {
        print("\n⚠️  No Video Found: \(result.noVideoFound.count)")
        for song in result.noVideoFound {
            print("  [\(song.rank)] \(song.title) - \(song.artistName)")
        }
    }

    if !result.errors.isEmpty {
        print("\n❌ Errors: \(result.errors.count)")
        for (song, error) in result.errors {
            print("  [\(song.rank)] \(song.title) - \(song.artistName)")
            print("    Error: \(error)")
        }
    }

    print("\n" + String(repeating: "=", count: 60))
    print("Total processed: \(result.successful.count + result.noVideoFound.count + result.errors.count)/75")
    print(String(repeating: "=", count: 60) + "\n")
}

// MARK: - Main Execution
Task {
    let result = await processSongs(songs: songs2002, batchSize: 10, delayBetweenBatches: 2_000_000_000)
    printSummary(result: result)
    exit(0)
}

// Keep the program running
RunLoop.main.run()
