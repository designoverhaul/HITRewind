//
//  FavoritesService.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/26/25.
//

import SwiftUI
import UIKit

// MARK: - Notification Extensions
extension Notification.Name {
    static let favoriteAdded = Notification.Name("favoriteAdded")
}
#if canImport(CloudKit)
import CloudKit
#endif

// MARK: - Favorite Video Model
struct FavoriteVideo: Identifiable, Codable, Hashable {
    let id = UUID()
    let videoId: String
    let title: String
    let artist: String
    let year: String
    let dateAdded: Date
    
    init(videoId: String, title: String, artist: String, year: String) {
        self.videoId = videoId
        self.title = title
        self.artist = artist
        self.year = year
        self.dateAdded = Date()
    }
}

@MainActor
class FavoritesService: ObservableObject {
    @Published var favoriteVideos: [FavoriteVideo] = []
    @Published var isLoading = false
    @Published var syncStatus: SyncStatus = .unknown
    
    static let shared = FavoritesService()
    
    #if canImport(CloudKit)
    private lazy var container: CKContainer? = {
        guard AppConfig.useCloudKit else { return nil }
        return CKContainer.default()
    }()
    private lazy var privateDatabase: CKDatabase? = {
        guard let container = container else { return nil }
        return container.privateCloudDatabase
    }()
    #endif
    private let localStorageKey = "LocalFavorites"
    
    enum SyncStatus: Equatable {
        case unknown
        case syncing
        case synced
        case error(String)
    }
    
    private init() {
        loadLocalFavorites()
        #if canImport(CloudKit)
        if AppConfig.useCloudKit {
            checkCloudKitAvailability()
        } else {
            syncStatus = .unknown
        }
        #else
        syncStatus = .unknown
        #endif
    }
    
    // MARK: - Public Methods
    
    func toggleFavorite(videoId: String, title: String, artist: String, year: String) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        if let existingIndex = favoriteVideos.firstIndex(where: { $0.videoId == videoId }) {
            // Remove favorite
            let favoriteToRemove = favoriteVideos[existingIndex]
            favoriteVideos.remove(at: existingIndex)
            saveLocalFavorites()
            
            #if canImport(CloudKit)
            if AppConfig.useCloudKit {
                Task { await removeFromCloud(favoriteToRemove) }
            }
            #endif
            
            print("❤️ Removed favorite: \(title) by \(artist)")
        } else {
            // Add favorite
            let newFavorite = FavoriteVideo(videoId: videoId, title: title, artist: artist, year: year)
            favoriteVideos.append(newFavorite)
            favoriteVideos.sort { $0.dateAdded > $1.dateAdded } // Most recent first
            saveLocalFavorites()
            
            #if canImport(CloudKit)
            if AppConfig.useCloudKit {
                Task { await saveToCloud(newFavorite) }
            }
            #endif
            
            // Trigger heart animation in tab bar
            NotificationCenter.default.post(name: .favoriteAdded, object: nil)
            
            print("❤️ Added favorite: \(title) by \(artist)")
        }
    }
    
    func isFavorited(_ videoId: String) -> Bool {
        return favoriteVideos.contains { $0.videoId == videoId }
    }
    
    func clearAllFavorites() {
        favoriteVideos.removeAll()
        saveLocalFavorites()
        
        #if canImport(CloudKit)
        if AppConfig.useCloudKit {
            Task { await clearCloudFavorites() }
        }
        #endif
    }
    
    func syncWithCloud() {
        #if canImport(CloudKit)
        if AppConfig.useCloudKit {
            Task { await performCloudSync() }
        }
        #endif
    }
    
    // MARK: - Local Storage
    
    private func loadLocalFavorites() {
        guard let data = UserDefaults.standard.data(forKey: localStorageKey),
              let favorites = try? JSONDecoder().decode([FavoriteVideo].self, from: data) else {
            favoriteVideos = []
            return
        }
        favoriteVideos = favorites.sorted { $0.dateAdded > $1.dateAdded }
    }
    
    private func saveLocalFavorites() {
        if let data = try? JSONEncoder().encode(favoriteVideos) {
            UserDefaults.standard.set(data, forKey: localStorageKey)
        }
    }
    
    // MARK: - CloudKit Integration
    
    #if canImport(CloudKit)
    private func checkCloudKitAvailability() {
        guard let container = container else { return }
        container.accountStatus { [weak self] accountStatus, error in
            DispatchQueue.main.async {
                switch accountStatus {
                case .available:
                    if AuthenticationService.shared.isAuthenticated {
                        self?.syncStatus = .unknown
                        Task { await self?.performCloudSync() }
                    }
                case .noAccount:
                    self?.syncStatus = .error("iCloud account not found")
                case .restricted, .temporarilyUnavailable:
                    self?.syncStatus = .error("iCloud temporarily unavailable")
                case .couldNotDetermine:
                    self?.syncStatus = .unknown
                @unknown default:
                    self?.syncStatus = .error("Unknown iCloud status")
                }
            }
        }
    }
    #endif
    
    #if canImport(CloudKit)
    private func performCloudSync() async {
        guard AppConfig.useCloudKit, AuthenticationService.shared.isAuthenticated else {
            syncStatus = .error("User not authenticated")
            return
        }
        
        syncStatus = .syncing
        
        do {
            // Fetch favorites from cloud
            let cloudFavorites = await fetchFromCloud()
            
            // Merge with local favorites (cloud takes precedence for duplicates)
            let mergedFavorites = mergeCloudAndLocalFavorites(cloudFavorites: cloudFavorites)
            
            // Update local storage
            favoriteVideos = mergedFavorites.sorted { $0.dateAdded > $1.dateAdded }
            saveLocalFavorites()
            
            // Upload any local-only favorites to cloud
            await uploadLocalFavoritesToCloud()
            
            syncStatus = .synced
        } catch {
            syncStatus = .error("Sync failed: \(error.localizedDescription)")
            print("❌ CloudKit sync error: \(error)")
        }
    }
    
    private func fetchFromCloud() async -> [FavoriteVideo] {
        do {
            let query = CKQuery(recordType: "FavoriteVideo", predicate: NSPredicate(value: true))
            query.sortDescriptors = [NSSortDescriptor(key: "dateAdded", ascending: false)]
            
            guard let privateDatabase = privateDatabase else { return [] }
            let result = try await privateDatabase.records(matching: query)
            
            var cloudFavorites: [FavoriteVideo] = []
            
            for (_, result) in result.matchResults {
                switch result {
                case .success(let record):
                    if let favorite = favoriteVideoFromRecord(record) {
                        cloudFavorites.append(favorite)
                    }
                case .failure(let error):
                    print("❌ Failed to fetch record: \(error)")
                }
            }
            
            return cloudFavorites
        } catch {
            print("❌ CloudKit fetch error: \(error)")
            return []
        }
    }
    
    private func saveToCloud(_ favorite: FavoriteVideo) async {
        guard AppConfig.useCloudKit, AuthenticationService.shared.isAuthenticated else { return }
        
        do {
            let record = recordFromFavoriteVideo(favorite)
            guard let privateDatabase = privateDatabase else { return }
            try await privateDatabase.save(record)
            print("☁️ Saved to cloud: \(favorite.title)")
        } catch {
            print("❌ CloudKit save error: \(error)")
        }
    }
    
    private func removeFromCloud(_ favorite: FavoriteVideo) async {
        guard AppConfig.useCloudKit, AuthenticationService.shared.isAuthenticated else { return }
        
        do {
            // Find and delete the record
            let query = CKQuery(recordType: "FavoriteVideo", predicate: NSPredicate(format: "videoId == %@", favorite.videoId))
            guard let privateDatabase = privateDatabase else { return }
            let result = try await privateDatabase.records(matching: query)
            
            for (recordID, _) in result.matchResults {
                try await privateDatabase.deleteRecord(withID: recordID)
                print("☁️ Removed from cloud: \(favorite.title)")
            }
        } catch {
            print("❌ CloudKit delete error: \(error)")
        }
    }
    
    private func clearCloudFavorites() async {
        guard AppConfig.useCloudKit, AuthenticationService.shared.isAuthenticated else { return }
        
        do {
            let query = CKQuery(recordType: "FavoriteVideo", predicate: NSPredicate(value: true))
            guard let privateDatabase = privateDatabase else { return }
            let result = try await privateDatabase.records(matching: query)
            
            for (recordID, _) in result.matchResults {
                try await privateDatabase.deleteRecord(withID: recordID)
            }
            
            print("☁️ Cleared all favorites from cloud")
        } catch {
            print("❌ CloudKit clear error: \(error)")
        }
    }
    
    private func uploadLocalFavoritesToCloud() async {
        for favorite in favoriteVideos {
            await saveToCloud(favorite)
        }
    }
    #endif
    
    private func mergeCloudAndLocalFavorites(cloudFavorites: [FavoriteVideo]) -> [FavoriteVideo] {
        var mergedFavorites = cloudFavorites
        
        // Add local favorites that aren't in cloud
        for localFavorite in favoriteVideos {
            if !cloudFavorites.contains(where: { $0.videoId == localFavorite.videoId }) {
                mergedFavorites.append(localFavorite)
            }
        }
        
        return mergedFavorites
    }
    
    // MARK: - CloudKit Record Conversion
    
    private func recordFromFavoriteVideo(_ favorite: FavoriteVideo) -> CKRecord {
        let record = CKRecord(recordType: "FavoriteVideo")
        record["videoId"] = favorite.videoId
        record["title"] = favorite.title
        record["artist"] = favorite.artist
        record["year"] = favorite.year
        record["dateAdded"] = favorite.dateAdded
        return record
    }
    
    private func favoriteVideoFromRecord(_ record: CKRecord) -> FavoriteVideo? {
        guard let videoId = record["videoId"] as? String,
              let title = record["title"] as? String,
              let artist = record["artist"] as? String,
              let year = record["year"] as? String,
              let dateAdded = record["dateAdded"] as? Date else {
            return nil
        }
        
        return FavoriteVideo(videoId: videoId, title: title, artist: artist, year: year)
    }
}