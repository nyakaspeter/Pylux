// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Cloud gaming models matching Android's cloudplay/model/ package exactly

import Foundation
import os

// MARK: - CloudGame (matches Android CloudGame.kt)

/// Represents a game in the cloud catalog (PSNow or PSCloud)
struct CloudGame: Identifiable, Hashable {
    let id: String           // catalog productId (PSCloud) or product id (PSNOW)
    let name: String
    let imageUrl: String     // Cover/box art (type 10)
    let landscapeImageUrl: String  // Landscape (type 12/13)
    let platform: String     // "ps4", "ps3", or "ps5"
    let serviceType: String  // "psnow" or "pscloud"
    let conceptUrl: String   // URL to add game to library (PS5)
    let conceptId: String    // Imagic conceptId for catalog dedupe (PS5 cloud)
    var isOwned: Bool        // Whether user owns this game (PS5)
    var entitlementId: String   // PSCloud: entitlement id for streaming (Qt gameData.id)
    var storeProductId: String  // PSCloud: product_id from entitlements API

    init(productId: String, name: String, imageUrl: String, landscapeImageUrl: String = "",
         platform: String = "ps4", serviceType: String = "psnow",
         conceptUrl: String = "", conceptId: String = "", isOwned: Bool = false,
         entitlementId: String = "", storeProductId: String = "") {
        self.id = productId
        self.name = name
        self.imageUrl = imageUrl
        self.landscapeImageUrl = landscapeImageUrl.isEmpty ? imageUrl : landscapeImageUrl
        self.platform = platform
        self.serviceType = serviceType
        self.conceptUrl = conceptUrl
        self.conceptId = conceptId
        self.isOwned = isOwned
        self.entitlementId = entitlementId
        self.storeProductId = storeProductId
    }

    /// Mirrors CloudGameCard.qml getStreamingIdentifier() for PSCloud.
    var streamingIdentifier: String {
        if serviceType.lowercased() == "pscloud" {
            if !entitlementId.isEmpty { return entitlementId }
            if !storeProductId.isEmpty { return storeProductId }
        }
        return id
    }
}

// MARK: - CloudStreamSession (matches Android CloudStreamSession.kt)

/// Cloud stream session data returned after Gaikai allocation
struct CloudStreamSession {
    let serverIp: String
    let serverPort: Int
    let handshakeKey: String
    let launchSpec: String
    let sessionId: String
    let entitlementId: String
    let gameName: String
    let platform: String
    let psnWrapperType: Int
    let mtuIn: Int
    let mtuOut: Int
    let rttMs: Int
    let serviceType: String  // "psnow" or "pscloud"
}

// MARK: - Cloud Errors (matches Android CloudStreamingExceptions.kt)

/// PS Plus subscription required
struct PsPlusSubscriptionError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Account privacy settings issue
struct AccountPrivacySettingsError: Error, LocalizedError {
    let upgradeUrl: String
    let message: String
    var errorDescription: String? { message }
}

/// RTT > 80ms on auto datacenter (matches `gui/src/qml/Main.qml` ping dialog copy).
struct PingTimeoutError: Error, LocalizedError {
    static let alertTitle = "Ping Too High"
    static let alertMessage = """
Ping must be less than 80ms to start a cloud session.

To continue anyway, go to Settings → Cloud and manually select a datacenter for your service (Game Library or Game Catalog).
"""
    var errorDescription: String? { Self.alertMessage }
}

/// Authorization failed
struct AuthorizationFailedError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// General Gaikai allocation error
struct GaikaiAllocationError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Kamaji session error
struct KamajiSessionError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

// MARK: - Cloud API Constants (matches Android PsnApiConstants.kt + GaikaiConsts)

enum CloudApiConstants {
    // Gaikai constants (matches GaikaiConsts in PSGaikaiStreaming.kt)
    static let configBase = "https://config.cc.prod.gaikai.com/v1"
    static let gaikaiBase = "https://cc.prod.gaikai.com/v1"
    static let gaikaiAccountBase = "https://ca.account.sony.com"
    static let gaikaiRedirectUri = "gaikai://local"
    static let gaikaiUserAgent = "PlayStation Portal/6.0.0-rel.444+6a9cea6f5"

    // PSNow / Kamaji constants (matches PsnApiConstants.kt)
    static let kamajiBase = "https://psnow.playstation.com/kamaji/api/pcnow/00_09_000"
    static let storeBase = "https://psnow.playstation.com/store/api/pcnow/00_09_000"
    static let commerceBase = "https://commerce.api.np.km.playstation.net/commerce/api/v1"
    static let kamajiClientId = "bc6b0777-abb5-40da-92ca-e133cf18e989"
    static let kamajiRedirectUri = "https://psnow.playstation.com/app/2.2.0/133/5cdcc037d/grc-response.html"
    static let kamajiOrigin = "https://psnow.playstation.com"
    static let kamajiReferer = "https://psnow.playstation.com/app/2.2.0/133/5cdcc037d/"
    static let kamajiUserAgent = "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) playstation-now/0.0.0 Chrome/83.0.4103.104 Electron/9.0.4 Safari/537.36 gkApollo"
    static let ps4Scopes = "kamaji:commerce_native kamaji:commerce_container kamaji:lists kamaji:s2s.subscriptionsPremium.get"

    // Cloud config (matches CloudConfig in CloudStreamingBackend.kt)
    static let accountBase = "https://ca.account.sony.com/api"
}

// MARK: - Gaikai Allocation Result

struct GaikaiAllocationResult {
    let success: Bool
    let message: String
    var serverIp: String = ""
    var serverPort: Int = 0
    var handshakeKey: String = ""
    var launchSpec: String = ""
    var sessionId: String = ""
    var psnWrapperType: Int = 0
    var mtuIn: Int = 0
    var mtuOut: Int = 0
    var rttMs: Int = 0
}

// MARK: - Kamaji Session Result

struct KamajiSessionResult {
    let success: Bool
    let message: String
    var entitlementId: String = ""
    var platform: String = ""
}

// MARK: - Cloud locale

private let cloudLocaleLog = OSLog(subsystem: "com.pylux.stream", category: "CloudLocale")

enum CloudLocaleSettings {
    private static let preferencesKey = "cloud_language_pscloud"
    static let defaultStored = "en-US"

    static var isConfigured: Bool {
        UserDefaults.standard.object(forKey: preferencesKey) != nil
    }

    static var stored: String {
        UserDefaults.standard.string(forKey: preferencesKey) ?? defaultStored
    }

    static var imagicLocale: String { stored.lowercased() }

    static func unconfiguredWarning() -> String {
        "Could not detect your PlayStation region. The catalog may not match your store."
    }

    static func parseStorePath(_ stored: String) -> (country: String, language: String) {
        let parts = stored.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let language = parts.first.map(String.init)?.lowercased()
        let lang = (language?.isEmpty == false) ? language! : "en"
        var country = parts.count > 1 ? String(parts[1]).uppercased() : "US"
        if country.isEmpty { country = "US" }
        return (country, lang)
    }

    static func fromSession(language: String?, country: String?) -> String? {
        let lang = language?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let cty = country?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !lang.isEmpty, !cty.isEmpty else { return nil }
        return "\(lang)-\(cty.uppercased())"
    }

    static func setFromSession(language: String?, country: String?) {
        guard let locale = fromSession(language: language, country: country) else {
            os_log(.info, log: cloudLocaleLog,
                   "Kamaji session: no language/country in response (stored=%{public}s)", stored)
            return
        }
        if isConfigured && locale == stored {
            os_log(.info, log: cloudLocaleLog,
                   "Kamaji session locale unchanged: %{public}s", locale)
            return
        }
        setStored(locale)
    }

    static func setStored(_ value: String) {
        if isConfigured && stored == value { return }
        let wasConfigured = isConfigured
        let previous = wasConfigured ? stored : defaultStored
        UserDefaults.standard.set(value, forKey: preferencesKey)
        os_log(.info, log: cloudLocaleLog,
               "Cloud locale %{public}s: %{public}s -> %{public}s",
               wasConfigured ? "changed" : "configured", previous, value)
        invalidateCatalogCache()
    }

    private static let catalogCacheSubdir = "cloud_catalog_cache"

    private static func invalidateCatalogCache() {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(catalogCacheSubdir, isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return
        }
        for file in files where !file.hasDirectoryPath {
            try? FileManager.default.removeItem(at: file)
        }
    }

    static func applyLocaleFromKamajiSessionBody(_ body: String) {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any] else { return }
        setFromSession(
            language: dataObj["language"] as? String,
            country: dataObj["country"] as? String
        )
    }

    private static let bootstrapLock = NSLock()

    @discardableResult
    static func ensureConfigured(npssoToken: String) -> Bool {
        if isConfigured { return true }
        guard !npssoToken.isEmpty else {
            os_log(.info, log: cloudLocaleLog, "Locale bootstrap skipped: no npsso token")
            return false
        }

        bootstrapLock.lock()
        defer { bootstrapLock.unlock() }
        if isConfigured { return true }

        os_log(.info, log: cloudLocaleLog, "Bootstrapping cloud locale via Kamaji session (first time only)")
        let duid = generateBootstrapDuid()
        guard let code = fetchBootstrapOAuthCode(npssoToken: npssoToken, duid: duid) else {
            os_log(.info, log: cloudLocaleLog, "Locale bootstrap failed: OAuth")
            return false
        }
        guard postBootstrapKamajiSession(oauthCode: code, duid: duid) else {
            os_log(.info, log: cloudLocaleLog, "Locale bootstrap failed: Kamaji session")
            return false
        }
        os_log(.info, log: cloudLocaleLog, "Locale bootstrap OK: %{public}s", stored)
        return isConfigured
    }

    private static func fetchBootstrapOAuthCode(npssoToken: String, duid: String) -> String? {
        let params: [(String, String)] = [
            ("smcid", "pc:psnow"), ("applicationId", "psnow"),
            ("response_type", "code"), ("scope", CloudApiConstants.ps4Scopes),
            ("client_id", CloudApiConstants.kamajiClientId),
            ("redirect_uri", CloudApiConstants.kamajiRedirectUri),
            ("service_entity", "urn:service-entity:psn"), ("prompt", "none"),
            ("renderMode", "mobilePortrait"), ("hidePageElements", "forgotPasswordLink"),
            ("displayFooter", "none"), ("disableLinks", "qriocityLink"),
            ("mid", "PSNOW"), ("duid", duid), ("layout_type", "popup"),
            ("service_logo", "ps"), ("tp_psn", "true"), ("noEVBlock", "true")
        ]
        let query = params.map { "\($0.0)=\($0.1.cloudUrlEncoded)" }.joined(separator: "&")
        let url = "\(CloudApiConstants.accountBase)/v1/oauth/authorize?\(query)"

        guard let response = CloudHttpClient.get(url: url, headers: [
            "Cookie": "npsso=\(npssoToken)"
        ], followRedirects: false), response.statusCode == 302,
              let location = CloudHttpClient.extractLocation(from: response),
              let comps = URLComponents(string: location),
              let code = comps.queryItems?.first(where: { $0.name == "code" })?.value,
              !code.isEmpty else { return nil }
        return code
    }

    private static func postBootstrapKamajiSession(oauthCode: String, duid: String) -> Bool {
        let url = "\(CloudApiConstants.kamajiBase)/user/session"
        let body = "code=\(oauthCode)&client_id=\(CloudApiConstants.kamajiClientId)&duid=\(duid)"

        guard let response = CloudHttpClient.post(url: url, body: body, headers: [
            "Content-Type": "text/plain;charset=UTF-8",
            "X-Alt-Referer": CloudApiConstants.kamajiRedirectUri,
            "Origin": CloudApiConstants.kamajiOrigin,
            "Referer": CloudApiConstants.kamajiReferer,
            "Accept": "*/*"
        ]), response.statusCode == 200 else { return false }

        guard let data = response.body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let header = json["header"] as? [String: Any],
              header["status_code"] as? String == "0x0000" else { return false }

        applyLocaleFromKamajiSessionBody(response.body)
        return isConfigured
    }

    private static func generateBootstrapDuid() -> String {
        let prefix = "0000000700410080"
        var randomBytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, 16, &randomBytes)
        return prefix + randomBytes.map { String(format: "%02x", $0) }.joined()
    }
}
