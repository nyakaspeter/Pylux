// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL

import UIKit

/// Drives `UIApplicationDelegate.application(_:supportedInterfaceOrientationsFor:)` so streaming can
/// match Android `userLandscape`. `requestGeometryUpdate` alone is often ignored under SwiftUI hosting controllers.
enum AppOrientationLock {
    private static func normalMask() -> UIInterfaceOrientationMask {
        var m: UIInterfaceOrientationMask = [.portrait, .landscapeLeft, .landscapeRight]
        if UIDevice.current.userInterfaceIdiom == .pad {
            m.insert(.portraitUpsideDown)
        }
        return m
    }

    static var maskForAppDelegate: UIInterfaceOrientationMask = normalMask()

    static func lockLandscapeForStream() {
        maskForAppDelegate = .landscape
        apply()
    }

    static func unlockAfterStream() {
        maskForAppDelegate = normalMask()
        apply()
    }

    private static func apply() {
        DispatchQueue.main.async {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
            guard let scene else { return }

            scene.requestGeometryUpdate(.iOS(interfaceOrientations: maskForAppDelegate)) { _ in }

            for window in scene.windows {
                var vc: UIViewController? = window.rootViewController
                while let current = vc {
                    current.setNeedsUpdateOfSupportedInterfaceOrientations()
                    vc = current.presentedViewController
                }
            }
        }
    }
}

final class PyluxAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        AppOrientationLock.maskForAppDelegate
    }

    /// Arms a one-shot `didBecomeActive` observer for the App Store review prompt. Fires once
    /// per cold launch after the foreground scene is attached; resumes are a no-op.
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        #if DEBUG
        // Debug-only helpers for App Store review prompt testing. No-ops in release.
        //   -PyluxSeedStreamTimeMs <ms>       seeds totalStreamTimeMs (iOS keychain persists across uninstall)
        //   -PyluxClearAppReviewLast 1        resets lastAppReviewPromptTotalStreamMs to 0
        let seed = UserDefaults.standard.integer(forKey: "PyluxSeedStreamTimeMs")
        if seed > 0 {
            SecureStore.shared.totalStreamTimeMs = Int64(seed)
        }
        if UserDefaults.standard.bool(forKey: "PyluxClearAppReviewLast") {
            SecureStore.shared.lastAppReviewPromptTotalStreamMs = 0
        }
        #endif
        AppReviewLauncher.shared.armOnNextActivation()
        return true
    }
}

/// One-shot bridge from `didBecomeActiveNotification` to the main-actor-isolated `AppReviewHelper`.
/// Top-level `@MainActor` class avoids capturing main-actor state from a `Sendable` closure.
@MainActor
private final class AppReviewLauncher {
    static let shared = AppReviewLauncher()

    private var armed = false
    private var token: NSObjectProtocol?

    private init() {}

    func armOnNextActivation() {
        if armed { return }
        armed = true
        token = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if let token = self.token {
                    NotificationCenter.default.removeObserver(token)
                    self.token = nil
                }
                let scene = UIApplication.shared.connectedScenes
                    .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
                AppReviewHelper.shared.requestReviewIfEligible(in: scene)
            }
        }
    }
}
