//
//  OnboardingPageView.swift
//  HIt Rewind2
//
//  Created by Hit Rewind on 11/5/25.
//

import SwiftUI

extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    // Helper to build text with inline SF Symbols using Text concatenation for proper flow
    private func textWithIcons(_ text: String, fontSize: CGFloat, color: Color) -> Text {
        let iconMappings: [String: String] = [
            "{{screenShare}}": "rectangle.on.rectangle",
            "{{airplay}}": "airplayvideo"
        ]

        var result = Text("")
        var remaining = text

        while !remaining.isEmpty {
            var foundIcon = false

            for (placeholder, sfSymbol) in iconMappings {
                if let range = remaining.range(of: placeholder) {
                    // Add text before the icon
                    let before = String(remaining[..<range.lowerBound])
                    if !before.isEmpty {
                        result = result + Text(before)
                            .font(.custom(AppFont.ticketingName(), size: fontSize))
                            .foregroundColor(color)
                    }
                    // Add the icon inline
                    result = result + Text(Image(systemName: sfSymbol))
                        .font(.system(size: fontSize * 0.9))
                        .foregroundColor(color)
                    // Continue with remaining text
                    remaining = String(remaining[range.upperBound...])
                    foundIcon = true
                    break
                }
            }

            if !foundIcon {
                result = result + Text(remaining)
                    .font(.custom(AppFont.ticketingName(), size: fontSize))
                    .foregroundColor(color)
                remaining = ""
            }
        }

        return result
    }

    private func hasIcons(_ text: String) -> Bool {
        text.contains("{{")
    }

    var body: some View {
        GeometryReader { geometry in
            if page.useGIFCarousel {
                // Looping Video with fixed title positioning
                ZStack(alignment: .top) {
                    Color.black.ignoresSafeArea()

                    VStack(spacing: 0) {
                        // Looping Video - responsive sizing based on device
                        if isIPad {
                            // iPad: constrained to 60% width, centered
                            LoopingVideoPlayerView(videoName: "songs")
                                .frame(width: geometry.size.width * 0.6)
                                .frame(height: geometry.size.height * 0.55)
                                .frame(maxWidth: .infinity)
                                .clipped()
                        } else {
                            // iPhone: edge-to-edge (video has built-in padding)
                            LoopingVideoPlayerView(videoName: "songs")
                                .frame(width: geometry.size.width)
                                .frame(height: geometry.size.height * 0.55)
                                .clipped()
                        }

                        Spacer()
                    }

                    // Title positioned at fixed distance from bottom
                    VStack {
                        Spacer()

                        VStack(spacing: 8) {
                            Text(page.title)
                                .font(.custom(AppFont.ticketingName(), size: 24))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)

                            if !page.subtitle.isEmpty {
                                Text(page.subtitle)
                                    .font(.custom(AppFont.ticketingName(), size: 24))
                                    .foregroundColor(Color.hitRewindPurple)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(4)
                            }
                        }
                        .padding(.bottom, geometry.size.height * 0.25) // Fixed position from bottom
                    }
                }
                .onAppear {
                    print("📄 OnboardingPageView - useGIFCarousel (now video): true")
                    print("  → Using Looping Video: songs.m4v")
                }
            } else {
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
                    if page.imageName == "Onboarding4" || page.imageName == "Onboarding4.5" || page.imageName == "onboarding5" {
                        Image(page.imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 600)
                            .padding(.top, 60)
                    } else {
                        Image(page.imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 600)
                            .frame(height: geometry.size.height * 0.55)
                            .clipped()
                    }
                } else {
                    // iPhone: full width edge-to-edge
                    if page.imageName == "Onboarding4" || page.imageName == "Onboarding4.5" || page.imageName == "onboarding5" {
                        Image(page.imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geometry.size.width)
                            .padding(.top, 60)
                    } else {
                        Image(page.imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width)
                            .frame(height: geometry.size.height * 0.55)
                            .clipped()
                    }
                }

                // Conditional spacing based on page
                if page.imageName == "Onboarding4" || page.imageName == "Onboarding4.5" || page.imageName == "onboarding5" {
                    // No spacing for Onboarding4/4.5/5 - title touches image
                    EmptyView()
                } else {
                    Spacer()
                        .frame(height: 40)
                }

                // Title
                if hasIcons(page.title) {
                    textWithIcons(page.title, fontSize: 24, color: .white)
                        .multilineTextAlignment(.center)
                } else {
                    Text(page.title)
                        .font(.custom(AppFont.ticketingName(), size: 24))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                // Subtitle (if present)
                if !page.subtitle.isEmpty {
                    if page.imageName == "onboarding2" {
                        // Special handling for onboarding2 with larger emoji
                        VStack(spacing: 8) {
                            Text("But Netflix stole the screen")
                                .font(.custom(AppFont.ticketingName(), size: 24))
                                .foregroundColor(Color.hitRewindPurple)
                                .multilineTextAlignment(.center)
                            Text("😢")
                                .font(.system(size: 42))
                        }
                        .padding(.top, 8)
                    } else if hasIcons(page.subtitle) {
                        textWithIcons(page.subtitle, fontSize: 24, color: Color.hitRewindPurple)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                    } else {
                        Text(page.subtitle)
                            .font(.custom(AppFont.ticketingName(), size: 24))
                            .foregroundColor(Color.hitRewindPurple)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.top, 8)
                    }
                }

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    print("📄 OnboardingPageView - imageName: \(page.imageName), gifName: \(page.gifName ?? "nil"), useCarousel: \(page.useCarousel), useGIFCarousel: \(page.useGIFCarousel)")
                    if page.useGIFCarousel {
                        print("  → Using GIF Carousel")
                    } else if page.useCarousel {
                        print("  → Using TV Carousel")
                    } else if let gifName = page.gifName {
                        print("  → Using GIF: \(gifName)")
                    } else {
                        print("  → Using Image: \(page.imageName)")
                    }
                }
            }
        }
    }
}

#Preview {
    OnboardingPageView(page: OnboardingPage.pages[0])
        .background(Color.black)
}
