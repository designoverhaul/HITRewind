import Foundation
// import XCDYouTubeKit // Removed

// // Define YouTube video quality constants if not already defined // Removed
// struct YouTubeVideoQuality {
//     static let hd720 = NSNumber(value: XCDYouTubeVideoQuality.HD720.rawValue)
//     static let medium360 = NSNumber(value: XCDYouTubeVideoQuality.medium360.rawValue)
//     static let small240 = NSNumber(value: XCDYouTubeVideoQuality.small240.rawValue)
// }

// // Extend XCDYouTubeClient to provide a fixed version that handles the hostname.split error // Removed
// // This extension is currently not being used directly - the functionality has been moved
// // into each view controller to avoid import issues. Keeping this here for reference.
// extension XCDYouTubeClient {
//    
//     // Safe patterns to use that avoid the window.location.hostname.split error
//     static let safeCustomPatterns = [
//         // Standard patterns that avoid the hostname.split issue
//         "\\b[cs]\\s*&&\\s*[adf]\\.set\\([^,]+\\s*,\\s*encodeURIComponent\\s*\\(\\s*([a-zA-Z0-9$]+)\\(",
//         "\\b[a-zA-Z0-9]+\\s*&&\\s*[a-zA-Z0-9]+\\.set\\([^,]+\\s*,\\s*encodeURIComponent\\s*\\(\\s*([a-zA-Z0-9$]+)\\(",
//         "(?:\\b|[^a-zA-Z0-9$])([a-zA-Z0-9$]{2})\\s*=\\s*function\\(\\s*a\\s*\\)\\s*\\{\\s*a\\s*=\\s*a\\.split\\(\\s*\"\"\\s*\\)"
//     ]
//    
//     // Helper method to get video with fixed patterns
//     class func getVideoWithFixedPatterns(videoIdentifier: String, completion: @escaping (XCDYouTubeVideo?, Error?) -> Void) {
//         XCDYouTubeClient.default().getVideoWithIdentifier(
//             videoIdentifier, 
//             cookies: nil, 
//             customPatterns: safeCustomPatterns, 
//             completionHandler: completion
//         )
//     }
// }

// Extract YouTube video ID from a URL
func extractYouTubeVideoID(from videoURL: String) -> String? {
    guard let url = URL(string: videoURL),
          let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else {
        return nil
    }
    for queryItem in queryItems {
        if queryItem.name.lowercased() == "v" {
            return queryItem.value
        }
    }
    return nil
} 