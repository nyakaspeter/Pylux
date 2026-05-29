// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL

package com.metallic.chiaki.cloudplay.api

import com.metallic.chiaki.cloudplay.model.CloudGame
import org.json.JSONObject

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

	private data class CatalogIndex(
		val byProductId: MutableMap<String, Int>,
		val byConceptId: MutableMap<String, Int>
	)

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

	fun crossReferenceOwnedGames(
		filteredEntitlements: List<Entitlement>,
		publicCatalog: List<CloudGame>,
		plusLibrarySupplement: List<CloudGame> = emptyList(),
		productIdAliases: Map<String, String> = emptyMap(),
	): List<CloudGame>
	{
		val catalogMap = catalogMapFirstWins(publicCatalog)
		for ((alias, canonical) in productIdAliases)
		{
			if (alias in catalogMap)
				continue
			catalogMap[canonical]?.let { catalogMap[alias] = it }
		}
		val supplementMap = catalogMapFirstWins(plusLibrarySupplement)
		val browseStableKey = buildStableKeyIndex(publicCatalog)
		val supplementStableKey = buildStableKeyIndex(plusLibrarySupplement)
		val byKey = linkedMapOf<String, CloudGame>()

		for (ent in filteredEntitlements)
		{
			val stable = productIdStableKey(ent.productId)
			val skipStableDemo = ent.name.contains("demo", ignoreCase = true)
			val meta = when {
				ent.productId.isNotEmpty() && catalogMap.containsKey(ent.productId) ->
					catalogMap[ent.productId]
				ent.id.isNotEmpty() && catalogMap.containsKey(ent.id) ->
					catalogMap[ent.id]
				ent.productId.isNotEmpty() && ent.id == ent.productId
					&& supplementMap.containsKey(ent.productId) ->
					supplementMap[ent.productId]
				stable != null && !skipStableDemo && browseStableKey.containsKey(stable) ->
					browseStableKey[stable]
				stable != null && !skipStableDemo && supplementStableKey.containsKey(stable) ->
					supplementStableKey[stable]
				else -> null
			} ?: continue

			val displayName = meta.name.ifEmpty { ent.name }
			val game = meta.copy(
				name = displayName,
				isOwned = true,
				entitlementId = ent.id,
				storeProductId = ent.productId
			)
			val key = ownedDedupeKey(meta, ent)
			val existing = byKey[key]
			byKey[key] = if (existing == null) game else preferOwnedEntry(existing, game)
		}

		return byKey.values.toList()
	}

	private fun ownedDedupeKey(meta: CloudGame, ent: Entitlement): String
	{
		if (meta.conceptId.isNotEmpty()) return "c:${meta.conceptId}"
		if (meta.productId.isNotEmpty()) return "p:${meta.productId}"
		if (ent.id.isNotEmpty()) return "e:${ent.id}"
		return "u:${meta.productId}:${ent.id}"
	}

	private fun preferOwnedEntry(existing: CloudGame, candidate: CloudGame): CloudGame
	{
		return when
		{
			existing.entitlementId.isEmpty() && candidate.entitlementId.isNotEmpty() -> candidate
			else -> existing
		}
	}

	private fun catalogMapFirstWins(games: List<CloudGame>): MutableMap<String, CloudGame>
	{
		val map = linkedMapOf<String, CloudGame>()
		for (game in games)
		{
			if (game.productId.isNotEmpty() && game.productId !in map)
				map[game.productId] = game
		}
		return map
	}

	/** Tokenize on '-' and '_'; identity is all tokens except the last (store SKU). */
	private fun productIdStableKey(productId: String): String?
	{
		if (productId.isEmpty())
			return null
		val tokens = mutableListOf<String>()
		for (dashPart in productId.split('-'))
		{
			for (token in dashPart.split('_'))
			{
				if (token.isNotEmpty())
					tokens.add(token)
			}
		}
		if (tokens.size < 2)
			return null
		return tokens.dropLast(1).joinToString("|")
	}

	private fun buildStableKeyIndex(games: List<CloudGame>): Map<String, CloudGame>
	{
		val index = linkedMapOf<String, CloudGame>()
		for (game in games)
		{
			val key = productIdStableKey(game.productId) ?: continue
			if (key !in index)
				index[key] = game
		}
		return index
	}

	fun mergeOwnedIntoBrowseCatalog(
		browseCatalog: List<CloudGame>,
		ownedCrossRef: List<CloudGame>
	): List<CloudGame>
	{
		val games = browseCatalog.toMutableList()
		val catalogIndex = buildCatalogIndex(games)

		for (owned in ownedCrossRef)
		{
			val catalogMatch = findCatalogIndexForOwned(owned, catalogIndex)
			if (catalogMatch >= 0)
			{
				val existing = games[catalogMatch]
				games[catalogMatch] = existing.copy(
					isOwned = true,
					entitlementId = owned.entitlementId.ifEmpty { existing.entitlementId },
					storeProductId = owned.storeProductId.ifEmpty { existing.storeProductId }
				)
				continue
			}

			val entry = owned.copy(isOwned = true)
			registerInCatalogIndex(entry, games.size, catalogIndex)
			games.add(entry)
		}

		return games.sortedWith(
			compareByDescending<CloudGame> { it.isOwned }
				.thenBy { it.name.lowercase() }
		)
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

	private fun buildCatalogIndex(games: List<CloudGame>): CatalogIndex
	{
		val byProductId = mutableMapOf<String, Int>()
		val byConceptId = mutableMapOf<String, Int>()
		for (i in games.indices)
			registerInCatalogIndex(games[i], i, CatalogIndex(byProductId, byConceptId))
		return CatalogIndex(byProductId, byConceptId)
	}

	private fun registerInCatalogIndex(game: CloudGame, index: Int, catalogIndex: CatalogIndex)
	{
		if (game.productId.isNotEmpty())
			catalogIndex.byProductId[game.productId] = index
		if (game.conceptId.isNotEmpty())
			catalogIndex.byConceptId[game.conceptId] = index
		if (game.entitlementId.isNotEmpty() && game.entitlementId != game.productId)
			catalogIndex.byProductId[game.entitlementId] = index
	}

	private fun findCatalogIndexForOwned(owned: CloudGame, catalogIndex: CatalogIndex): Int
	{
		if (owned.productId.isNotEmpty() && catalogIndex.byProductId.containsKey(owned.productId))
			return catalogIndex.byProductId.getValue(owned.productId)
		if (owned.entitlementId.isNotEmpty() && catalogIndex.byProductId.containsKey(owned.entitlementId))
			return catalogIndex.byProductId.getValue(owned.entitlementId)
		if (owned.storeProductId.isNotEmpty() && catalogIndex.byProductId.containsKey(owned.storeProductId))
			return catalogIndex.byProductId.getValue(owned.storeProductId)
		if (owned.conceptId.isNotEmpty() && catalogIndex.byConceptId.containsKey(owned.conceptId))
			return catalogIndex.byConceptId.getValue(owned.conceptId)
		return -1
	}
}
