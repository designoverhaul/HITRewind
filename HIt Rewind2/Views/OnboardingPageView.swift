//
//  OnboardingPageView.swift
//  HIt Rewind2
//
//  Created by Hit Rewind on 11/5/25.
//

import SwiftUI

struct OnboardingPageView: View {
    let page: OnboardingPage
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Featured Image/Carousel/GIF
                if page.useCarousel {
                    // TV Carousel for first page
                    TVCarouselView()
                        .frame(height: geometry.size.height * 0.55)
                } else if let gifName = page.gifName {
                    // GIF content - full width edge-to-edge
                    AnimatedGIFView(gifName: gifName, contentMode: .fill)
                        .frame(width: geometry.size.width)
                        .frame(height: geometry.size.height * 0.55)
                        .clipped()
                } else if isIPad {
                    // iPad: padded image
                    Image(page.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 600)
                        .frame(height: geometry.size.height * 0.55)
                        .clipped()
                } else {
                    // iPhone: full width edge-to-edge
                    Image(page.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width)
                        .frame(height: geometry.size.height * 0.55)
                        .clipped()
                }

                Spacer()
                    .frame(height: 40)

                // Title
                Text(page.title)
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                // Subtitle (if present)
                if !page.subtitle.isEmpty {
                    Text(page.subtitle)
                        .font(.system(size: 28, weight: .semibold, design: .default))
                        .foregroundColor(Color.hitRewindPurple)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.top, 8)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    OnboardingPageView(page: OnboardingPage.pages[0])
        .background(Color.black)
}
