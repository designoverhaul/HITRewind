//
//  ScreenShareTutorialView.swift
//  HIt Rewind2
//
//  First-time tutorial for VJ Mode screen sharing
//

import SwiftUI

struct ScreenShareTutorialView: View {
    @Binding var isPresented: Bool
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            // Swipe instruction image - top right corner
            VStack {
                HStack {
                    Spacer()
                    Image("Swipe")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120)
                }
                Spacer()
            }
            .padding(.top, 8)
            .padding(.trailing, 8)

            VStack(spacing: 16) {
                Spacer()

                // Screen share image - larger size
                Image("screenshare")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 450)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.5), radius: 20)

                // Instructional text with inline icon
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Text("Press Screen-share")
                            .font(.custom(AppFont.ticketingName(), size: 20))
                            .foregroundColor(.white)

                        Image(systemName: "rectangle.on.rectangle")
                            .font(.system(size: 18))
                            .foregroundColor(Color.hitRewindPurple)

                        Text("from your")
                            .font(.custom(AppFont.ticketingName(), size: 20))
                            .foregroundColor(.white)
                    }

                    Text("control panel to share on your TV")
                        .font(.custom(AppFont.ticketingName(), size: 20))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }

                Spacer()
                    .frame(maxHeight: 20)

                // Got it button
                Button(action: {
                    // Mark as seen
                    UserDefaults.standard.set(true, forKey: "hasSeenScreenShareTutorial")
                    isPresented = false
                    onDismiss()
                }) {
                    Text("GOT IT")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .tracking(2)
                        .frame(maxWidth: 200)
                        .padding(.vertical, 14)
                        .background(Color.hitRewindPurple)
                        .cornerRadius(25)
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
        }
        .onTapGesture {
            // Allow tap anywhere to dismiss
            UserDefaults.standard.set(true, forKey: "hasSeenScreenShareTutorial")
            isPresented = false
            onDismiss()
        }
    }

    // Check if user has seen the tutorial
    static var hasSeenTutorial: Bool {
        UserDefaults.standard.bool(forKey: "hasSeenScreenShareTutorial")
    }
}

#Preview {
    ScreenShareTutorialView(isPresented: .constant(true), onDismiss: {})
}
