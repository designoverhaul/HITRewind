//
//  OnboardingPageView.swift
//  HIt Rewind2
//
//  Created by Hit Rewind on 11/5/25.
//

import SwiftUI

struct OnboardingPageView: View {
    let page: OnboardingPage
    @Environment(\.isPageActive) private var isPageActive

    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                switch page.pageType {
                case .textOnly(let emoji):
                    textOnlyContent(emoji: emoji)
                case .checklist(let items):
                    checklistContent(items: items)
                case .image(let name):
                    imageContent(name: name, geometry: geometry)
                case .loopingVideo(let name):
                    videoContent(name: name, geometry: geometry)
                }
            }
        }
    }

    // MARK: - Text Only (Screens 1 & 2)

    @ViewBuilder
    private func textOnlyContent(emoji: String) -> some View {
        VStack(spacing: 20) {
            Text(page.title)
                .font(.custom(AppFont.ticketingName(), size: 29))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Text(emoji)
                .font(.system(size: 72))
        }
    }

    // MARK: - Checklist (Screen 3)

    @ViewBuilder
    private func checklistContent(items: [String]) -> some View {
        VStack(spacing: 24) {
            Text(page.title)
                .font(.custom(AppFont.ticketingName(), size: 29))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(items, id: \.self) { item in
                    Text("✅ \(item)")
                        .font(.custom(AppFont.ticketingName(), size: 22))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Image (Screen 4)

    @ViewBuilder
    private func imageContent(name: String, geometry: GeometryProxy) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Text(page.title)
                .font(.custom(AppFont.ticketingName(), size: 29))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Image(name)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: isIPad ? 500 : geometry.size.width - 40)

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Looping Video (Screen 5)

    @ViewBuilder
    private func videoContent(name: String, geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Text(page.title)
                .font(.custom(AppFont.ticketingName(), size: 29))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, geometry.size.height * 0.15)

            Spacer().frame(height: 20)

            if isIPad {
                LoopingVideoPlayerView(videoName: name)
                    .frame(width: geometry.size.width * 0.6)
                    .frame(maxHeight: geometry.size.height * 0.5)
                    .clipped()
            } else {
                LoopingVideoPlayerView(videoName: name)
                    .frame(width: geometry.size.width)
                    .frame(maxHeight: geometry.size.height * 0.5)
                    .clipped()
            }

            Spacer()
        }
    }
}

#Preview {
    OnboardingPageView(page: OnboardingPage.pages[0])
        .background(Color.black)
}
