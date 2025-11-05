import SwiftUI
import StoreKit

struct ReviewRequestView: View {
    @Environment(\.requestReview) private var requestReview
    let message: String
    let onDismiss: () -> Void
    let onNextMessage: () -> Void
    @State private var isVisible = false
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            // Modal popup card
            VStack(spacing: 0) {
                // Close X button
                HStack {
                    Spacer()
                    Button(action: {
                        onDismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(Color(hex: "A789FD"))
                            .frame(width: 30, height: 30)
                    }
                }
                .padding(.top, 20)
                .padding(.trailing, 20)

                // Guitar emoji - smaller
                Text("🎸")
                    .font(.system(size: 40))
                    .padding(.top, 30)
                    .padding(.bottom, 20)
                
                // Song quote message - tappable area
                Button(action: {
                    requestReview()
                    onDismiss()
                }) {
                    VStack(spacing: 20) {
                        Text("\"\(message)\"")
                            .font(.system(.title, design: .default, weight: .medium))
                            .italic()
                            .foregroundColor(Color(hex: "A789FD"))
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .padding(.horizontal, 30)
                        
                        // Five outlined stars
                        HStack(spacing: 8) {
                            Image(systemName: "star")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "A789FD"))
                            Image(systemName: "star")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "A789FD"))
                            Image(systemName: "star")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "A789FD"))
                            Image(systemName: "star")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "A789FD"))
                            Image(systemName: "star")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "A789FD"))
                        }
                    }
                    .padding(.vertical, 20)
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()
            }
            .frame(width: 320, height: 400)
            .background(Color.black)
            .cornerRadius(20)
            .shadow(color: Color(hex: "A789FD").opacity(isVisible ? 0.4 : 0), radius: 30, x: 0, y: 0)
            .shadow(color: Color(hex: "A789FD").opacity(isVisible ? 0.2 : 0), radius: 15, x: 0, y: 0)
            .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
            .scaleEffect(isVisible ? 1.0 : 0.8)
            .opacity(isVisible ? 1.0 : 0.0)
            .animation(.easeOut(duration: 0.6), value: isVisible)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation {
                isVisible = true
            }
        }
    }
}

// MARK: - Preview
struct ReviewRequestView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ReviewRequestView(
                message: "Tell me something good",
                onDismiss: {},
                onNextMessage: {}
            )
            .previewDisplayName("Short Quote")
            
            ReviewRequestView(
                message: "One good thing about music, when it hits you, you feel no pain.",
                onDismiss: {},
                onNextMessage: {}
            )
            .previewDisplayName("Long Quote")
        }
    }
}