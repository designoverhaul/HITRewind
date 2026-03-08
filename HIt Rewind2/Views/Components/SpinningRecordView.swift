//
//  SpinningRecordView.swift
//  HIt Rewind2
//

import SwiftUI

struct SpinningRecordView: View {
    @State private var rotation: Double = 0
    var size: CGFloat = 40

    var body: some View {
        Image("record")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .rotationEffect(.degrees(rotation), anchor: .center)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}
