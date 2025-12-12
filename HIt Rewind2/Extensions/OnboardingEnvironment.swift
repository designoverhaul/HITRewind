//
//  OnboardingEnvironment.swift
//  HIt Rewind2
//
//  Created by Hit Rewind on 11/5/25.
//

import SwiftUI

// Environment key for onboarding restart binding
private struct OnboardingRestartKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(true)
}

// Environment key for tracking if the onboarding page is currently active/visible
private struct IsPageActiveKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    var onboardingRestart: Binding<Bool> {
        get { self[OnboardingRestartKey.self] }
        set { self[OnboardingRestartKey.self] = newValue }
    }

    var isPageActive: Bool {
        get { self[IsPageActiveKey.self] }
        set { self[IsPageActiveKey.self] = newValue }
    }
}
