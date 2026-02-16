#!/usr/bin/env swift

import Foundation

// MARK: - Configuration
let YOUTUBE_API_KEY = "AIzaSyChKL0fUHEfc1AlKe0ks53Y2wT78gxLiJE"
let AIRTABLE_API_KEY = "pat9HXwt4uUaLl3SC.3a38959399a2a1d101c726e5e3ce154b37661244db837be7698a27cd18fd764b"
let AIRTABLE_BASE_ID = "appxCBIOkiJEZiph7"
let AIRTABLE_TABLE_ID = "tblNwqwVyflL8hNDy"

// MARK: - Models
struct YouTubeSearchResponse: Codable {
    let items: [YouTubeSearchItem]?
}

struct YouTubeSearchItem: Codable {
    let id: YouTubeVideoId
}

struct YouTubeVideoId: Codable {
    let videoId: String
}

struct AirtableCreateRequest: Codable {
    let records: [AirtableRecord]
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
}

struct Song {
    let rank: Int
    let title: String
    let artist: String
}

// MARK: - Song Data
let songs: [Song] = [
    Song(rank: 1, title: "Lose Control", artist: "Teddy Swims"),
    Song(rank: 2, title: "A Bar Song (Tipsy)", artist: "Shaboozey"),
    Song(rank: 3, title: "Beautiful Things", artist: "Benson Boone"),
    Song(rank: 4, title: "I Had Some Help", artist: "Post Malone featuring Morgan Wallen"),
    Song(rank: 5, title: "Lovin on Me", artist: "Jack Harlow"),
    Song(rank: 6, title: "Not Like Us", artist: "Kendrick Lamar"),
    Song(rank: 7, title: "Espresso", artist: "Sabrina Carpenter"),
    Song(rank: 8, title: "Million Dollar Baby", artist: "Tommy Richman"),
    Song(rank: 9, title: "I Remember Everything", artist: "Zach Bryan featuring Kacey Musgraves"),
    Song(rank: 10, title: "Too Sweet", artist: "Hozier"),
    Song(rank: 11, title: "Stick Season", artist: "Noah Kahan"),
    Song(rank: 12, title: "Cruel Summer", artist: "Taylor Swift"),
    Song(rank: 13, title: "Greedy", artist: "Tate McRae"),
    Song(rank: 14, title: "Like That", artist: "Future, Metro Boomin and Kendrick Lamar"),
    Song(rank: 15, title: "Birds of a Feather", artist: "Billie Eilish"),
    Song(rank: 16, title: "Please Please Please", artist: "Sabrina Carpenter"),
    Song(rank: 17, title: "Agora Hills", artist: "Doja Cat"),
    Song(rank: 18, title: "Good Luck, Babe!", artist: "Chappell Roan"),
    Song(rank: 19, title: "Saturn", artist: "SZA"),
    Song(rank: 20, title: "Snooze", artist: "SZA"),
    Song(rank: 21, title: "Paint the Town Red", artist: "Doja Cat"),
    Song(rank: 22, title: "Fortnight", artist: "Taylor Swift featuring Post Malone"),
    Song(rank: 23, title: "Fast Car", artist: "Luke Combs"),
    Song(rank: 24, title: "Water", artist: "Tyla"),
    Song(rank: 25, title: "Feather", artist: "Sabrina Carpenter"),
    Song(rank: 26, title: "We Can't Be Friends (Wait for Your Love)", artist: "Ariana Grande"),
    Song(rank: 27, title: "Austin", artist: "Dasha"),
    Song(rank: 28, title: "Last Night", artist: "Morgan Wallen"),
    Song(rank: 29, title: "Cowgirls", artist: "Morgan Wallen featuring Ernest"),
    Song(rank: 30, title: "Pink Skies", artist: "Zach Bryan"),
    Song(rank: 31, title: "Thinkin' Bout Me", artist: "Morgan Wallen"),
    Song(rank: 32, title: "Texas Hold 'Em", artist: "Beyoncé"),
    Song(rank: 33, title: "Is It Over Now?", artist: "Taylor Swift"),
    Song(rank: 34, title: "Miles on It", artist: "Marshmello and Kane Brown"),
    Song(rank: 35, title: "I Can Do It with a Broken Heart", artist: "Taylor Swift"),
    Song(rank: 36, title: "Wild Ones", artist: "Jessie Murph and Jelly Roll"),
    Song(rank: 37, title: "Ain't No Love in Oklahoma", artist: "Luke Combs"),
    Song(rank: 38, title: "Carnival", artist: "¥$ (Kanye West and Ty Dolla Sign) featuring Rich the Kid and Playboi Carti"),
    Song(rank: 39, title: "Houdini", artist: "Eminem"),
    Song(rank: 40, title: "Wanna Be", artist: "GloRilla and Megan Thee Stallion"),
    Song(rank: 41, title: "Slow It Down", artist: "Benson Boone"),
    Song(rank: 42, title: "Redrum", artist: "21 Savage"),
    Song(rank: 43, title: "Houdini", artist: "Dua Lipa"),
    Song(rank: 44, title: "Yeah Glo!", artist: "GloRilla"),
    Song(rank: 45, title: "Rich Baby Daddy", artist: "Drake featuring Sexyy Red and SZA"),
    Song(rank: 46, title: "What Was I Made For?", artist: "Billie Eilish"),
    Song(rank: 47, title: "End of Beginning", artist: "Djo"),
    Song(rank: 48, title: "Lunch", artist: "Billie Eilish"),
    Song(rank: 49, title: "Never Lose Me", artist: "Flo Milli"),
    Song(rank: 50, title: "Lies Lies Lies", artist: "Morgan Wallen"),
    Song(rank: 51, title: "Type Shit", artist: "Future, Metro Boomin, Travis Scott, and Playboi Carti"),
    Song(rank: 52, title: "Gata Only", artist: "FloyyMenor and Cris MJ"),
    Song(rank: 53, title: "Hot to Go!", artist: "Chappell Roan"),
    Song(rank: 54, title: "All I Want for Christmas Is You", artist: "Mariah Carey"),
    Song(rank: 55, title: "Get It Sexyy", artist: "Sexyy Red"),
    Song(rank: 56, title: "Made for Me", artist: "Muni Long"),
    Song(rank: 57, title: "Vampire", artist: "Olivia Rodrigo"),
    Song(rank: 58, title: "Whatever She Wants", artist: "Bryson Tiller"),
    Song(rank: 59, title: "Rockin' Around the Christmas Tree", artist: "Brenda Lee"),
    Song(rank: 60, title: "Pretty Little Poison", artist: "Warren Zeiders"),
    Song(rank: 61, title: "First Person Shooter", artist: "Drake featuring J. Cole"),
    Song(rank: 62, title: "Die with a Smile", artist: "Lady Gaga and Bruno Mars"),
    Song(rank: 63, title: "I Like the Way You Kiss Me", artist: "Artemas"),
    Song(rank: 64, title: "Need a Favor", artist: "Jelly Roll"),
    Song(rank: 65, title: "Save Me", artist: "Jelly Roll featuring Lainey Wilson"),
    Song(rank: 66, title: "Euphoria", artist: "Kendrick Lamar"),
    Song(rank: 67, title: "Truck Bed", artist: "Hardy"),
    Song(rank: 68, title: "Jingle Bell Rock", artist: "Bobby Helms"),
    Song(rank: 69, title: "Flowers", artist: "Miley Cyrus"),
    Song(rank: 70, title: "Where the Wild Things Are", artist: "Luke Combs"),
    Song(rank: 71, title: "Everybody", artist: "Nicki Minaj featuring Lil Uzi Vert"),
    Song(rank: 72, title: "La Diabla", artist: "Xavi"),
    Song(rank: 73, title: "Stargazing", artist: "Myles Smith"),
    Song(rank: 74, title: "Last Christmas", artist: "Wham!"),
    Song(rank: 75, title: "I Am Not Okay", artist: "Jelly Roll")
]

// MARK: - Helper Functions
func extractMainArtist(from artist: String) -> String {
    // Remove everything after "featuring", "and", "with", etc.
    let patterns = [" featuring ", " feat. ", " feat ", " ft. ", " ft ", " and ", " with ", " & "]
    var cleanArtist = artist

    for pattern in patterns {
        if let range = cleanArtist.range(of: pattern, options: .caseInsensitive) {
            cleanArtist = String(cleanArtist[..<range.lowerBound])
            break
        }
    }

    return cleanArtist.trimmingCharacters(in: .whitespaces)
}

func searchYouTubeVideo(title: String, artist: String) async throws -> String? {
    let query = "\(title) \(artist) official video".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    let urlString = "https://www.googleapis.com/youtube/v3/search?part=snippet&type=video&q=\(query)&maxResults=1&key=\(YOUTUBE_API_KEY)"

    guard let url = URL(string: urlString) else {
        throw NSError(domain: "InvalidURL", code: -1)
    }

    let (data, response) = try await URLSession.shared.data(from: url)

    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
        throw NSError(domain: "HTTPError", code: (response as? HTTPURLResponse)?.statusCode ?? -1)
    }

    let searchResponse = try JSONDecoder().decode(YouTubeSearchResponse.self, from: data)

    if let videoId = searchResponse.items?.first?.id.videoId {
        return "https://www.youtube.com/watch?v=\(videoId)"
    }

    return nil
}

func addToAirtable(records: [AirtableRecord]) async throws {
    let urlString = "https://api.airtable.com/v0/\(AIRTABLE_BASE_ID)/\(AIRTABLE_TABLE_ID)"
    guard let url = URL(string: urlString) else {
        throw NSError(domain: "InvalidURL", code: -1)
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("Bearer \(AIRTABLE_API_KEY)", forHTTPHeaderField: "Authorization")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    let createRequest = AirtableCreateRequest(records: records)
    request.httpBody = try JSONEncoder().encode(createRequest)

    let (_, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
        throw NSError(domain: "AirtableError", code: (response as? HTTPURLResponse)?.statusCode ?? -1)
    }
}

// MARK: - Main Processing
func processSongs() async {
    print("🎵 Starting to process 75 songs from 2024...")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    var successCount = 0
    var failureCount = 0
    var notFoundCount = 0
    var recordsToAdd: [AirtableRecord] = []
    var failedSongs: [(Song, String)] = []

    for (index, song) in songs.enumerated() {
        let progress = "\(index + 1)/\(songs.count)"
        print("\n[\(progress)] Processing: \(song.title) - \(song.artist)")

        do {
            // Search for YouTube video
            if let youtubeUrl = try await searchYouTubeVideo(title: song.title, artist: song.artist) {
                print("  ✅ Found video: \(youtubeUrl)")

                // Extract main artist name
                let mainArtist = extractMainArtist(from: song.artist)

                // Create record
                let fields = AirtableFields(
                    title: song.title,
                    url: youtubeUrl,
                    Rank: song.rank,
                    artistName: mainArtist,
                    Year: "2024"
                )

                let record = AirtableRecord(fields: fields)
                recordsToAdd.append(record)

                print("  📝 Prepared record for Airtable (Artist: \(mainArtist))")
                successCount += 1

                // Add to Airtable in batches of 10
                if recordsToAdd.count == 10 {
                    print("\n  💾 Uploading batch of 10 records to Airtable...")
                    try await addToAirtable(records: recordsToAdd)
                    print("  ✅ Batch uploaded successfully!")
                    recordsToAdd.removeAll()

                    // Rate limiting - wait 1 second between batches
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                }
            } else {
                print("  ⚠️  No video found")
                notFoundCount += 1
                failedSongs.append((song, "No video found"))
            }

            // Rate limiting - wait 200ms between requests
            try await Task.sleep(nanoseconds: 200_000_000)

        } catch {
            print("  ❌ Error: \(error.localizedDescription)")
            failureCount += 1
            failedSongs.append((song, error.localizedDescription))
        }
    }

    // Upload remaining records
    if !recordsToAdd.isEmpty {
        print("\n💾 Uploading final batch of \(recordsToAdd.count) records to Airtable...")
        do {
            try await addToAirtable(records: recordsToAdd)
            print("✅ Final batch uploaded successfully!")
        } catch {
            print("❌ Error uploading final batch: \(error.localizedDescription)")
        }
    }

    // Print summary
    print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("📊 SUMMARY")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("✅ Successfully added: \(successCount)")
    print("⚠️  Videos not found: \(notFoundCount)")
    print("❌ Errors: \(failureCount)")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    if !failedSongs.isEmpty {
        print("\n❌ FAILED SONGS:")
        for (song, error) in failedSongs {
            print("  • \(song.title) - \(song.artist): \(error)")
        }
    }
}

// Run the async function
await processSongs()
