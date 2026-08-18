package com.nursify

import java.text.Normalizer
import kotlin.math.abs

/**
 * Relevance-ranked, typo-tolerant concept search. Kept in lock-step with the
 * iOS `ConceptLibrary.search` so the API and the app's offline library return
 * the same ordering for a given query.
 *
 * Every concept is scored across its name, aliases, and (low-weight) tags;
 * those with any signal come back best-match-first. Exact/prefix hits lead,
 * multi-word queries match regardless of word order, and misspellings resolve
 * via a capped Levenshtein gated to >=4-char words (so short acronyms like
 * "PE"/"MI" never fuzzy-match). See the tier comments below.
 */
object ConceptSearch {

    fun rank(query: String, concepts: List<ConceptDto>): List<ConceptSummaryDto> {
        val q = normalize(query)
        if (q.isEmpty()) return emptyList()
        val qTokens = tokens(q)
        val fuzzyTokens = qTokens.filter { it.length >= 4 }
        // A single character matches only prefixes; 2+ chars run full scoring.
        val allowSubstring = q.length >= 2

        val scored = ArrayList<Pair<ConceptDto, Double>>(concepts.size)
        for (c in concepts) {
            val name = normalize(c.name)
            val aliasNorms = c.aliases.map { normalize(it.text) }
            val tagNorms = c.tags.map { normalize(it) }

            var s = when {
                name == q -> 1000.0
                name.startsWith(q) -> 700.0
                allowSubstring && name.contains(q) -> 400.0
                else -> 0.0
            }

            var bestAlias = 0.0
            for (a in aliasNorms) {
                val x = when {
                    a == q -> 900.0
                    a.startsWith(q) -> 600.0
                    allowSubstring && a.contains(q) -> 350.0
                    else -> 0.0
                }
                if (x > bestAlias) bestAlias = x
            }
            if (bestAlias > s) s = bestAlias

            if (allowSubstring && qTokens.isNotEmpty()) {
                var matched = 0
                for (t in qTokens) {
                    if (name.contains(t) || aliasNorms.any { it.contains(t) } || tagNorms.any { it.contains(t) }) matched++
                }
                if (matched > 0) {
                    val cov = if (matched == qTokens.size) 500.0 else 250.0 * matched / qTokens.size
                    if (cov > s) s = cov
                }
            }

            if (allowSubstring) {
                for (tg in tagNorms) {
                    if (tg == q) { if (150.0 > s) s = 150.0 } else if (tg.contains(q)) { if (60.0 > s) s = 60.0 }
                }
            }

            if (fuzzyTokens.isNotEmpty()) {
                val candidates = tokens(name) + aliasNorms.flatMap { tokens(it) }
                for (qt in fuzzyTokens) {
                    val maxDist = if (qt.length <= 6) 1 else 2
                    for (cd in candidates) {
                        if (cd.length >= 4 && cd[0] == qt[0] && abs(cd.length - qt.length) <= maxDist) {
                            val d = levenshtein(qt, cd, maxDist)
                            if (d <= maxDist) {
                                val f = 240.0 - d * 70.0
                                if (f > s) s = f
                            }
                        }
                    }
                }
            }

            if (s > 0) scored.add(c to (s - name.length * 0.1))
        }

        return scored
            .sortedWith(compareByDescending<Pair<ConceptDto, Double>> { it.second }.thenBy { it.first.name.length })
            .take(60)
            .map { (c, _) ->
                ConceptSummaryDto(id = c.id, type = c.type, name = c.name, sideEffectsPreview = c.sections.sideEffects)
            }
    }

    /** Lowercased + diacritic-folded, matching iOS `normalizedForSearch`. */
    private fun normalize(s: String): String =
        Normalizer.normalize(s.trim(), Normalizer.Form.NFD).replace(Regex("\\p{M}+"), "").lowercase()

    /** Alphanumeric word tokens, dropping punctuation/whitespace. */
    private fun tokens(s: String): List<String> =
        s.split(Regex("[^\\p{L}\\p{N}]+")).filter { it.isNotEmpty() }

    /** Capped Levenshtein — mirrors iOS `ConceptLibrary.levenshtein`. */
    private fun levenshtein(a: String, b: String, cap: Int): Int {
        if (abs(a.length - b.length) > cap) return cap + 1
        var prev = IntArray(b.length + 1) { it }
        for (i in 1..a.length) {
            val cur = IntArray(b.length + 1)
            cur[0] = i
            var rowMin = i
            for (j in 1..b.length) {
                val cost = if (a[i - 1] == b[j - 1]) 0 else 1
                cur[j] = minOf(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
                rowMin = minOf(rowMin, cur[j])
            }
            if (rowMin > cap) return cap + 1
            prev = cur
        }
        return prev[b.length]
    }
}
