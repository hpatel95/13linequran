//
//  QuranRepositoryProtocol.swift
//  QuranApp
//
//  Thread-safe repository contract for accessing Quran data.
//

import Foundation

public protocol QuranRepositoryProtocol: Sendable {
    /// Fetches all 114 canonical Surahs ordered by ID (1 ... 114)
    func fetchSurahs() async throws -> [Surah]
    
    /// Fetches a specific Surah by its ID (1 ... 114)
    func fetchSurah(id: Int) async throws -> Surah?

    /// Fetches all 30 canonical Juzs ordered by number (1 ... 30)
    func fetchJuzs() async throws -> [Juz]

    /// Fetches a specific Juz by its number (1 ... 30)
    func fetchJuz(number: Int) async throws -> Juz?

    /// Fetches a dictionary of Surah ID to Juz span string (e.g. [2: "Juz 1–3", 1: "Juz 1"])
    func fetchSurahJuzSpans() async throws -> [Int: String]
    
    /// Fetches the exactly 13 physical lines for an Indo-Pak Mushaf page (1 ... 849)
    func fetchLines(forPage pageNumber: Int) async throws -> [MushafLine]
    
    /// Fetches all verses belonging to a specific Surah
    func fetchAyahs(forSurah surahId: Int) async throws -> [Ayah]
    
    /// Fetches all verses belonging to a specific 13-line page
    func fetchAyahs(forPage pageNumber: Int) async throws -> [Ayah]
    
    /// Fetches a specific verse by Surah and verse number
    func fetchAyah(surah: Int, verse: Int) async throws -> Ayah?
    
    /// Fetches the translation for a given global verse ID and author code
    func fetchTranslation(ayahId: Int, authorCode: Translation.TranslationAuthor) async throws -> Translation?
    
    /// Executes a full-text search (FTS5) across Arabic and translations
    func search(query: String, limit: Int) async throws -> [SearchResult]
}
