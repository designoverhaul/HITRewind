import Foundation

// MARK: - Search Result Models
struct SearchResult {
    let id: String
    let title: String
    let artistName: String
    let year: String
    let url: String
    let videoImage: String
    let type: SearchResultType
}

enum SearchResultType {
    case video
    case mtvVideo
}

// MARK: - Response Models for Airtable
struct SearchResponse: Codable {
    let records: [SearchRecord]
}

struct SearchRecord: Codable {
    let id: String
    let fields: SearchFields
}

struct SearchFields: Codable {
    let title: String?
    let artistName: String?
    let year: String?
    let url: String?
    let videoImage: String?
    
    // Videos table specific
    var Title: String? { return title }
    var Year: String? { return year }
    var URL: String? { return url }
    
    private enum CodingKeys: String, CodingKey {
        case title = "title"
        case artistName = "artistName"
        case year = "year"
        case url = "url"
        case videoImage = "videoImage"
        case Title = "Title"
        case Year = "Year"
        case URL = "URL"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try both lowercase and uppercase variants
        title = (try? container.decode(String.self, forKey: .title)) ?? 
                (try? container.decode(String.self, forKey: .Title))
        
        // Handle artistName as either string or array of strings
        if let artistNameString = try? container.decode(String.self, forKey: .artistName) {
            artistName = artistNameString
        } else if let artistNameArray = try? container.decode([String].self, forKey: .artistName) {
            artistName = artistNameArray.first
        } else {
            artistName = nil
        }
        
        if let yearInt = try? container.decode(Int.self, forKey: .year) {
            year = String(yearInt)
        } else if let yearString = try? container.decode(String.self, forKey: .year) {
            year = yearString
        } else if let yearString = try? container.decode(String.self, forKey: .Year) {
            year = yearString
        } else {
            year = nil
        }
        
        url = (try? container.decode(String.self, forKey: .url)) ?? 
              (try? container.decode(String.self, forKey: .URL))
        
        videoImage = try? container.decode(String.self, forKey: .videoImage)
    }
}

// MARK: - Search Service
class SearchService {
    static let shared = SearchService()
    private let apiKey = "pat9HXwt4uUaLl3SC.3a38959399a2a1d101c726e5e3ce154b37661244db837be7698a27cd18fd764b"
    private let baseId = "appxCBIOkiJEZiph7"
    
    private init() {}
    
    func searchArtists(query: String, completion: @escaping (Result<[SearchResult], Error>) -> Void) {
        let group = DispatchGroup()
        var allResults: [SearchResult] = []
        var searchError: Error?
        
        // Search in Videos table
        group.enter()
        searchInVideosTable(query: query) { result in
            switch result {
            case .success(let results):
                allResults.append(contentsOf: results)
            case .failure(let error):
                searchError = error
            }
            group.leave()
        }
        
        // Search in MTvVideos table
        group.enter()
        searchInMTvVideosTable(query: query) { result in
            switch result {
            case .success(let results):
                allResults.append(contentsOf: results)
            case .failure(let error):
                if searchError == nil {
                    searchError = error
                }
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            if let error = searchError {
                completion(.failure(error))
            } else {
                // Sort results by artist name
                let sortedResults = allResults.sorted { $0.artistName < $1.artistName }
                completion(.success(sortedResults))
            }
        }
    }
    
    private func searchInVideosTable(query: String, completion: @escaping (Result<[SearchResult], Error>) -> Void) {
        // Handle artistName as an array in Videos table
        let formula = "FIND('\(query)', ARRAYJOIN({artistName}, ', '))"
        let urlString = "https://api.airtable.com/v0/\(baseId)/Videos?filterByFormula=\(formula.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        performSearch(urlString: urlString, type: .video, completion: completion)
    }
    
    private func searchInMTvVideosTable(query: String, completion: @escaping (Result<[SearchResult], Error>) -> Void) {
        let formula = "FIND('\(query)', {artistName})"
        let urlString = "https://api.airtable.com/v0/\(baseId)/MTvVideos?filterByFormula=\(formula.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        performSearch(urlString: urlString, type: .mtvVideo, completion: completion)
    }
    
    private func performSearch(urlString: String, type: SearchResultType, completion: @escaping (Result<[SearchResult], Error>) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "No data received", code: 0, userInfo: nil)))
                }
                return
            }
            
            do {
                let searchResponse = try JSONDecoder().decode(SearchResponse.self, from: data)
                let results = searchResponse.records.compactMap { record -> SearchResult? in
                    guard let title = record.fields.title ?? record.fields.Title,
                          let artistName = record.fields.artistName,
                          let year = record.fields.year ?? record.fields.Year,
                          let url = record.fields.url ?? record.fields.URL else {
                        return nil
                    }
                    
                    return SearchResult(
                        id: record.id,
                        title: title,
                        artistName: artistName,
                        year: year,
                        url: url,
                        videoImage: record.fields.videoImage ?? "",
                        type: type
                    )
                }
                
                DispatchQueue.main.async {
                    completion(.success(results))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
} 