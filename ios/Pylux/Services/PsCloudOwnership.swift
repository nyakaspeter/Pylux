// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// PS5 cloud ownership matching — mirrors gui/src/cloudcatalogbackend.cpp

import Foundation

/// Raw entitlement fields from Sony internal_entitlements API.
struct PsCloudEntitlement {
    let id: String
    let productId: String
    let activeFlag: Bool
    let packageType: String
    let name: String
}

enum PsCloudOwnership {
    static let pageSize = 300
    static let pageCooldownSeconds: TimeInterval = 0.1

    /// Mirrors CloudCatalogBackend::filterOwnedPs5Games
    static func filterOwnedPs5Games(_ entitlements: [PsCloudEntitlement]) -> [PsCloudEntitlement] {
        entitlements.filter { ent in
            guard ent.packageType == "PSGD" else { return false }
            guard ent.activeFlag else { return false }
            let pid = ent.productId
            guard !pid.hasPrefix("IP"), !pid.hasPrefix("SUB") else { return false }
            return true
        }
    }

    /// Mirrors CloudCatalogBackend::processCrossReferenceComplete
    static func crossReferenceOwnedGames(
        filteredEntitlements: [PsCloudEntitlement],
        publicCatalog: [CloudGame]
    ) -> [CloudGame] {
        var catalogMap: [String: CloudGame] = [:]
        for game in publicCatalog {
            catalogMap[game.id] = game
        }

        var ownedGames: [CloudGame] = []
        for ent in filteredEntitlements {
            let catalogGame: CloudGame?
            if !ent.productId.isEmpty, let g = catalogMap[ent.productId] {
                catalogGame = g
            } else if !ent.id.isEmpty, let g = catalogMap[ent.id] {
                catalogGame = g
            } else {
                catalogGame = nil
            }

            guard var game = catalogGame else { continue }

            game.isOwned = true
            game.entitlementId = ent.id
            game.storeProductId = ent.productId
            ownedGames.append(game)
        }

        return ownedGames
    }

    /// Mirrors CloudPlayView.qml All tab — ownedIds from cross-ref product_id || catalog productId
    static func markAllTabOwnership(publicCatalog: [CloudGame], ownedCrossRef: [CloudGame]) -> [CloudGame] {
        var ownedIds = Set<String>()
        for game in ownedCrossRef {
            if !game.storeProductId.isEmpty { ownedIds.insert(game.storeProductId) }
            if !game.id.isEmpty { ownedIds.insert(game.id) }
        }

        let ownedByCatalogId = Dictionary(ownedCrossRef.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        return publicCatalog.map { cat in
            var game = cat
            let isOwned = ownedIds.contains(cat.id)
            game.isOwned = isOwned
            if isOwned, let matched = ownedByCatalogId[cat.id] {
                game.entitlementId = matched.entitlementId
                game.storeProductId = matched.storeProductId
            }
            return game
        }
    }

    static func parseEntitlement(_ obj: [String: Any]) -> PsCloudEntitlement? {
        guard let id = obj["id"] as? String, !id.isEmpty else { return nil }
        let gameMeta = obj["game_meta"] as? [String: Any] ?? [:]
        let name = (gameMeta["name"] as? String) ?? id
        return PsCloudEntitlement(
            id: id,
            productId: (obj["product_id"] as? String) ?? "",
            activeFlag: (obj["active_flag"] as? Bool) ?? false,
            packageType: (gameMeta["package_type"] as? String) ?? "",
            name: name
        )
    }
}
