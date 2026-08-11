package com.nursify.shared

import com.nursify.shared.db.DatabaseDriverFactory
import com.nursify.shared.db.createDatabase
import com.nursify.shared.model.ChartLookupRequest
import com.nursify.shared.network.ApiClient
import kotlinx.coroutines.runBlocking
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * Runtime verification, not just "does it compile" — run via `gradle jvmTest`.
 * dbRoundTrip needs nothing external. apiClient* tests need a live backend
 * at BACKEND_URL (defaults to localhost:8080) and will fail fast with a
 * clear message if it's not running, rather than hanging.
 */
class SharedModuleSmokeTest {

    @Test
    fun conceptCache_insertAndReadBack_roundTrips() {
        val db = createDatabase(DatabaseDriverFactory())
        db.conceptCacheQueries.insertOrReplace(
            id = "test-id",
            type = "MEDICATION",
            name = "Furosemide",
            shortExplanation = "Helps remove excess fluid.",
            sectionsJson = "{}",
            tagsJson = "[]",
            aliasesJson = "[]",
            relatedConceptIdsJson = "[]",
            sourceCitation = "Source: test",
            cachedAt = 1L
        )

        val row = db.conceptCacheQueries.selectById("test-id").executeAsOne()
        assertEquals("Furosemide", row.name)
        assertEquals("MEDICATION", row.type)

        val all = db.conceptCacheQueries.selectAll().executeAsList()
        assertTrue(all.isNotEmpty())
    }

    @Test
    fun apiClient_searchConcepts_hitsLiveBackend() = runBlocking {
        val baseUrl = System.getenv("BACKEND_URL") ?: "http://localhost:8080"
        val client = ApiClient(baseUrl)
        val results = client.searchConcepts("furosemide")
        assertTrue(results.isNotEmpty(), "Expected at least one match from the live backend at $baseUrl")
        assertEquals("Furosemide", results.first().name)
    }

    @Test
    fun apiClient_chartLookup_hitsLiveBackend() = runBlocking {
        val baseUrl = System.getenv("BACKEND_URL") ?: "http://localhost:8080"
        val client = ApiClient(baseUrl)
        val response = client.chartLookup(
            ChartLookupRequest(
                chiefComplaints = listOf("CHF exacerbation"),
                medicationNames = listOf("Furosemide", "Not A Real Drug")
            )
        )
        assertEquals(2, response.medications.size)
        assertTrue(response.medications.first { it.name == "Furosemide" }.found)
        assertTrue(!response.medications.first { it.name == "Not A Real Drug" }.found)
    }
}
