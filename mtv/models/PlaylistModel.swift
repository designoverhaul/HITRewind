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

