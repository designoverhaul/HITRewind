//
//  VJModeVideoStack.swift
//  HIt Rewind2
//
//  Vertical scrolling video thumbnail stack for VJ Mode (full height)
//

import SwiftUI

/// Vertical scrolling list of video thumbnails for VJ Mode
/// Full height from top to bottom of screen
struct VJModeVideoStack: View {
    let videos: [PlaylistVideo]
    let currentVideoId: String
    let onVideoSelect: (PlaylistVideo) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 6) {
                    ForEach(videos) { video in
                        VJModeVideoThumbnail(
                            video: video,
                            rank: video.rank, // Only show rank if video has actual Billboard rank
                            isCurrentlyPlaying: video.id == currentVideoId,
                            onTap: { onVideoSelect(video) }
                        )
                        .id(video.id)
                    }
                }
                .padding(.vertical, 4)
            }
            .background(Color.black.opacity(0.3))
            .onChange(of: currentVideoId) { _, newId in
                // Scroll to current video when it changes
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(newId, anchor: .center)
                }
            }
            .onChange(of: videos.map { $0.id }) { _, _ in
                // Scroll to top (#1 video) when video list changes (e.g., year selection)
                if let firstVideo = videos.first {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(firstVideo.id, anchor: .top)
                    }
                }
            }
            .onAppear {
                // Scroll to current video on appear
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    proxy.scrollTo(currentVideoId, anchor: .center)
                }
            }
        }
    }
}

/// Compact video thumbnail for VJ Mode stack
struct VJModeVideoThumbnail: View {
    let video: PlaylistVideo
    let rank: Int? // Optional - only show badge if video has actual Billboard rank
    let isCurrentlyPlaying: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                // Thumbnail image
                ZStack {
                    AsyncImage(url: URL(string: "https://img.youtube.com/vi/\(video.id)/mqdefault.jpg")) { image in
                        image
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(height: 56)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                    // Playing indicator overlay
                    if isCurrentlyPlaying {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.hitRewindPurple, lineWidth: 2)

                        // Now playing icon
                        Image(systemName: "play.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .padding(5)
                            .background(Color.hitRewindPurple.opacity(0.9))
                            .clipShape(Circle())
                    }

                    // Rank badge (top-right corner) - only show if video has actual rank
                    if let rank = rank {
                        VStack {
                            HStack {
                                Spacer()

                                Text("#\(rank)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.hitRewindPurple)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                                    .padding(.trailing, 2)
                                    .padding(.top, 2)
                            }
                            Spacer()
                        }
                    }
                }
                .frame(height: 56)

                // Title (compact, 1 line)
                Text(video.title)
                    .font(.system(size: 11, weight: isCurrentlyPlaying ? .semibold : .regular))
                    .foregroundColor(isCurrentlyPlaying ? .white : .white.opacity(0.8))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Artist name
                Text(video.artist)
                    .font(.system(size: 11))
                    .foregroundColor(.hitRewindPurple)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isCurrentlyPlaying ? Color.hitRewindPurple.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VJModeVideoStack(
            videos: [
                PlaylistVideo(id: "video1", youtubeURL: "", title: "Video One Title", artist: "Artist A", year: "2023"),
                PlaylistVideo(id: "video2", youtubeURL: "", title: "Video Two with a Longer Title Here", artist: "Artist B", year: "2023"),
                PlaylistVideo(id: "video3", youtubeURL: "", title: "Video Three", artist: "Artist C", year: "2023"),
                PlaylistVideo(id: "video4", youtubeURL: "", title: "Video Four", artist: "Artist D", year: "2023"),
                PlaylistVideo(id: "video5", youtubeURL: "", title: "Video Five", artist: "Artist E", year: "2023"),
            ],
            currentVideoId: "video2",
            onVideoSelect: { _ in }
        )
        .frame(width: 140)
    }
}
