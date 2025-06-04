import Foundation
import AVKit

class AlternativeVideoService {
    static let shared = AlternativeVideoService()
    private let youtubeDataAPIKey = "AIzaSyChKL0fUHEfc1AlKe0ks53Y2wT78gxLiJE" // Your existing API key
    
    private init() {}
    
    // Get video information from YouTube Data API
    func getVideoInfo(videoId: String, completion: @escaping (VideoInfo?, Error?) -> Void) {
        let urlString = "https://www.googleapis.com/youtube/v3/videos?part=snippet,contentDetails&id=\(videoId)&key=\(youtubeDataAPIKey)"
        
        guard let url = URL(string: urlString) else {
            completion(nil, NSError(domain: "InvalidURL", code: 0, userInfo: nil))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let data = data else {
                completion(nil, NSError(domain: "NoData", code: 0, userInfo: nil))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(YouTubeVideoResponse.self, from: data)
                if let item = response.items.first {
                    let videoInfo = VideoInfo(
                        id: videoId,
                        title: item.snippet.title,
                        description: item.snippet.description,
                        thumbnailURL: item.snippet.thumbnails.high?.url,
                        duration: item.contentDetails.duration
                    )
                    completion(videoInfo, nil)
                } else {
                    completion(nil, NSError(domain: "VideoNotFound", code: 404, userInfo: nil))
                }
            } catch {
                completion(nil, error)
            }
        }.resume()
    }
    
    // Show video unavailable message with Apple TV appropriate options
    func showVideoUnavailableAlert(on viewController: UIViewController, videoInfo: VideoInfo) {
        let message = """
        This video cannot be played directly due to YouTube's restrictions.
        
        Options:
        • Open in YouTube app
        • View video information
        """
        
        let alert = UIAlertController(
            title: "Video Unavailable",
            message: message,
            preferredStyle: .alert
        )
        
        // Option 1: Open in YouTube app (if available)
        alert.addAction(UIAlertAction(title: "Open in YouTube App", style: .default) { _ in
            self.openInYouTubeApp(videoId: videoInfo.id)
        })
        
        // Option 2: Show video information
        alert.addAction(UIAlertAction(title: "View Info", style: .default) { _ in
            self.showVideoInfo(on: viewController, videoInfo: videoInfo)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        DispatchQueue.main.async {
            viewController.present(alert, animated: true)
        }
    }
    
    private func openInYouTubeApp(videoId: String) {
        // Try to open in YouTube app, fallback to web
        let youtubeAppURL = URL(string: "youtube://watch?v=\(videoId)")
        let youtubeWebURL = URL(string: "https://www.youtube.com/watch?v=\(videoId)")
        
        if let appURL = youtubeAppURL, UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
        } else if let webURL = youtubeWebURL {
            UIApplication.shared.open(webURL)
        }
    }
    
    private func showVideoInfo(on viewController: UIViewController, videoInfo: VideoInfo) {
        let infoVC = VideoInfoViewController(videoInfo: videoInfo)
        infoVC.modalPresentationStyle = .formSheet
        viewController.present(infoVC, animated: true)
    }
}

// MARK: - Data Models
struct VideoInfo {
    let id: String
    let title: String
    let description: String
    let thumbnailURL: String?
    let duration: String
}

struct YouTubeVideoResponse: Codable {
    let items: [YouTubeVideoItem]
}

struct YouTubeVideoItem: Codable {
    let snippet: VideoSnippet
    let contentDetails: VideoContentDetails
}

struct VideoSnippet: Codable {
    let title: String
    let description: String
    let thumbnails: VideoThumbnails
}

struct VideoThumbnails: Codable {
    let high: VideoThumbnail?
}

struct VideoThumbnail: Codable {
    let url: String
}

struct VideoContentDetails: Codable {
    let duration: String
} 