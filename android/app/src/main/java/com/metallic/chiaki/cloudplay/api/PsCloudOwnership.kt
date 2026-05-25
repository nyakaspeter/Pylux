// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL

package com.metallic.chiaki.cloudplay.api

import com.metallic.chiaki.cloudplay.model.CloudGame
import org.json.JSONObject

/**
 * PS5 cloud ownership matching — mirrors gui/src/cloudcatalogbackend.cpp
 */
object PsCloudOwnership
{
	const val PAGE_SIZE = 300
	const val PAGE_COOLDOWN_MS = 100L

	data class Entitlement(
		val id: String,
		val productId: String,
		val activeFlag: Boolean,
		val packageType: String,
		val name: String
	)

	/** Mirrors CloudCatalogBackend::filterOwnedPs5Games */
	fun filterOwnedPs5Games(entitlements: List<Entitlement>): List<Entitlement>
	{
		return entitlements.filter { ent ->
			ent.packageType == "PSGD" &&
				ent.activeFlag &&
				!ent.productId.startsWith("IP") &&
				!ent.productId.startsWith("SUB")
		}
	}

	fun parseEntitlement(obj: JSONObject): Entitlement?
	{
		val id = obj.optString("id", "")
		if (id.isEmpty()) return null
		val gameMeta = obj.optJSONObject("game_meta") ?: JSONObject()
		val name = gameMeta.optString("name", id)
		return Entitlement(
			id = id,
			productId = obj.optString("product_id", ""),
			activeFlag = obj.optBoolean("active_flag", false),
			packageType = gameMeta.optString("package_type", ""),
			name = name
		)
	}

	/** Mirrors CloudCatalogBackend::processCrossReferenceComplete */
	fun crossReferenceOwnedGames(
		filteredEntitlements: List<Entitlement>,
		publicCatalog: List<CloudGame>
	): List<CloudGame>
	{
		val catalogMap = publicCatalog.associateBy { it.productId }
		val ownedGames = mutableListOf<CloudGame>()

		for (ent in filteredEntitlements)
		{
			val catalogGame = when {
				ent.productId.isNotEmpty() && catalogMap.containsKey(ent.productId) ->
					catalogMap[ent.productId]
				ent.id.isNotEmpty() && catalogMap.containsKey(ent.id) ->
					catalogMap[ent.id]
				else -> null
			} ?: continue

			ownedGames.add(
				catalogGame.copy(
					isOwned = true,
					entitlementId = ent.id,
					storeProductId = ent.productId
				)
			)
		}

		return ownedGames
	}

	/** Mirrors CloudPlayView.qml All tab ownership marking */
	fun markAllTabOwnership(publicCatalog: List<CloudGame>, ownedCrossRef: List<CloudGame>): List<CloudGame>
	{
		val ownedIds = mutableSetOf<String>()
		for (game in ownedCrossRef)
		{
			if (game.storeProductId.isNotEmpty()) ownedIds.add(game.storeProductId)
			if (game.productId.isNotEmpty()) ownedIds.add(game.productId)
		}

		val ownedByCatalogId = ownedCrossRef.associateBy { it.productId }

		return publicCatalog.map { cat ->
			val isOwned = ownedIds.contains(cat.productId)
			if (!isOwned)
			{
				cat.copy(isOwned = false)
			}
			else
			{
				val matched = ownedByCatalogId[cat.productId]
				cat.copy(
					isOwned = true,
					entitlementId = matched?.entitlementId ?: "",
					storeProductId = matched?.storeProductId ?: ""
				)
			}
		}
	}

	fun streamingIdentifier(game: CloudGame): String
	{
		if (game.serviceType.equals("pscloud", ignoreCase = true))
		{
			if (game.entitlementId.isNotEmpty()) return game.entitlementId
			if (game.storeProductId.isNotEmpty()) return game.storeProductId
		}
		return game.productId
	}
}
