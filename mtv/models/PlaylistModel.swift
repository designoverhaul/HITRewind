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
            let jsonObject = try decoder.decode([String: [Playlist]].self, from: data)
            // Extract playlists from the "records" key
            if var playlists = jsonObject["records"] {
                // Sort playlists based on the year field in reverse order
                playlists.sort { $0.fields.year > $1.fields.year }
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
                    // Sort videoTitles
                    let sortedVideoTitles = videoTitles.sorted()
                    
                    // Get the sorted indices
                    let sortedIndices = sortedVideoTitles.compactMap { videoTitle in
                        return videoTitles.firstIndex(of: videoTitle)
                    }
                    
                    playlists[playlistIndex].fields.videoTitles = sortedVideoTitles
                    playlists[playlistIndex].fields.mtvVideos = sortedIndices.map { playlists[playlistIndex].fields.mtvVideos?[$0] ?? "" }
                    playlists[playlistIndex].fields.videoUrls = sortedIndices.map { playlists[playlistIndex].fields.videoUrls?[$0] ?? "" }
                    playlists[playlistIndex].fields.artistNames = sortedIndices.map { playlists[playlistIndex].fields.artistNames?[$0] ?? "" }
                }
            }
            
            completion(.success(playlists))
        case .failure(let error):
            completion(.failure(error))
        }
    }
}
