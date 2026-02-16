//
//  FavoritesService.swift
//  HIt Rewind2
//
//  Firestore-based favorites with automatic real-time sync
//  (Migrated from CloudKit)
//

import SwiftUI
import UIKit
import StoreKit
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

// MARK: - Notification Extensions
extension Notification.Name {
    static let favoriteAdded = Notification.Name("favoriteAdded")
    static let authenticationStateChanged = Notification.Name("authenticationStateChanged")
}

// MARK: - Favorite Video Model
struct FavoriteVideo: Identifiable, Codable, Hashable {
    var id: String
    let videoId: String
    let title: String
    let artist: String
    let year: String
    let dateAdded: Date

    init(videoId: String, title: String, artist: String, year: String) {
        self.id = videoId
        self.videoId = videoId
        self.title = title
        self.artist = artist
        self.year = year
        self.dateAdded = Date()
    }

    init(id: String, videoId: String, title: String, artist: String, year: String, dateAdded: Date) {
        self.id = id
        self.videoId = videoId
        self.title = title
        self.artist = artist
        self.year = year
        self.dateAdded = dateAdded
    }
}

@MainActor
class FavoritesService: ObservableObject {
    @Published var favoriteVideos: [FavoriteVideo] = []
    @Published var isLoading = false
    @Published var syncStatus: SyncStatus = .unknown

    static let shared = FavoritesService()

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var authStateListener: AuthStateDidChangeListenerHandle?

    // Review request tracking
    private let favoritesAddedKey = "favorites_added_count"
    private let lastReviewRequestKey = "last_review_request_date"
    private let hasRequestedReviewKey = "has_requested_review"
    private let launchCountKey = "app_launch_count"

    enum SyncStatus: Equatable {
        case unknown       // Initial state
        case syncing       // Setting up listener
        case synced        // Real-time listener active
        case offline       // Offline but has cached data
        case error(String)
    }

    private init() {
        setupAuthStateListener()
    }

    // MARK: - Review Request Logic

    /// Check if we should request a review after adding a favorite
    /// Conditions: 2+ favorites added, 3+ launches, 60+ days since last prompt
    private func checkAndRequestReview() {
        let userDefaults = UserDefaults.standard

        // Increment favorites added count
        let currentFavoritesAdded = userDefaults.integer(forKey: favoritesAddedKey)
        userDefaults.set(currentFavoritesAdded + 1, forKey: favoritesAddedKey)
        let favoritesAdded = currentFavoritesAdded + 1

        let launchCount = userDefaults.integer(forKey: launchCountKey)
        let hasRequestedBefore = userDefaults.bool(forKey: hasRequestedReviewKey)

        // Must have added at least 2 favorites and launched app 3+ times
        guard favoritesAdded >= 2 && launchCount >= 3 else {
            print("📝 Review: Not enough engagement yet (favorites: \(favoritesAdded), launches: \(launchCount))")
            return
        }

        // Check time since last request (60 days minimum)
        if hasRequestedBefore {
            if let lastRequestDate = userDefaults.object(forKey: lastReviewRequestKey) as? Date {
                let daysSinceLastRequest = Calendar.current.dateComponents([.day], from: lastRequestDate, to: Date()).day ?? 0
                guard daysSinceLastRequest >= 60 else {
                    print("📝 Review: Too soon since last request (\(daysSinceLastRequest) days)")
                    return
                }
            }
        }

        // All conditions met - request review after a brief delay
        print("📝 Review: Conditions met! Requesting review...")
        userDefaults.set(true, forKey: hasRequestedReviewKey)
        userDefaults.set(Date(), forKey: lastReviewRequestKey)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
            }
        }
    }

    deinit {
        listener?.remove()
        if let handle = authStateListener {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Auth State Listener

    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user = user {
                    print("User signed in, setting up favorites listener for: \(user.uid)")
                    self?.setupFavoritesListener(for: user.uid)
                } else {
                    print("User signed out, removing favorites listener")
                    self?.removeListener()
                    self?.favoriteVideos = []
                    self?.syncStatus = .unknown
                }
            }
        }
    }

    // MARK: - Real-time Listener (Automatic Sync)

    private func setupFavoritesListener(for userId: String) {
        listener?.remove()

        syncStatus = .syncing
        isLoading = true

        let favoritesRef = db.collection("users").document(userId).collection("favorites")

        listener = favoritesRef
            .order(by: "dateAdded", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    self?.isLoading = false

                    if let error = error {
                        print("Firestore listener error: \(error.localizedDescription)")
                        self?.syncStatus = .error(error.localizedDescription)
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        print("No favorites documents found")
                        self?.favoriteVideos = []
                        self?.syncStatus = .synced
                        return
                    }

                    // Check if data is from cache (offline)
                    if snapshot?.metadata.isFromCache == true {
                        self?.syncStatus = .offline
                    } else {
                        self?.syncStatus = .synced
                    }

                    // Parse documents into FavoriteVideo objects
                    let favorites = documents.compactMap { doc -> FavoriteVideo? in
                        let data = doc.data()
                        guard let videoId = data["videoId"] as? String,
                              let title = data["title"] as? String,
                              let artist = data["artist"] as? String,
                              let year = data["year"] as? String,
                              let timestamp = data["dateAdded"] as? Timestamp else {
                            return nil
                        }
                        return FavoriteVideo(
                            id: doc.documentID,
                            videoId: videoId,
                            title: title,
                            artist: artist,
                            year: year,
                            dateAdded: timestamp.dateValue()
                        )
                    }

                    self?.favoriteVideos = favorites
                    print("Favorites updated: \(favorites.count) items")
                }
            }
    }

    private func removeListener() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Public Methods

    func toggleFavorite(videoId: String, title: String, artist: String, year: String) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("Cannot toggle favorite - user not signed in")
            return
        }

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        let favoritesRef = db.collection("users").document(userId).collection("favorites")
        let documentRef = favoritesRef.document(videoId)

        if isFavorited(videoId) {
            // OPTIMISTIC UPDATE: Remove from local array immediately
            if let index = favoriteVideos.firstIndex(where: { $0.videoId == videoId }) {
                let removedFavorite = favoriteVideos.remove(at: index)
                print("Optimistically removed favorite: \(title)")

                // Then sync to Firestore
                documentRef.delete { [weak self] error in
                    if let error = error {
                        print("Error removing favorite: \(error.localizedDescription)")
                        // Rollback on error - add it back
                        Task { @MainActor in
                            self?.favoriteVideos.append(removedFavorite)
                            self?.favoriteVideos.sort { $0.dateAdded > $1.dateAdded }
                        }
                    } else {
                        print("Removed favorite from Firestore: \(title)")
                    }
                }
            }
        } else {
            // OPTIMISTIC UPDATE: Add to local array immediately
            let newFavorite = FavoriteVideo(videoId: videoId, title: title, artist: artist, year: year)
            favoriteVideos.insert(newFavorite, at: 0) // Add at beginning (most recent)
            print("Optimistically added favorite: \(title)")
            NotificationCenter.default.post(name: .favoriteAdded, object: nil)

            // Then sync to Firestore
            let data: [String: Any] = [
                "videoId": videoId,
                "title": title,
                "artist": artist,
                "year": year,
                "dateAdded": Timestamp(date: Date())
            ]

            documentRef.setData(data) { [weak self] error in
                if let error = error {
                    print("Error adding favorite: \(error.localizedDescription)")
                    // Rollback on error - remove it
                    Task { @MainActor in
                        self?.favoriteVideos.removeAll { $0.videoId == videoId }
                    }
                } else {
                    print("Added favorite to Firestore: \(title)")
                    // Check if we should request a review after this positive action
                    Task { @MainActor in
                        self?.checkAndRequestReview()
                    }
                }
            }
        }
    }

    func isFavorited(_ videoId: String) -> Bool {
        return favoriteVideos.contains { $0.videoId == videoId }
    }

    func clearAllFavorites() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let favoritesRef = db.collection("users").document(userId).collection("favorites")

        favoritesRef.getDocuments { snapshot, error in
            if let error = error {
                print("Error getting favorites for deletion: \(error.localizedDescription)")
                return
            }

            let batch = self.db.batch()
            snapshot?.documents.forEach { doc in
                batch.deleteDocument(doc.reference)
            }

            batch.commit { error in
                if let error = error {
                    print("Error clearing favorites: \(error.localizedDescription)")
                } else {
                    print("All favorites cleared")
                }
            }
        }
    }

    // MARK: - Sync Method (kept for API compatibility, but no-op since sync is automatic)

    func syncWithCloud() {
        // No-op - Firestore real-time listener handles sync automatically
        print("Sync requested - Firestore listener handles this automatically")
    }
}
