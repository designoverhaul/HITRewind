//
//  ArtistSidebarView.swift
//  HIt Rewind2
//
//  Created by Aaron Heine on 8/26/25.
//

import SwiftUI

struct ArtistSidebarView: View {
    let artists: [Playlist]
    @Binding var selectedArtist: Playlist?
    let onArtistSelected: (Playlist) -> Void
    let onBackToCategories: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Back to Categories button
            Button(action: onBackToCategories) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                    Text("Categories")
                        .font(.system(size: 16, weight: .medium))
                    Spacer()
                }
                .foregroundColor(.hitRewindPurple)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(PlainButtonStyle())
            
            Divider()
                .background(Color.hitRewindPurple.opacity(0.3))
            
            // Artists list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(artists) { artist in
                        ArtistRowView(
                            artist: artist,
                            isSelected: selectedArtist?.id == artist.id
                        ) {
                            onArtistSelected(artist)
                        }
                    }
                }
                .padding(.leading, 8)
                .padding(.trailing, 16)
                .padding(.vertical, 8)
            }
        }
        .background(Color.hitRewindBackground)
    }
}

struct ArtistRowView: View {
    let artist: Playlist
    let isSelected: Bool
    let onTap: () -> Void
    
    private var videoCount: Int {
        return artist.fields.isVisible.filter { $0 == true }.count
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(artist.fields.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.hitRewindPrimaryText)
                        .multilineTextAlignment(.leading)
                    
                    if videoCount > 0 {
                        Text("\(videoCount) video\(videoCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.hitRewindSecondaryText)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.hitRewindPurple)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.hitRewindPurple.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        ArtistSidebarView(
            artists: [],
            selectedArtist: .constant(nil),
            onArtistSelected: { artist in
                print("Selected: \(artist.fields.title)")
            },
            onBackToCategories: {
                print("Back to categories")
            }
        )
        .navigationTitle("Artists")
    }
    .preferredColorScheme(.dark)
}