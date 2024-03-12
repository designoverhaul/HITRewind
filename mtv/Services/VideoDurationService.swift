
import Foundation
func convertYouTubeDurationToHoursMinutes(_ duration: String) -> String {
    // Check if the duration string starts with 'PT' and ends with 'S'
    if duration.hasPrefix("PT") && duration.hasSuffix("S") {
        // Remove the 'PT' at the beginning and 'S' at the end
        var cleanedDuration = duration
        cleanedDuration.removeFirst(2)
        cleanedDuration.removeLast()

        // Initialize variables to store hours, minutes, and seconds
        var hours = 0
        var minutes = 0

        // Split the duration string based on 'H', 'M', and 'S' to extract hours, minutes, and seconds
        if let hourRange = cleanedDuration.range(of: #"(\d+)H"#, options: .regularExpression) {
            hours = Int(cleanedDuration[hourRange].dropLast()) ?? 0
        }

        if let minuteRange = cleanedDuration.range(of: #"(\d+)M"#, options: .regularExpression) {
            minutes = Int(cleanedDuration[minuteRange].dropLast()) ?? 0
        }

        // Create a formatted string for hours and minutes
        var formattedDuration = ""
        if hours > 0 {
            formattedDuration += "\(hours)hr "
        }
        if minutes > 0 {
            formattedDuration += "\(minutes)min"
        }

        return formattedDuration.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Return an empty string if the input format is not recognized
    return ""
}


import Foundation

// Define the function to fetch video duration asynchronously
func getVideoDuration(videoUrl: String, completion: @escaping (String?) -> Void) {
    // Extract the video ID from the YouTube URL
    guard let videoID = extractYouTubeVideoID(from: videoUrl) else {
        completion(nil) // Return nil if video ID extraction fails
        return
    }
print(videoID)
    // Construct the YouTube API URL to fetch video details
    let youtubeApiKey = "AIzaSyChKL0fUHEfc1AlKe0ks53Y2wT78gxLiJE"
    let url = "https://www.googleapis.com/youtube/v3/videos?id=\(videoID)&part=contentDetails&key=\(youtubeApiKey)"

    // Create a URLRequest for the API URL
    guard let apiURL = URL(string: url) else {
        completion(nil)
        return
    }
    var request = URLRequest(url: apiURL)
    request.httpMethod = "GET"

    // Send the API request
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        // Check for errors
        if let error = error {
            print("Error fetching video duration:", error.localizedDescription)
            completion(nil)
            return
        }

        // Check if data is received
        guard let data = data else {
            completion(nil)
            return
        }

        // Parse the JSON response
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let items = json["items"] as? [[String: Any]],
               let contentDetails = items.first?["contentDetails"] as? [String: Any],
               let duration = contentDetails["duration"] as? String {
                print(duration)
                // Convert YouTube duration format to hours and minutes
                let formattedDuration = convertYouTubeDurationToHoursMinutes(duration)
                completion(formattedDuration)
            } else {
                completion(nil)
            }
        } catch {
            print("Error parsing JSON:", error.localizedDescription)
            completion(nil)
        }
    }

    // Start the API request task
    task.resume()
}

//extractYouTubeVideoID
