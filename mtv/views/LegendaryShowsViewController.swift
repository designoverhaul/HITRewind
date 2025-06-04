import UIKit
// import XCDYouTubeKit // Replaced with YouTubeKit
import YouTubeKit // Added for the new YouTube player
import AVKit
// import RevenueCat // Temporarily commented out

// MARK: - YouTubeVideoQuality

// struct YouTubeVideoQuality { ... } // Removed duplicate definition

// MARK: - Legendary Show Models
struct LegendaryShow: Codable {
    let id: String
    let fields: LegendaryShowFields
}

struct LegendaryShowFields: Codable {
    let title: String?
    let artist: String?
    let year: String?
    let url: String?
    let thumbnail: String?
    
    enum CodingKeys: String, CodingKey {
        case title = "Title"
        case artist = "Artist"
        case year = "Year"
        case url = "URL"
        case thumbnail = "thumbnail"
    }
}

struct LegendaryShowResponse: Codable {
    let records: [LegendaryShow]
}

// Function to fetch legendary shows from separate table
func fetchLegendaryShows(apiKey: String, baseURLString: String, completion: @escaping (Result<[LegendaryShow], Error>) -> Void) {
    // No filter needed since this is a dedicated legendary shows table
    guard let url = URL(string: baseURLString) else {
        print("🌟 LEGENDARY DEBUG: Failed to create URL")
        completion(.failure(NSError(domain: "URLError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
        return
    }
    
    print("🌟 LEGENDARY DEBUG: Final URL: \(url)")
    
    var request = URLRequest(url: url)
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("🌟 LEGENDARY DEBUG: Network error: \(error)")
            completion(.failure(error))
            return
        }
        
        if let httpResponse = response as? HTTPURLResponse {
            print("🌟 LEGENDARY DEBUG: HTTP Status: \(httpResponse.statusCode)")
        }
        
        guard let data = data else {
            print("🌟 LEGENDARY DEBUG: No data received")
            completion(.failure(NSError(domain: "DataError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
            return
        }
        
        print("🌟 LEGENDARY DEBUG: Received data length: \(data.count)")
        
        // Print raw JSON for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            print("🌟 LEGENDARY DEBUG: Raw JSON response: \(jsonString)")
        }
        
        do {
            let decoder = JSONDecoder()
            let legendaryShowResponse = try decoder.decode(LegendaryShowResponse.self, from: data)
            let legendaryShows = legendaryShowResponse.records
            print("🌟 LEGENDARY DEBUG: Successfully decoded \(legendaryShows.count) shows")
            
            // Print details of each show for debugging
            for (index, show) in legendaryShows.enumerated() {
                print("🌟 LEGENDARY DEBUG: Show \(index): \(show.fields.title ?? "No title"), Artist: \(show.fields.artist ?? "No artist")")
            }
            
            completion(.success(legendaryShows))
        } catch {
            print("🌟 LEGENDARY DEBUG: Decoding error: \(error)")
            completion(.failure(error))
        }
    }.resume()
}

class LegendaryShowsViewController: UIViewController, AVPlayerViewControllerDelegate {
    
    // MARK: - Properties
    
    // Custom colors
    private let purpleColor = UIColor(red: 167/255, green: 137/255, blue: 253/255, alpha: 1.0)  // #A789FD
    private let darkGrayColor = UIColor(red: 41/255, green: 38/255, blue: 49/255, alpha: 1.0)   // #292631
    
    private var legendaryShows: [LegendaryShow] = []
    private var collectionView: UICollectionView!
    private var loadingIndicator: UIActivityIndicatorView!
    
    // Subscription management properties
    // private var isSubscribed: Bool = false // Temporarily commented out
    private var isSubscribed: Bool = true // Assume subscribed for debugging
    
    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        showLoadingIndicator()
        fetchLegendaryShows()
        // checkSubscriptionStatus() // Temporarily commented out
        print("LegendaryShowsViewController: checkSubscriptionStatus bypassed.")
        
        // Add observer for subscription status change
        // NotificationCenter.default.addObserver(self, selector: #selector(subscriptionStatusChanged), name: Notification.Name("SubscriptionStatusChanged"), object: nil) // Temporarily commented out
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // checkSubscriptionStatus() // Temporarily commented out
        print("LegendaryShowsViewController: viewWillAppear - subscription check bypassed.")
        isSubscribed = true // Assume subscribed
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // MTV logo imageView setup (same positioning as search screen)
        let imageView = UIImageView(image: UIImage(named: "logoVector"))
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)
        
        // Collection view setup - 3 columns, full width
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 30
        layout.minimumLineSpacing = 40
        
        // Calculate item size for 4 columns using full width
        let screenWidth = UIScreen.main.bounds.width
        let totalHorizontalPadding: CGFloat = 80 // 40 on each side (reduced for full width)
        let totalSpacing: CGFloat = 3 * 30 // 3 spaces between 4 items
        let availableWidth = screenWidth - totalHorizontalPadding - totalSpacing
        let itemWidth = availableWidth / 4
        let itemHeight: CGFloat = 380 // Increased from 320 to provide more space for text
        
        layout.itemSize = CGSize(width: itemWidth, height: itemHeight)
        layout.sectionInset = UIEdgeInsets(top: 20, left: 40, bottom: 20, right: 40)
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(LegendaryShowCell.self, forCellWithReuseIdentifier: "LegendaryShowCell")
        view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        
        // Layout constraints (same positioning as search screen)
        NSLayoutConstraint.activate([
            // Logo (same as search screen)
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 152),
            imageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 40),
            imageView.widthAnchor.constraint(equalToConstant: 98),
            imageView.heightAnchor.constraint(equalToConstant: 77),
            
            // Collection View (full width like search screen)
            collectionView.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 30),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    // MARK: - Data Fetching
    
    private func fetchLegendaryShows() {
        print("🌟 LegendaryShowsViewController: Starting to fetch legendary shows")
        
        MTV_Music_Videos.fetchLegendaryShows(apiKey: apiKey, baseURLString: legendaryShowsUrl) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let shows):
                print("🌟 LegendaryShowsViewController: Successfully fetched \(shows.count) legendary shows")
                self.legendaryShows = shows
                DispatchQueue.main.async {
                    self.collectionView.reloadData()
                    self.hideLoadingIndicator()
                }
            case .failure(let error):
                print("🌟 LegendaryShowsViewController: Error fetching legendary shows: \(error)")
                DispatchQueue.main.async {
                    self.hideLoadingIndicator()
                }
            }
        }
    }
    
    // MARK: - Loading Indicator
    
    private func showLoadingIndicator() {
        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.color = .white
        loadingIndicator.startAnimating()
        view.addSubview(loadingIndicator)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func hideLoadingIndicator() {
        loadingIndicator?.stopAnimating()
        loadingIndicator?.removeFromSuperview()
    }
    
    // MARK: - YouTube Playlist Support
    
    private func isPlaylistURL(_ url: String) -> Bool {
        return url.contains("playlist?list=") || url.contains("&list=")
    }
    
    private func extractPlaylistId(from url: String) -> String? {
        guard let urlComponents = URLComponents(string: url),
              let queryItems = urlComponents.queryItems else {
            return nil
        }
        
        return queryItems.first(where: { $0.name == "list" })?.value
    }
    
    private func fetchPlaylistVideoIds(playlistId: String, completion: @escaping ([String]) -> Void) {
        // YouTube Data API key - you'll need to add this to your constants
        let apiKey = "AIzaSyChKL0fUHEfc1AlKe0ks53Y2wT78gxLiJE" // Use your existing YouTube API key
        let urlString = "https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&maxResults=50&playlistId=\(playlistId)&key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            print("🌟 Invalid YouTube API URL")
            completion([])
            return
        }
        
        print("🌟 Fetching playlist videos from: \(urlString)")
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("🌟 Error fetching playlist: \(error)")
                completion([])
                return
            }
            
            guard let data = data else {
                print("🌟 No data received from YouTube API")
                completion([])
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let items = json["items"] as? [[String: Any]] {
                    
                    let videoIds = items.compactMap { item -> String? in
                        guard let snippet = item["snippet"] as? [String: Any],
                              let resourceId = snippet["resourceId"] as? [String: Any],
                              let videoId = resourceId["videoId"] as? String else {
                            return nil
                        }
                        return videoId
                    }
                    
                    print("🌟 Successfully extracted \(videoIds.count) video IDs from playlist")
                    completion(videoIds)
                } else {
                    print("🌟 Failed to parse YouTube API response")
                    completion([])
                }
            } catch {
                print("🌟 Error parsing YouTube API response: \(error)")
                completion([])
            }
        }.resume()
    }
    
    // MARK: - Video Playback
    
    private func playVideo(with url: String) {
        // Check if this is a playlist URL
        if isPlaylistURL(url) {
            playPlaylist(with: url)
        } else {
            playSingleVideo(with: url)
        }
    }
    
    private func playPlaylist(with url: String) {
        guard let playlistId = extractPlaylistId(from: url) else {
            print("🌟 Could not extract playlist ID from URL: \(url)")
            return
        }
        
        print("🌟 Playing playlist with ID: \(playlistId)")
        
        // Show loading indicator
        let loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.color = .white
        loadingIndicator.center = view.center
        view.addSubview(loadingIndicator)
        loadingIndicator.startAnimating()
        
        fetchPlaylistVideoIds(playlistId: playlistId) { [weak self] videoIds in
            DispatchQueue.main.async {
                loadingIndicator.stopAnimating()
                loadingIndicator.removeFromSuperview()
                
                if videoIds.isEmpty {
                    print("🌟 No videos found in playlist")
                    return
                }
                
                print("🌟 Starting playlist playback with \(videoIds.count) videos")
                self?.playVideoPlaylist(videoIdentifiers: videoIds)
            }
        }
    }
    
    private func playSingleVideo(with url: String) {
        guard let videoId = extractVideoId(from: url) else {
            print("🌟 Invalid video URL: \(url)")
            return
        }
        
        let loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.color = .white
        loadingIndicator.center = view.center
        view.addSubview(loadingIndicator)
        loadingIndicator.startAnimating()
        
        let playerViewController = AVPlayerViewController()
        playerViewController.modalPresentationStyle = .fullScreen
        playerViewController.delegate = self
        
        print("🌟 Starting YouTube video playback for ID: \(videoId) using YouTubeKit")
        
        Task { @MainActor in // Use Task for async operation
            defer {
                loadingIndicator.stopAnimating()
                loadingIndicator.removeFromSuperview()
            }
            
            do {
                let video = YouTube(videoID: videoId, methods: [.local, .remote])
                
                // Attempt to get HLS livestreams first (long shot for VOD)
                var hlsStreamURL: URL? = nil
                do {
                    let liveStreams = try await video.livestreams
                    if let hlsStream = liveStreams.filter({ $0.streamType == .hls }).first {
                        hlsStreamURL = hlsStream.url
                        print("🌟 Found HLS livestream URL: \(hlsStreamURL!)")
                    }
                } catch {
                    print("ⓘ No HLS livestreams found or error fetching them for video ID \(videoId): \(error.localizedDescription)")
                }

                if let validHLSUrl = hlsStreamURL {
                    print("🌟 Attempting to play HLS stream for video ID: \(videoId)")
                    let avPlayer = AVPlayer(url: validHLSUrl)
                    playerViewController.player = avPlayer
                    self.present(playerViewController, animated: true) {
                        print("✅ LegendaryShowsViewController: AVPlayerViewController presented for HLS video ID: \(videoId)")
                        avPlayer.play()
                    }
                    return // Exit if HLS stream is played
                }

                // If no HLS stream, proceed with regular stream extraction
                let allFetchedStreams = try await video.streams // Fetch all streams asynchronously

                print("--- DEBUG: All streams returned by YouTubeKit for \(video.videoID ?? "Unknown VideoID") ---")
                if allFetchedStreams.isEmpty {
                    print("YouTubeKit returned no streams.")
                } else {
                    for (index, stream) in allFetchedStreams.enumerated() {
                        let url = stream.url
                        let isPlayable = stream.isNativelyPlayable
                        // Check if this individual stream would be considered combined A/V by YouTubeKit's filter
                        let isCombined = !([stream].filterVideoAndAudio().isEmpty)
                        print("  Stream \(index): URL contains itag=\(url.absoluteString.components(separatedBy: "itag=").last?.components(separatedBy: "&").first ?? "N/A"), NativelyPlayable: \(isPlayable), Combined A/V: \(isCombined)")
                    }
                }
                print("--- END DEBUG ---")
                
                let combinedAudioVideoStreams = allFetchedStreams.filterVideoAndAudio()
                let playableCombinedStreams = combinedAudioVideoStreams.filter { $0.isNativelyPlayable }

                var finalStream: YouTubeKit.Stream?
                var selectedQualityDescription = "Unknown"

                if !playableCombinedStreams.isEmpty {
                    // Try for 720p from combined, playable streams
                    if let first720pStream = playableCombinedStreams.streams(withExactResolution: 720).first {
                        finalStream = first720pStream
                        selectedQualityDescription = "720p (Combined A/V)"
                    }
                    // Else, try for 480p from combined, playable streams
                    else if let first480pStream = playableCombinedStreams.streams(withExactResolution: 480).first {
                        finalStream = first480pStream
                        selectedQualityDescription = "480p (Combined A/V)"
                    }
                    // Else, try for 360p from combined, playable streams
                    else if let first360pStream = playableCombinedStreams.streams(withExactResolution: 360).first {
                        finalStream = first360pStream
                        selectedQualityDescription = "360p (Combined A/V)"
                    }
                    // Else, take the lowest available resolution from combined, playable streams
                    else if let lowestPlayableCombined = playableCombinedStreams.lowestResolutionStream() {
                        finalStream = lowestPlayableCombined
                        selectedQualityDescription = "Lowest Playable (Combined A/V)"
                    }
                }
                // If playableCombinedStreams is empty, finalStream will remain nil here.

                if let streamToPlay = finalStream {
                    let streamURL = streamToPlay.url
                    print("🌟 Selected \(selectedQualityDescription) stream. LegendaryShowsViewController: YouTubeKit Stream URL: \(streamURL) for video ID: \(videoId)")
                    let avPlayer = AVPlayer(url: streamURL)
                    playerViewController.player = avPlayer
                    self.present(playerViewController, animated: true) {
                        print("✅ LegendaryShowsViewController: AVPlayerViewController presented for video ID: \(videoId)")
                        avPlayer.play()
                        print("▶️ LegendaryShowsViewController: avPlayer.play() called for video ID: \(videoId)")
                    }
                } else {
                    // This 'else' block is now reached if no HLS stream was found AND no suitable combined A/V stream was found.
                    print("🚫 LegendaryShowsViewController: YouTubeKit - Could not find a suitable combined audio/video stream for video ID: \(videoId)")
                    let alert = UIAlertController(title: "Playback Unavailable", message: "This video is not available in a directly playable format (no combined audio/video stream found).", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                }
            } catch {
                print("🚫 YouTubeKit failed to get streams for video ID \(videoId). Error: \(error)")
                // Optionally, show an alert to the user
                let alert = UIAlertController(title: "Playback Error", message: "Could not load video information: \(error.localizedDescription)", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    // MARK: - Playlist Playback (adapted from PlayListViewController)
    
    func playVideoPlaylist(videoIdentifiers: [String], currentIndex: Int = 0) {
        guard currentIndex < videoIdentifiers.count else {
            print("🌟 Playlist finished - all videos played")
            return
        }
        
        let loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.color = .white
        loadingIndicator.center = view.center
        view.addSubview(loadingIndicator)
        loadingIndicator.startAnimating()
        
        let playerViewController = AVPlayerViewController()
        playerViewController.modalPresentationStyle = .fullScreen
        playerViewController.delegate = self
        
        let currentVideoIdentifier = videoIdentifiers[currentIndex]
        
        print("🌟 Starting playlist video \(currentIndex + 1)/\(videoIdentifiers.count) - ID: \(currentVideoIdentifier) using YouTubeKit")
        
        Task { @MainActor in // Use Task for async operation
            defer {
                loadingIndicator.stopAnimating()
                loadingIndicator.removeFromSuperview()
            }
            
            do {
                let video = YouTube(videoID: currentVideoIdentifier, methods: [.local, .remote])
                
                // Attempt to get HLS livestreams first (long shot for VOD)
                var hlsStreamURL: URL? = nil
                do {
                    let liveStreams = try await video.livestreams
                    if let hlsStream = liveStreams.filter({ $0.streamType == .hls }).first {
                        hlsStreamURL = hlsStream.url
                        print("🌟 Found HLS livestream URL: \(hlsStreamURL!) for playlist item: \(currentVideoIdentifier)")
                    }
                } catch {
                     print("ⓘ No HLS livestreams found or error fetching them for playlist video ID \(currentVideoIdentifier): \(error.localizedDescription)")
                }

                if let validHLSUrl = hlsStreamURL {
                    print("🌟 Attempting to play HLS stream for playlist video ID: \(currentVideoIdentifier)")
                    let avPlayer = AVPlayer(url: validHLSUrl)
                    playerViewController.player = avPlayer
                    self.present(playerViewController, animated: true) { 
                        print("✅ LegendaryShowsViewController (Playlist): AVPlayerViewController presented for HLS video ID: \(currentVideoIdentifier)")
                        avPlayer.play()
                        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: avPlayer.currentItem, queue: .main) { [weak self, weak playerViewController] _ in
                            NotificationCenter.default.removeObserver(self as Any, name: .AVPlayerItemDidPlayToEndTime, object: avPlayer.currentItem)
                            playerViewController?.dismiss(animated: true) {
                                self?.playVideoPlaylist(videoIdentifiers: videoIdentifiers, currentIndex: currentIndex + 1)
                            }
                        }
                    }
                    return // Exit if HLS stream is played
                }

                // If no HLS stream, proceed with regular stream extraction
                let allFetchedStreams = try await video.streams

                print("--- DEBUG: All streams returned by YouTubeKit for playlist video \(video.videoID ?? "Unknown VideoID") ---")
                 if allFetchedStreams.isEmpty {
                    print("YouTubeKit returned no streams for playlist video.")
                } else {
                    for (index, stream) in allFetchedStreams.enumerated() {
                        let url = stream.url
                        let isPlayable = stream.isNativelyPlayable
                        // Check if this individual stream would be considered combined A/V by YouTubeKit's filter
                        let isCombined = !([stream].filterVideoAndAudio().isEmpty)
                        print("  Stream \(index): URL contains itag=\(url.absoluteString.components(separatedBy: "itag=").last?.components(separatedBy: "&").first ?? "N/A"), NativelyPlayable: \(isPlayable), Combined A/V: \(isCombined)")
                    }
                }
                print("--- END DEBUG ---")
                
                let combinedAudioVideoStreams = allFetchedStreams.filterVideoAndAudio()
                let playableCombinedStreams = combinedAudioVideoStreams.filter { $0.isNativelyPlayable }

                var finalStream: YouTubeKit.Stream?
                var selectedQualityDescription = "Unknown"

                if !playableCombinedStreams.isEmpty {
                    // Try for 720p from combined, playable streams
                    if let first720pStream = playableCombinedStreams.streams(withExactResolution: 720).first {
                        finalStream = first720pStream
                        selectedQualityDescription = "720p (Combined A/V)"
                    }
                    // Else, try for 480p from combined, playable streams
                    else if let first480pStream = playableCombinedStreams.streams(withExactResolution: 480).first {
                        finalStream = first480pStream
                        selectedQualityDescription = "480p (Combined A/V)"
                    }
                    // Else, try for 360p from combined, playable streams
                    else if let first360pStream = playableCombinedStreams.streams(withExactResolution: 360).first {
                        finalStream = first360pStream
                        selectedQualityDescription = "360p (Combined A/V)"
                    }
                    // Else, take the lowest available resolution from combined, playable streams
                    else if let lowestPlayableCombined = playableCombinedStreams.lowestResolutionStream() {
                        finalStream = lowestPlayableCombined
                        selectedQualityDescription = "Lowest Playable (Combined A/V)"
                    }
                }
                // If playableCombinedStreams is empty, finalStream will remain nil here.
                
                if let streamToPlay = finalStream {
                    let streamURL = streamToPlay.url
                    print("🌟 Selected \(selectedQualityDescription) stream. LegendaryShowsViewController (Playlist): YouTubeKit Stream URL: \(streamURL) for video ID: \(currentVideoIdentifier)")
                    let avPlayer = AVPlayer(url: streamURL)
                    playerViewController.player = avPlayer
                    
                    self.present(playerViewController, animated: true) {
                        print("✅ LegendaryShowsViewController (Playlist): AVPlayerViewController presented for video ID: \(currentVideoIdentifier)")
                        avPlayer.play()
                        print("▶️ LegendaryShowsViewController (Playlist): avPlayer.play() called for video ID: \(currentVideoIdentifier)")
                        
                        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: avPlayer.currentItem, queue: .main) { [weak self, weak playerViewController] _ in
                            NotificationCenter.default.removeObserver(self as Any, name: .AVPlayerItemDidPlayToEndTime, object: avPlayer.currentItem)
                            playerViewController?.dismiss(animated: true) {
                                self?.playVideoPlaylist(videoIdentifiers: videoIdentifiers, currentIndex: currentIndex + 1)
                            }
                        }
                    }
                } else {
                    // This 'else' block is now reached if no HLS stream was found AND no suitable combined A/V stream was found for the playlist item.
                    print("🚫 LegendaryShowsViewController (Playlist): YouTubeKit - Could not find a suitable combined audio/video stream for video ID: \(currentVideoIdentifier)")
                    let alert = UIAlertController(title: "Playback Unavailable", message: "This video in the playlist is not available in a directly playable format (no combined audio/video stream found). Skipping to next.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                        self.playVideoPlaylist(videoIdentifiers: videoIdentifiers, currentIndex: currentIndex + 1)
                    }))
                    self.present(alert, animated: true, completion: nil)
                }
            } catch {
                print("🚫 YouTubeKit failed to get streams for video ID \(currentVideoIdentifier). Error: \(error)")
                // Optionally, show an alert to the user
                let alert = UIAlertController(title: "Playback Error", message: "Could not load video information for playlist item: \(error.localizedDescription)", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                    // Skip to next video if in a playlist context
                    self.playVideoPlaylist(videoIdentifiers: videoIdentifiers, currentIndex: currentIndex + 1)
                }))
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    private func extractVideoId(from url: String) -> String? {
        guard let urlComponents = URLComponents(string: url),
              let queryItems = urlComponents.queryItems else {
            return nil
        }
        
        return queryItems.first(where: { $0.name == "v" })?.value
    }
    
    // MARK: - Subscription Management
    
    private func checkSubscriptionStatus() {
        // Purchases.shared.getCustomerInfo { [weak self] (customerInfo, error) in // Temporarily commented out
        //     guard let self = self else { return }

        //     if let customerInfo = customerInfo {
        //         let activeEntitlements = customerInfo.entitlements.all.filter { $0.value.isActive }
        //         if !activeEntitlements.isEmpty {
        //             self.isSubscribed = true
        //             print("🌟 LegendaryShowsViewController: User is subscribed")
        //         } else {
        //             self.isSubscribed = false
        //             print("🌟 LegendaryShowsViewController: User is not subscribed")
        //         }
        //     } else if let error = error {
        //         print("🌟 LegendaryShowsViewController: Error fetching customer info: \(error.localizedDescription)")
        //         self.isSubscribed = false
        //     }
        // }
        print("LegendaryShowsViewController: checkSubscriptionStatus called - Bypassed, assuming subscribed.")
        isSubscribed = true // Assume subscribed
    }
    
    @objc private func subscriptionStatusChanged() {
        // checkSubscriptionStatus() // Temporarily commented out
        print("LegendaryShowsViewController: subscriptionStatusChanged called - Bypassed.")
        isSubscribed = true // Assume subscribed
    }
    
    @objc private func navigateToPurchases() {
        // let purchasesViewController = PurchasesViewController() // Temporarily commented out
        // purchasesViewController.modalPresentationStyle = .fullScreen
        // present(purchasesViewController, animated: true, completion: nil)
        print("LegendaryShowsViewController: navigateToPurchases called - Bypassed.")
        // Optionally, show an alert that this feature is temporarily disabled
        let alert = UIAlertController(title: "Temporarily Disabled", message: "Access to the subscription screen is temporarily disabled for debugging.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}

// MARK: - Collection View Data Source

extension LegendaryShowsViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return legendaryShows.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LegendaryShowCell", for: indexPath) as? LegendaryShowCell else {
            return UICollectionViewCell()
        }
        
        let show = legendaryShows[indexPath.item]
        cell.configure(with: show)
        return cell
    }
}

// MARK: - Collection View Delegate

extension LegendaryShowsViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedShow = legendaryShows[indexPath.item]
        // requireSubscription(on: self) { [weak self] isSubscribed in // Temporarily commented out
        //     guard let self = self, isSubscribed else { return }
        //     if let url = selectedShow.fields.url {
        //         print("🌟 LegendaryShowsViewController: User subscribed, playing video: \(selectedShow.fields.title ?? "Unknown")")
        //         self.playVideo(with: url)
        //     }
        // }
        print("LegendaryShowsViewController: collectionView.didSelectItemAt - Bypassing requireSubscription.")
        if let url = selectedShow.fields.url {
            print("🌟 LegendaryShowsViewController: Playing video (subscription check bypassed): \(selectedShow.fields.title ?? "Unknown")")
            self.playVideo(with: url)
        }
    }
}

// MARK: - Legendary Show Cell

class LegendaryShowCell: UICollectionViewCell {
    // Container for thumbnail to allow glow without clipping
    private let thumbnailContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 12
        iv.backgroundColor = UIColor.black.withAlphaComponent(0.1)
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    // Title, artist, and year labels below the thumbnail
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        // 30% smaller than 38: use 27
        if let customFont = UIFont(name: "Anton-Regular", size: 27) {
            label.font = customFont
        } else {
            print("⚠️ Anton-Regular font not found, using system bold.")
            label.font = UIFont.systemFont(ofSize: 27, weight: .bold)
        }
        label.textAlignment = .left
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    private let artistLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(hex: "#A789FD")
        label.font = UIFont.systemFont(ofSize: 25, weight: .semibold)
        label.textAlignment = .left
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    private let yearLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(hex: "#A789FD")
        label.font = UIFont.systemFont(ofSize: 25, weight: .semibold)
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    private func setupCell() {
        contentView.clipsToBounds = false
        layer.masksToBounds = false
        // Thumbnail container for glow
        contentView.addSubview(thumbnailContainer)
        thumbnailContainer.addSubview(imageView)
        // Remove overlay and move all meta below image
        contentView.addSubview(titleLabel)
        contentView.addSubview(artistLabel)
        contentView.addSubview(yearLabel)
        NSLayoutConstraint.activate([
            // Thumbnail container (for glow)
            thumbnailContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            thumbnailContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            thumbnailContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            thumbnailContainer.heightAnchor.constraint(equalTo: thumbnailContainer.widthAnchor, multiplier: 9.0/16.0),
            // Image view inside container
            imageView.topAnchor.constraint(equalTo: thumbnailContainer.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: thumbnailContainer.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: thumbnailContainer.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: thumbnailContainer.bottomAnchor),
            // Title label below thumbnail
            titleLabel.topAnchor.constraint(equalTo: thumbnailContainer.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            // Artist label below title
            artistLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            artistLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            artistLabel.trailingAnchor.constraint(lessThanOrEqualTo: yearLabel.leadingAnchor, constant: -8),
            artistLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 22),
            // Year label inline with artist label, right-aligned
            yearLabel.centerYAnchor.constraint(equalTo: artistLabel.centerYAnchor),
            yearLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            yearLabel.leadingAnchor.constraint(greaterThanOrEqualTo: artistLabel.trailingAnchor, constant: 8),
            // Bottom constraint for cell
            artistLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -10)
        ])
        // Compression/hugging priorities
        artistLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        artistLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        yearLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        yearLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        // Clear content for reuse
        titleLabel.text = nil
        artistLabel.text = nil
        yearLabel.text = nil
        thumbnailContainer.transform = .identity
        thumbnailContainer.layer.shadowOpacity = 0
    }
    func configure(with show: LegendaryShow) {
        titleLabel.text = show.fields.title ?? "Unknown Title"
        artistLabel.text = show.fields.artist ?? "Unknown Artist"
        artistLabel.isHidden = false
        yearLabel.text = show.fields.year ?? ""
        imageView.image = UIImage(systemName: "play.rectangle.fill")
        if let thumbnail = show.fields.thumbnail, !thumbnail.isEmpty {
            loadThumbnailFromURL(thumbnail)
        } else if let url = show.fields.url {
            if url.contains("playlist?list=") || url.contains("&list=") {
                if let playlistId = extractPlaylistIdFromURL(url) {
                    fetchPlaylistThumbnail(playlistId: playlistId)
                }
            } else if let videoId = extractVideoIdFromURL(url) {
                let thumbnailURL = "https://i.ytimg.com/vi/\(videoId)/mqdefault.jpg"
                loadThumbnailFromURL(thumbnailURL)
            }
        }
    }
    private func loadThumbnailFromURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self?.imageView.image = image
                }
            }
        }.resume()
    }
    private func fetchPlaylistThumbnail(playlistId: String) {
        let apiKey = "AIzaSyChKL0fUHEfc1AlKe0ks53Y2wT78gxLiJE"
        let urlString = "https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&maxResults=1&playlistId=\(playlistId)&key=\(apiKey)"
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let items = json["items"] as? [[String: Any]],
               let firstItem = items.first,
               let snippet = firstItem["snippet"] as? [String: Any],
               let resourceId = snippet["resourceId"] as? [String: Any],
               let videoId = resourceId["videoId"] as? String {
                let thumbnailURL = "https://i.ytimg.com/vi/\(videoId)/mqdefault.jpg"
                DispatchQueue.main.async {
                    self?.loadThumbnailFromURL(thumbnailURL)
                }
            }
        }.resume()
    }
    private func extractVideoIdFromURL(_ url: String) -> String? {
        guard let urlComponents = URLComponents(string: url),
              let queryItems = urlComponents.queryItems else { return nil }
        return queryItems.first(where: { $0.name == "v" })?.value
    }
    private func extractPlaylistIdFromURL(_ url: String) -> String? {
        guard let urlComponents = URLComponents(string: url),
              let queryItems = urlComponents.queryItems else { return nil }
        return queryItems.first(where: { $0.name == "list" })?.value
    }
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                self.contentView.backgroundColor = UIColor(hex: "292631")
                self.contentView.layer.cornerRadius = 10
                self.contentView.layer.masksToBounds = true
                self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            } else {
                self.contentView.backgroundColor = .clear
                self.contentView.layer.cornerRadius = 0
                self.contentView.layer.masksToBounds = false
                self.transform = CGAffineTransform.identity
            }
        }, completion: nil)
    }
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        titleLabel.text = nil
        artistLabel.text = nil
        yearLabel.text = nil
        // Reset overlay background
        thumbnailContainer.transform = .identity
        thumbnailContainer.layer.shadowOpacity = 0
    }
}

// UIColor hex extension is already defined in ViewController.swift 