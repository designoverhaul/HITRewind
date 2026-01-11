//
//  DirectVideoService.swift
//  HIt Rewind2
//
//  Service to fetch videos directly from MTvVideosNEW table
//  Created by Aaron Heine on 1/11/26.
//

import Foundation

@MainActor
class DirectVideoService: ObservableObject {
    @Published var videos: [DirectVideoRecord] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let baseURL = "https://api.airtable.com/v0/appxCBIOkiJEZiph7/tblNwqwVyflL8hNDy"

    func fetchVideos(year: String? = nil) async {
        isLoading = true
        errorMessage = nil

        do {
            var urlComponents = URLComponents(string: baseURL)
            var queryItems: [URLQueryItem] = []

            // Add filter for year if specified
            if let year = year {
                queryItems.append(URLQueryItem(name: "filterByFormula", value: "{Year}=\"\(year)\""))
            }

            // Sort by rank ascending
            queryItems.append(URLQueryItem(name: "sort[0][field]", value: "Rank"))
            queryItems.append(URLQueryItem(name: "sort[0][direction]", value: "asc"))

            // Set page size
            queryItems.append(URLQueryItem(name: "pageSize", value: "100"))

            urlComponents?.queryItems = queryItems

            guard let url = urlComponents?.url else {
                throw DirectVideoError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(AirtableConfig.apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw DirectVideoError.networkError(NSError(domain: "Invalid response", code: -1))
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw DirectVideoError.networkError(NSError(domain: "HTTP \(httpResponse.statusCode)", code: httpResponse.statusCode))
            }

            let decoder = JSONDecoder()
            var allVideos: [DirectVideoRecord] = []
            var currentData = data
            var hasMorePages = true

            // Handle pagination
            while hasMorePages {
                let videoResponse = try decoder.decode(DirectVideoRecordsResponse.self, from: currentData)
                allVideos.append(contentsOf: videoResponse.records)

                // Check if there are more pages
                if let offset = videoResponse.offset {
                    // Fetch next page
                    var nextQueryItems = queryItems
                    nextQueryItems.append(URLQueryItem(name: "offset", value: offset))
                    urlComponents?.queryItems = nextQueryItems

                    guard let nextURL = urlComponents?.url else {
                        hasMorePages = false
                        break
                    }

                    var nextRequest = URLRequest(url: nextURL)
                    nextRequest.httpMethod = "GET"
                    nextRequest.setValue("Bearer \(AirtableConfig.apiKey)", forHTTPHeaderField: "Authorization")
                    nextRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    let (nextData, _) = try await URLSession.shared.data(for: nextRequest)
                    currentData = nextData
                } else {
                    hasMorePages = false
                }
            }

            self.videos = allVideos
            print("✅ Fetched \(allVideos.count) videos from MTvVideosNEW" + (year != nil ? " for year \(year!)" : ""))

        } catch let error as DirectVideoError {
            self.errorMessage = error.localizedDescription
            print("❌ Video fetch error: \(error.localizedDescription)")
        } catch {
            self.errorMessage = "Failed to fetch videos: \(error.localizedDescription)"
            print("❌ Video fetch error: \(error)")
        }

        isLoading = false
    }

    // Get available years from loaded videos
    var availableYears: [Int] {
        let years = videos.compactMap { $0.fields.yearInt }
        return Array(Set(years)).sorted(by: >)
    }

    // Filter videos by year (only return videos with URLs for playback)
    func videos(forYear year: Int) -> [DirectVideoRecord] {
        videos.filter {
            $0.fields.yearInt == year &&
            $0.fields.url != nil &&
            $0.fields.youtubeVideoId != nil
        }
    }
}
