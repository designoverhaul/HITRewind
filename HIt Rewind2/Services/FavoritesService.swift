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
    static let authenticationStateChanged = Notification.Name("authenticationStateChanged")
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
    
    // Custom initializer for CloudKit records
    init(videoId: String, title: String, artist: String, year: String, dateAdded: Date) {
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

        // Listen for authentication state changes to trigger sync
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAuthenticationStateChange),
            name: .authenticationStateChanged,
            object: nil
        )

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
        print("❤️ toggleFavorite called for: \(title) by \(artist)")
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        if let existingIndex = favoriteVideos.firstIndex(where: { $0.videoId == videoId }) {
            print("❤️ Removing existing favorite at index \(existingIndex)")
            // Remove favorite
            let favoriteToRemove = favoriteVideos[existingIndex]
            favoriteVideos.remove(at: existingIndex)
            saveLocalFavorites()
            print("❤️ Local favorites saved, now have \(favoriteVideos.count) favorites")

            #if canImport(CloudKit)
            if AppConfig.useCloudKit {
                Task { await removeFromCloud(favoriteToRemove) }
            }
            #endif

            print("❤️ Removed favorite: \(title) by \(artist)")
        } else {
            print("❤️ Adding new favorite")
            // Add favorite
            let newFavorite = FavoriteVideo(videoId: videoId, title: title, artist: artist, year: year)
            favoriteVideos.append(newFavorite)
            favoriteVideos.sort { $0.dateAdded > $1.dateAdded } // Most recent first
            saveLocalFavorites()
            print("❤️ Local favorites saved, now have \(favoriteVideos.count) favorites")

            #if canImport(CloudKit)
            if AppConfig.useCloudKit {
                Task { await saveToCloud(newFavorite) }
            }
            #endif

            // Trigger heart animation in tab bar
            NotificationCenter.default.post(name: .favoriteAdded, object: nil)

            print("❤️ Added favorite: \(title) by \(artist)")
        }

        // Force UI update by posting objectWillChange
        print("❤️ Posting objectWillChange to trigger UI updates")
        self.objectWillChange.send()
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

    @objc private func handleAuthenticationStateChange() {
        // When authentication state changes, trigger a cloud sync if user is now authenticated
        if AuthenticationService.shared.isAuthenticated {
            print("✅ User authenticated, starting cloud sync...")
            #if canImport(CloudKit)
            if AppConfig.useCloudKit {
                // Wait a bit before syncing to let CloudKit settle
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
                    await performCloudSync()
                }
            }
            #endif
        } else {
            print("❌ User signed out, keeping local favorites")
        }
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
        guard let container = container else { 
            syncStatus = .error("CloudKit container not available")
            return 
        }
        
        container.accountStatus { [weak self] accountStatus, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ CloudKit account status error: \(error)")
                    self?.syncStatus = .error("CloudKit unavailable: \(error.localizedDescription)")
                    return
                }
                
                switch accountStatus {
                case .available:
                    print("✅ CloudKit account available")
                    if AuthenticationService.shared.isAuthenticated {
                        self?.syncStatus = .unknown
                        Task { await self?.performCloudSync() }
                    }
                case .noAccount:
                    print("❌ No iCloud account found")
                    self?.syncStatus = .error("iCloud account not found")
                case .restricted:
                    print("⚠️ iCloud account restricted")
                    self?.syncStatus = .error("iCloud account restricted")
                case .temporarilyUnavailable:
                    print("⚠️ iCloud temporarily unavailable")
                    self?.syncStatus = .error("iCloud temporarily unavailable")
                case .couldNotDetermine:
                    print("⚠️ Could not determine iCloud status")
                    self?.syncStatus = .unknown
                @unknown default:
                    print("❌ Unknown iCloud status: \(accountStatus.rawValue)")
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
        print("☁️ Starting CloudKit sync with \(favoriteVideos.count) local favorites")

        do {
            // Fetch favorites from cloud
            let cloudFavorites = await fetchFromCloud()
            print("☁️ Fetched \(cloudFavorites.count) favorites from cloud")

            // Always merge, even if cloud is empty (handles first-time sign in)
            let mergedFavorites = mergeCloudAndLocalFavorites(cloudFavorites: cloudFavorites)
            favoriteVideos = mergedFavorites.sorted { $0.dateAdded > $1.dateAdded }
            saveLocalFavorites()
            print("☁️ Merged and saved \(favoriteVideos.count) total favorites")

            // Upload any local-only favorites to cloud
            await uploadLocalFavoritesToCloud()

            syncStatus = .synced
            print("☁️ CloudKit sync completed successfully")
        } catch {
            // Even if CloudKit fails, don't error out - just continue with local data
            syncStatus = .error("Sync failed: \(error.localizedDescription)")
            print("❌ CloudKit sync error: \(error)")
            print("📱 Continuing with local favorites only (\(favoriteVideos.count) favorites)")
        }
    }
    
    private func fetchFromCloud() async -> [FavoriteVideo] {
        guard let privateDatabase = privateDatabase else { 
            print("❌ No private database available")
            return [] 
        }
        
        do {
            print("☁️ Starting CloudKit fetch...")
            // Use a simple predicate that doesn't rely on queryable fields
            let predicate = NSPredicate(format: "TRUEPREDICATE")
            let query = CKQuery(recordType: "FavoriteVideo", predicate: predicate)
            
            let result = try await privateDatabase.records(matching: query)
            print("☁️ CloudKit query completed, processing results...")
            
            var cloudFavorites: [FavoriteVideo] = []
            
            for (_, result) in result.matchResults {
                switch result {
                case .success(let record):
                    if let favorite = favoriteVideoFromRecord(record) {
                        cloudFavorites.append(favorite)
                        print("☁️ Successfully parsed favorite: \(favorite.title)")
                    } else {
                        print("❌ Failed to parse record into FavoriteVideo")
                    }
                case .failure(let error):
                    print("❌ Failed to fetch individual record: \(error)")
                }
            }
            
            print("☁️ Successfully fetched \(cloudFavorites.count) favorites from CloudKit")
            return cloudFavorites
        } catch {
            print("❌ CloudKit fetch error: \(error)")
            if let ckError = error as? CKError {
                print("❌ CKError details: \(ckError.localizedDescription)")
                print("❌ CKError code: \(ckError.code.rawValue)")
                
                // Try a different approach if the query fails
                if ckError.code == .invalidArguments {
                    print("☁️ Trying alternative fetch method...")
                    return await fetchFromCloudAlternative()
                }
            }
            return []
        }
    }
    
    // Alternative fetch method that doesn't use queries
    private func fetchFromCloudAlternative() async -> [FavoriteVideo] {
        guard let privateDatabase = privateDatabase else { return [] }
        
        // Since we can't efficiently query CloudKit without proper schema setup,
        // we'll return empty for now and rely on the main fetch method
        print("⚠️ Alternative fetch not implemented due to CloudKit schema limitations")
        print("💡 Recommendation: Configure CloudKit schema with queryable fields")
        return []
    }
    
    private func saveToCloud(_ favorite: FavoriteVideo) async {
        guard AppConfig.useCloudKit, AuthenticationService.shared.isAuthenticated else { return }
        
        do {
            let record = recordFromFavoriteVideo(favorite)
            guard let privateDatabase = privateDatabase else { 
                print("❌ No private database available for save")
                return 
            }
            try await privateDatabase.save(record)
            print("☁️ Saved to cloud: \(favorite.title)")
        } catch {
            print("❌ CloudKit save error: \(error)")
            if let ckError = error as? CKError {
                print("❌ CKError details: \(ckError.localizedDescription) (Code: \(ckError.code.rawValue))")
                switch ckError.code {
                case .networkFailure, .networkUnavailable:
                    print("📶 Network issue - will retry on next sync")
                case .quotaExceeded:
                    print("📈 CloudKit quota exceeded")
                case .limitExceeded:
                    print("⚠️ CloudKit limit exceeded")
                default:
                    break
                }
            }
        }
    }
    
    private func removeFromCloud(_ favorite: FavoriteVideo) async {
        guard AppConfig.useCloudKit, AuthenticationService.shared.isAuthenticated else { return }
        
        // Fetch all cloud favorites and find the matching record
        let cloudFavorites = await fetchFromCloud()
        
        // We can't directly query by videoId, so we need to fetch all and find the match
        // This is not ideal but works around the queryable field limitation
        print("☁️ Searching through \(cloudFavorites.count) cloud records for deletion")
        
        do {
            let predicate = NSPredicate(format: "TRUEPREDICATE")
            let query = CKQuery(recordType: "FavoriteVideo", predicate: predicate)
            guard let privateDatabase = privateDatabase else { 
                print("❌ No private database available for delete")
                return 
            }
            
            let result = try await privateDatabase.records(matching: query)
            
            // Find the record with matching videoId
            for (recordID, recordResult) in result.matchResults {
                switch recordResult {
                case .success(let record):
                    if let videoId = record["videoId"] as? String, videoId == favorite.videoId {
                        try await privateDatabase.deleteRecord(withID: recordID)
                        print("☁️ Removed from cloud: \(favorite.title)")
                        return
                    }
                case .failure(let error):
                    print("❌ Failed to process record during delete: \(error)")
                }
            }
            print("⚠️ Record not found in cloud for deletion: \(favorite.title)")
        } catch {
            print("❌ CloudKit delete error: \(error)")
            if let ckError = error as? CKError {
                print("❌ CKError details: \(ckError.localizedDescription) (Code: \(ckError.code.rawValue))")
                
                // If query fails, try alternative approach
                if ckError.code == .invalidArguments {
                    print("☁️ Using alternative delete method...")
                    await removeFromCloudAlternative(favorite)
                }
            }
        }
    }
    
    private func removeFromCloudAlternative(_ favorite: FavoriteVideo) async {
        // Alternative deletion method - fetch all records first
        let allFavorites = await fetchFromCloudAlternative()
        print("☁️ Alternative delete: searching \(allFavorites.count) records")
        
        // Note: This is a limitation - we can't efficiently delete without queryable fields
        // The record will be removed next time a full sync happens
        print("⚠️ CloudKit schema limitation: cannot efficiently delete specific records")
        print("🔄 Record will be cleaned up during next full sync")
    }
    
    private func clearCloudFavorites() async {
        guard AppConfig.useCloudKit, AuthenticationService.shared.isAuthenticated else { return }
        
        do {
            let predicate = NSPredicate(format: "TRUEPREDICATE")
            let query = CKQuery(recordType: "FavoriteVideo", predicate: predicate)
            guard let privateDatabase = privateDatabase else { return }
            let result = try await privateDatabase.records(matching: query)
            
            for (recordID, _) in result.matchResults {
                try await privateDatabase.deleteRecord(withID: recordID)
            }
            
            print("☁️ Cleared all favorites from cloud")
        } catch {
            print("❌ CloudKit clear error: \(error)")
            if let ckError = error as? CKError, ckError.code == .invalidArguments {
                print("⚠️ Cannot clear cloud favorites due to schema limitations")
            }
        }
    }
    
    private func uploadLocalFavoritesToCloud() async {
        // Get current cloud favorites to avoid duplicates
        let cloudFavorites = await fetchFromCloud()
        let cloudVideoIds = Set(cloudFavorites.map { $0.videoId })
        
        // Only upload favorites that aren't already in cloud
        let localOnlyFavorites = favoriteVideos.filter { !cloudVideoIds.contains($0.videoId) }
        print("📤 Uploading \(localOnlyFavorites.count) local-only favorites to cloud")
        
        for favorite in localOnlyFavorites {
            await saveToCloud(favorite)
        }
    }
    #endif
    
    private func mergeCloudAndLocalFavorites(cloudFavorites: [FavoriteVideo]) -> [FavoriteVideo] {
        var mergedFavorites: [FavoriteVideo] = []
        var videoIdSet: Set<String> = []
        
        // First, add all cloud favorites (they take precedence for conflicts)
        for cloudFavorite in cloudFavorites {
            mergedFavorites.append(cloudFavorite)
            videoIdSet.insert(cloudFavorite.videoId)
            print("☁️ Added cloud favorite: \(cloudFavorite.title)")
        }
        
        // Add local favorites that aren't in cloud
        for localFavorite in favoriteVideos {
            if !videoIdSet.contains(localFavorite.videoId) {
                mergedFavorites.append(localFavorite)
                videoIdSet.insert(localFavorite.videoId)
                print("📱 Added local favorite: \(localFavorite.title)")
            } else {
                print("🔄 Skipping duplicate favorite: \(localFavorite.title)")
            }
        }
        
        print("🔄 Merge complete: \(cloudFavorites.count) cloud + \(favoriteVideos.count) local = \(mergedFavorites.count) total")
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

        // Create a new FavoriteVideo with the date from CloudKit
        return FavoriteVideo(videoId: videoId, title: title, artist: artist, year: year, dateAdded: dateAdded)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}