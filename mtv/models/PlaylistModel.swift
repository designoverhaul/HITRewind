import Foundation
struct Playlist: Codable {
    let id: String
    var fields: PlaylistFields
}
struct PlaylistFields: Codable {
    let thumbnail: URL
    let year: Int
    let title: String
    var mtvVideos: [String]?
    var videoUrls: [String]?
    var artistNames: [String]?
    var videoTitles: [String]?
    var isVisible: [Bool?] // Change to optional Bool
}

func fetchThePlaylists(apiKey: String, baseURLString: String, completion: @escaping (Result<[Playlist], Error>) -> Void) {
    guard let url = URL(string: baseURLString) else {
        completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        guard let data = data, error == nil else {
            completion(.failure(error ?? NSError(domain: "Failed to fetch data", code: 0, userInfo: nil)))
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase // To handle snake_case keys
            let jsonObject = try decoder.decode([String: [Playlist]].self, from: data)
            // Extract playlists from the "records" key
            if var playlists = jsonObject["records"] {
                // Sort playlists based on the year field in reverse order
                playlists.sort { $0.fields.year > $1.fields.year }
                
                // Handle nullable isVisible values
                for var playlist in playlists {
                    playlist.fields.isVisible = playlist.fields.isVisible.map { $0 ?? true }
                }
                
                completion(.success(playlists))
            } else {
                completion(.failure(NSError(domain: "Invalid JSON structure: No playlists found", code: 0, userInfo: nil)))
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    task.resume()
}


func sortAndArrangePlaylists(apiKey: String, baseURLString: String, completion: @escaping (Result<[Playlist], Error>) -> Void) {
    fetchThePlaylists(apiKey: apiKey, baseURLString: baseURLString) { result in
        switch result {
        case .success(var playlists):
            // Sort playlists based on the year field in reverse order
            playlists.sort { $0.fields.year > $1.fields.year }
            
            // Iterate over each playlist
            for playlistIndex in 0..<playlists.count {
                if let videoTitles = playlists[playlistIndex].fields.videoTitles {
                    // Custom sorting closure
                    let sortedVideoTitles = videoTitles.sorted { (title1, title2) -> Bool in
                        // Check if the first character of each title is alphabet or not
                        let isTitle1Alphabet = title1.first?.isLetter ?? false
                        let isTitle2Alphabet = title2.first?.isLetter ?? false
                        
                        // Prioritize alphabet titles over special character titles
                        if isTitle1Alphabet && !isTitle2Alphabet {
                            return true
                        } else if !isTitle1Alphabet && isTitle2Alphabet {
                            return false
                        } else {
                            // If both titles start with alphabet or both start with special characters, use normal sorting
                            return title1 < title2
                        }
                    }
                    
                    // Get the sorted indices
                    let sortedIndices = sortedVideoTitles.compactMap { videoTitle in
                        return videoTitles.firstIndex(of: videoTitle)
                    }
                    
                    // Update the playlist fields with sorted data
                    playlists[playlistIndex].fields.videoTitles = sortedVideoTitles
                    playlists[playlistIndex].fields.mtvVideos = sortedIndices.map { playlists[playlistIndex].fields.mtvVideos?[$0] ?? "" }
                    playlists[playlistIndex].fields.videoUrls = sortedIndices.map { playlists[playlistIndex].fields.videoUrls?[$0] ?? "" }
                    playlists[playlistIndex].fields.artistNames = sortedIndices.map { playlists[playlistIndex].fields.artistNames?[$0] ?? "" }
                    playlists[playlistIndex].fields.isVisible = sortedIndices.map { playlists[playlistIndex].fields.isVisible[$0] ?? false }
                    print(playlists[playlistIndex].fields.isVisible)
                }
            }
            
            completion(.success(playlists))
        case .failure(let error):
            completion(.failure(error))
        }
    }
}
