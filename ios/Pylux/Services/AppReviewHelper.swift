// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
//
// iOS App Store review prompt. Dispatches `SKStoreReviewController.requestReview(in:)` once
// per cold launch, gated by cumulative stream time (10 min first, +60 min between prompts).

import Foundation
import os.log
import StoreKit
import UIKit

private let reviewLog = OSLog(subsystem: "com.pylux.stream", category: "AppReview")

@MainActor
final class AppReviewHelper {
    static let shared = AppReviewHelper()

    private static let minFirstStreamMs: Int64 = 10 * 60 * 1000          // 10 min
    private static let betweenPromptsStreamMs: Int64 = 60 * 60 * 1000    // 60 min

    private var requestedThisLaunch = false

    private init() {}

    /// Call once per cold launch from `PyluxAppDelegate.application(_:didFinishLaunchingWithOptions:)`.
    func requestReviewIfEligible(in scene: UIWindowScene?) {
        if requestedThisLaunch { return }

        let total = SecureStore.shared.totalStreamTimeMs
        let last = SecureStore.shared.lastAppReviewPromptTotalStreamMs
        let needed = (last == 0) ? Self.minFirstStreamMs : (last + Self.betweenPromptsStreamMs)
        let donationActive = DonationPromptCoordinator.shared.showPaywall
        let hasScene = scene != nil
        os_log(.info, log: reviewLog,
               "App review: eligibility check (total=%lld last=%lld needed=%lld donationActive=%{BOOL}d hasScene=%{BOOL}d)",
               total, last, needed, donationActive, hasScene)

        if total < needed { return }
        if donationActive { return }
        guard let windowScene = scene else { return }

        requestedThisLaunch = true
        os_log(.info, log: reviewLog, "App review: requested (system may not display)")

        if #available(iOS 14, *) {
            SKStoreReviewController.requestReview(in: windowScene)
        }

        // Persist *after* the bridge call; +60 min throttle still bounds re-prompts if it threw.
        SecureStore.shared.lastAppReviewPromptTotalStreamMs = total
    }
}
