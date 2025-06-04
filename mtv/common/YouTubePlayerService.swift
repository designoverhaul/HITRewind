import Foundation
import YouTubeKit
import AVKit

enum YouTubePlayerError: Error, LocalizedError {
    case videoIDInvalid
    case youtubeKitError(Error)
    case noPlayableStreamFound // HLS or combined A/V
    case noHLSStreamFound
    case noCombinedAVStreamFound
    case urlIsNil
    case unknown

    var errorDescription: String? {
        switch self {
        case .videoIDInvalid:
            return "The provided YouTube video ID is invalid."
        case .youtubeKitError(let underlyingError):
            return "YouTubeKit failed: \(underlyingError.localizedDescription)"
        case .noPlayableStreamFound:
            return "No playable video stream (HLS or Combined A/V) could be found for this video."
        case .noHLSStreamFound:
            return "No HLS stream was found for this video."
        case .noCombinedAVStreamFound:
            return "No combined audio/video stream was found for this video."
        case .urlIsNil:
            return "The stream URL obtained was nil."
        case .unknown:
            return "An unknown error occurred during video playback setup."
        }
    }
}

class YouTubePlayerService {

    static let shared = YouTubePlayerService()

    private init() {}

    func getPlayableStreamURL(for videoID: String, completion: @escaping (Result<URL, YouTubePlayerError>) -> Void) {
        print("YouTubePlayerService: Attempting to get playable stream for video ID: \(videoID)")

        Task { @MainActor in
            var foundAndReturnedHLSStream = false // Flag to track if HLS stream was processed
            do {
                let video = YouTube(videoID: videoID, methods: [.local, .remote])

                // 1. Attempt to get HLS livestreams first
                do {
                    let liveStreams = try await video.livestreams
                    if let hlsStream = liveStreams.filter({ $0.streamType == .hls }).first {
                        let hlsURL = hlsStream.url
                        print("YouTubePlayerService: Found HLS livestream URL: \(hlsURL) for video ID: \(videoID)")
                        completion(.success(hlsURL))
                        foundAndReturnedHLSStream = true // Set flag
                        return
                    }
                    print("YouTubePlayerService: No suitable HLS stream found for video ID: \(videoID).")
                } catch {
                    print("YouTubePlayerService: Error fetching HLS livestreams for video ID \(videoID): \(error.localizedDescription). Proceeding to check other streams.")
                }

                // If an HLS stream was found and completion was called, we would have returned.
                // So if we are here, HLS was not successfully processed or found.

                // 2. If no HLS stream, proceed with regular combined A/V stream extraction
                let allFetchedStreams = try await video.streams

                print("--- DEBUG YouTubePlayerService: All streams for \(videoID) ---")
                if allFetchedStreams.isEmpty {
                    print("YouTubePlayerService: YouTubeKit returned no streams for video ID: \(videoID)")
                } else {
                    for (index, stream) in allFetchedStreams.enumerated() {
                        let isCombined = !([stream].filterVideoAndAudio().isEmpty)
                        print("  Stream \(index): itag=\(stream.itag), NativelyPlayable: \(stream.isNativelyPlayable), Combined A/V: \(isCombined)")
                    }
                }
                print("--- END DEBUG YouTubePlayerService for \(videoID) ---")
                
                let combinedAudioVideoStreams = allFetchedStreams.filterVideoAndAudio()
                let playableCombinedStreams = combinedAudioVideoStreams.filter { $0.isNativelyPlayable }

                var finalStreamURL: URL? = nil
                var selectedQualityDescription = "Unknown"

                if !playableCombinedStreams.isEmpty {
                    if let first720pStream = playableCombinedStreams.streams(withExactResolution: 720).first {
                        finalStreamURL = first720pStream.url
                        selectedQualityDescription = "720p (Combined A/V)"
                    } else if let first480pStream = playableCombinedStreams.streams(withExactResolution: 480).first {
                        finalStreamURL = first480pStream.url
                        selectedQualityDescription = "480p (Combined A/V)"
                    } else if let first360pStream = playableCombinedStreams.streams(withExactResolution: 360).first {
                        finalStreamURL = first360pStream.url
                        selectedQualityDescription = "360p (Combined A/V)"
                    } else if let lowestPlayableCombined = playableCombinedStreams.lowestResolutionStream() {
                        finalStreamURL = lowestPlayableCombined.url
                        selectedQualityDescription = "Lowest Playable (Combined A/V)"
                    }
                }

                if let streamToPlayURL = finalStreamURL {
                    print("YouTubePlayerService: Selected \(selectedQualityDescription) stream. URL: \(streamToPlayURL) for video ID: \(videoID)")
                    completion(.success(streamToPlayURL))
                } else {
                    print("YouTubePlayerService: Could not find a suitable HLS or combined A/V stream for video ID: \(videoID)")
                    // Check if HLS was also not found (implicitly, if foundAndReturnedHLSStream is false) 
                    // AND no other streams were fetched.
                    if !foundAndReturnedHLSStream && allFetchedStreams.isEmpty {
                         completion(.failure(.noPlayableStreamFound)) // No streams at all (neither HLS nor other types)
                    } else if !foundAndReturnedHLSStream { // HLS was not found/returned, but other streams might exist (but no suitable combined A/V)
                         completion(.failure(.noCombinedAVStreamFound))
                    } else {
                        // This case should ideally not be reached if HLS was found and returned.
                        // If HLS was found but something else went wrong before returning, it's an unknown state.
                        // Or, if HLS was found and returned, this 'else' block for finalStreamURL shouldn't be hit.
                        // For safety, defaulting to noCombinedAVStreamFound or a more generic error.
                        // Given the logic, if foundAndReturnedHLSStream is true, we shouldn't be in this 'else' block.
                        // This implies no combined AV stream was found after failing to find/return HLS.
                        completion(.failure(.noCombinedAVStreamFound))
                    }
                }
            } catch {
                print("YouTubePlayerService: YouTubeKit master error for video ID \(videoID): \(error.localizedDescription)")
                completion(.failure(.youtubeKitError(error)))
            }
        }
    }
} 