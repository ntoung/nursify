package com.nursify.shared.network

import com.nursify.shared.model.ChartLookupRequest
import com.nursify.shared.model.ChartLookupResponse
import com.nursify.shared.model.Concept
import com.nursify.shared.model.ConceptSummary
import com.nursify.shared.model.ConceptType
import com.nursify.shared.model.NoteCreateRequest
import com.nursify.shared.model.NoteDto
import com.nursify.shared.model.SearchHistoryEntry
import com.nursify.shared.model.Suggestion
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.request.delete
import io.ktor.client.request.get
import io.ktor.client.request.parameter
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType
import io.ktor.serialization.kotlinx.json.json
import kotlinx.serialization.json.Json

/**
 * Talks to the backend API described in SYSTEM_DESIGN.md "API surface" /
 * backend/README.md. Ktor Client is multiplatform on its own — the engine
 * (Darwin on iOS, CIO on the JVM target) is selected per source set via the
 * dependency declared in build.gradle.kts, no expect/actual needed here.
 */
class ApiClient(private val baseUrl: String) {
    private val client = HttpClient {
        install(ContentNegotiation) {
            json(Json { ignoreUnknownKeys = true })
        }
    }

    suspend fun searchConcepts(query: String): List<ConceptSummary> =
        client.get("$baseUrl/concepts/search") {
            parameter("q", query)
        }.body()

    suspend fun conceptsByCategory(type: ConceptType): List<ConceptSummary> =
        client.get("$baseUrl/concepts/category/${type.name.lowercase()}").body()

    suspend fun concept(id: String): Concept =
        client.get("$baseUrl/concepts/$id").body()

    suspend fun chartLookup(request: ChartLookupRequest): ChartLookupResponse =
        client.post("$baseUrl/chart-lookup") {
            contentType(ContentType.Application.Json)
            setBody(request)
        }.body()

    suspend fun createNote(request: NoteCreateRequest): NoteDto =
        client.post("$baseUrl/notes") {
            contentType(ContentType.Application.Json)
            setBody(request)
        }.body()

    suspend fun suggestions(): List<Suggestion> =
        client.get("$baseUrl/suggestions").body()

    suspend fun searchHistory(): List<SearchHistoryEntry> =
        client.get("$baseUrl/search-history").body()

    suspend fun recordSearchHistory(conceptId: String): SearchHistoryEntry =
        client.post("$baseUrl/search-history/$conceptId").body()

    suspend fun clearSearchHistory() {
        client.delete("$baseUrl/search-history")
    }
}
