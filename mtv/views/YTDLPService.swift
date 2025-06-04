import Foundation
import AVKit

// MARK: - YTDLP API Response Models
struct YTDLPExtractResponse: Codable {
    let success: Bool
    let videoId: String?
    let title: String?
    let duration: Int?
    let uploader: String?
    let video_url: String? // Direct video URL
    let hls_url: String?   // HLS manifest URL (preferred for AVPlayer)
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case videoId = "video_id"
        case title
        case duration
        case uploader
        case video_url
        case hls_url
        case error
    }
}

// MARK: - YTDLPService
class YTDLPService {
    static let shared = YTDLPService()
    
    // For local testing, use localhost. For production, use your deployed server URL.
    private let backendBaseURL = "https://yt-dlp-api-882420341690.us-central1.run.app" // Or your Mac's local network IP for testing on Apple TV device
    
    private init() {}
    
    func getVideoInfo(videoId: String, completion: @escaping (Result<YTDLPExtractResponse, Error>) -> Void) {
        guard let url = URL(string: "\(backendBaseURL)/extract/\(videoId)") else {
            completion(.failure(NSError(domain: "YTDLPService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid backend URL"])))
            return
        }
        
        print("📞 YTDLPService: Fetching from URL: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 20.0 // Increased timeout for potential yt-dlp processing
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ YTDLPService: Network error - \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ YTDLPService: Not an HTTP response")
                completion(.failure(NSError(domain: "YTDLPService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
            print("⚙️ YTDLPService: HTTP Status Code - \(httpResponse.statusCode)")
            
            guard let data = data else {
                print("❌ YTDLPService: No data received")
                completion(.failure(NSError(domain: "YTDLPService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No data from server"])))
                return
            }
            
            // Debug: Print raw response
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📜 YTDLPService: Raw JSON response: \(jsonString.prefix(1000))...")
            }
            
            do {
                let decoder = JSONDecoder()
                let extractResponse = try decoder.decode(YTDLPExtractResponse.self, from: data)
                
                if extractResponse.success {
                    print("✅ YTDLPService: Successfully extracted video info for \(videoId)")
                    completion(.success(extractResponse))
                } else {
                    let errorMessage = extractResponse.error ?? "Unknown error from backend"
                    print("❌ YTDLPService: Backend returned error - \(errorMessage)")
                    completion(.failure(NSError(domain: "YTDLPService.Backend", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                }
            } catch {
                print("❌ YTDLPService: JSON Decoding Error - \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    // Helper to get the best playable URL (HLS preferred)
    func getPlayableURL(from response: YTDLPExtractResponse) -> URL? {
        if let hlsUrlString = response.hls_url, let hlsUrl = URL(string: hlsUrlString) {
            print("🎬 YTDLPService: Using HLS URL: \(hlsUrlString)")
            return hlsUrl
        }
        if let videoUrlString = response.video_url, let videoUrl = URL(string: videoUrlString) {
            print("🎬 YTDLPService: Using direct video URL: \(videoUrlString)")
            return videoUrl
        }
        print("⚠️ YTDLPService: No playable URL found in response.")
        return nil
    }

    // Test method to play a video
    func testPlayVideo(videoId: String, on viewController: UIViewController) {
        print("🧪 YTDLPService: Test playing video ID: \(videoId)")

        let loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.color = .white
        loadingIndicator.center = viewController.view.center
        viewController.view.addSubview(loadingIndicator)
        loadingIndicator.startAnimating()

        getVideoInfo(videoId: videoId) { result in
            DispatchQueue.main.async {
                loadingIndicator.stopAnimating()
                loadingIndicator.removeFromSuperview()

                switch result {
                case .success(let extractResponse):
                    guard let playableURL = self.getPlayableURL(from: extractResponse) else {
                        self.showAlert(on: viewController, title: "No Playable URL", message: "Could not find a playable video URL from the backend for \(extractResponse.title ?? videoId).")
                        return
                    }
                    
                    print("▶️ YTDLPService: Playing video: \(extractResponse.title ?? "Unknown")")
                    
                    let playerViewController = AVPlayerViewController()
                    let player = AVPlayer(url: playableURL)
                    playerViewController.player = player
                    
                    viewController.present(playerViewController, animated: true) {
                        player.play()
                    }
                    
                case .failure(let error):
                    self.showAlert(on: viewController, title: "YTDLP Test Failed", message: "Error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func showAlert(on viewController: UIViewController, title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        viewController.present(alert, animated: true)
    }
} 