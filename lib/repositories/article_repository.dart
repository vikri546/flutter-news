import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/article.dart'; // Pastikan path model benar
import '../services/api_service.dart'; // Pastikan path service benar
import '../utils/app_exceptions.dart'; // Pastikan path exceptions benar
import 'package:flutter/foundation.dart'; // Untuk debugPrint

class ArticleRepository {
  final ApiService _apiService;

  // Kunci SharedPreferences untuk cache
  static const String _cachePrefix = 'articles_cache_'; // Awalan untuk kunci cache
  // Kunci spesifik untuk data, timestamp, dan kategori
  static const String _cacheDataKeySuffix = '_data';
  static const String _cacheTimestampKeySuffix = '_timestamp';

  // Waktu kedaluwarsa cache (dalam menit)
  static const int _cacheExpirationMinutes = 15; // Cache 15 menit

  // Constructor: Inisialisasi ApiService
  ArticleRepository({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  // --- DIPERBARUI: Mengambil artikel berdasarkan nama kategori dengan cache ---
  Future<List<Article>> getArticlesByCategory(
    String? categoryName, { // Terima String? (bisa null untuk "Semua Berita")
    bool forceRefresh = false,
    int page = 1,
    int pageSize = 20,
  }) async {
    // Gunakan nama kategori (atau 'all' jika null) sebagai bagian dari kunci cache
    final String cacheCategoryIdentifier = categoryName ?? 'all';

    // 1. Coba ambil dari cache jika halaman pertama dan tidak dipaksa refresh
    if (page == 1 && !forceRefresh) {
      try {
        final cachedArticles = await _getCachedArticles(cacheCategoryIdentifier);
        if (cachedArticles != null) { // Jika cache valid dan tidak kedaluwarsa
          debugPrint("Cache hit for category: $cacheCategoryIdentifier");
          return cachedArticles;
        }
         debugPrint("Cache miss or expired for category: $cacheCategoryIdentifier");
      } catch (e) {
        // Abaikan error cache dan lanjut fetch dari API
        debugPrint('Cache read error for $cacheCategoryIdentifier: $e');
      }
    }

    // 2. Jika cache tidak ada/kedaluwarsa/forceRefresh, fetch dari API
    try {
      // Panggil ApiService yang sudah melakukan filter server-side
      final List<Article> articles = await _apiService.getArticlesByCategory(
        categoryName, // Teruskan nama kategori (bisa null)
        page: page,
        pageSize: pageSize,
      );

      // 3. Simpan hasil halaman pertama ke cache
      if (page == 1) {
        await _cacheArticles(articles, cacheCategoryIdentifier);
      }

      return articles;
    } catch (e) {
      // 4. Jika API gagal & ini halaman pertama, coba kembalikan cache kedaluwarsa (jika ada)
      if (page == 1) {
        try {
          final cachedArticles = await _getCachedArticles(cacheCategoryIdentifier, ignoreExpiration: true);
          if (cachedArticles != null && cachedArticles.isNotEmpty) {
             debugPrint("API failed, returning expired cache for category: $cacheCategoryIdentifier");
            return cachedArticles; // Kembalikan cache lama sebagai fallback
          }
        } catch (cacheError) {
          // Jika cache juga gagal dibaca, biarkan error API asli yang di-throw
           debugPrint("Expired cache read error for $cacheCategoryIdentifier: $cacheError");
        }
      }
      // Jika bukan halaman pertama atau fallback cache gagal, rethrow error API
      rethrow;
    }
  }
  // --- AKHIR PERUBAHAN ---


  // Mencari artikel (langsung panggil ApiService, tanpa cache pencarian saat ini)
  Future<List<Article>> searchArticles({
    required String query,
    String? sortBy, // 'date', 'relevance', dll.
    String? language, // Diabaikan oleh ApiService WP
    int page = 1,
    int pageSize = 20,
  }) async {
    // Langsung teruskan ke ApiService
    return _apiService.searchArticles(
      query: query,
      sortBy: sortBy,
      language: language,
      page: page,
      pageSize: pageSize,
    );
  }

  // --- DIPERBARUI: Menyimpan artikel ke cache berdasarkan identifier kategori ---
  Future<void> _cacheArticles(List<Article> articles, String categoryIdentifier) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Encode list artikel ke JSON string
      final articlesJson = json.encode(articles.map((e) => e.toJson()).toList());

      // Buat kunci spesifik untuk data dan timestamp
      final String dataKey = '$_cachePrefix${categoryIdentifier}$_cacheDataKeySuffix';
      final String timestampKey = '$_cachePrefix${categoryIdentifier}$_cacheTimestampKeySuffix';

      // Simpan data dan timestamp saat ini
      await prefs.setString(dataKey, articlesJson);
      await prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);
      debugPrint("Articles cached for category: $categoryIdentifier");
    } catch (e) {
      // Gagal menyimpan cache, laporkan sebagai CacheException
      throw CacheException('Gagal menyimpan cache untuk kategori $categoryIdentifier: $e');
    }
  }
  // --- AKHIR PERUBAHAN ---


  // --- DIPERBARUI: Mengambil artikel dari cache berdasarkan identifier kategori ---
  Future<List<Article>?> _getCachedArticles(String categoryIdentifier, {bool ignoreExpiration = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Buat kunci spesifik
      final String dataKey = '$_cachePrefix${categoryIdentifier}$_cacheDataKeySuffix';
      final String timestampKey = '$_cachePrefix${categoryIdentifier}$_cacheTimestampKeySuffix';

      // Cek apakah data dan timestamp ada di cache
      if (!prefs.containsKey(dataKey) || !prefs.containsKey(timestampKey)) {
        return null; // Cache tidak ada
      }

      // Cek kedaluwarsa cache (kecuali jika diabaikan)
      if (!ignoreExpiration) {
        final cacheTimestamp = prefs.getInt(timestampKey) ?? 0;
        final cacheAgeMillis = DateTime.now().millisecondsSinceEpoch - cacheTimestamp;
        final cacheAgeMinutes = cacheAgeMillis / (1000 * 60);

        if (cacheAgeMinutes > _cacheExpirationMinutes) {
          debugPrint("Cache expired for category: $categoryIdentifier");
          // Hapus cache yang kedaluwarsa (opsional, agar bersih)
          await prefs.remove(dataKey);
          await prefs.remove(timestampKey);
          return null; // Cache kedaluwarsa
        }
      }

      // Ambil data JSON dari cache
      final articlesJson = prefs.getString(dataKey);
      if (articlesJson == null) {
        return null; // Data cache hilang secara aneh
      }

      // Decode JSON dan parse menjadi List<Article>
      final List<dynamic> decodedList = json.decode(articlesJson);
      final List<Article> articles = decodedList
          .map((item) => Article.fromJson(item as Map<String, dynamic>))
          .toList();

      return articles; // Kembalikan data cache
    } catch (e) {
      // Gagal membaca cache, laporkan sebagai CacheException
      throw CacheException('Gagal membaca cache untuk kategori $categoryIdentifier: $e');
    }
  }
  // --- AKHIR PERUBAHAN ---


  // Membersihkan *semua* cache artikel (bukan per kategori)
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Dapatkan semua kunci yang ada di SharedPreferences
      final allKeys = prefs.getKeys();
      // Filter kunci yang dimulai dengan awalan cache artikel
      final articleCacheKeys = allKeys.where((key) => key.startsWith(_cachePrefix)).toList();
      // Hapus semua kunci cache artikel yang ditemukan
      for (final key in articleCacheKeys) {
        await prefs.remove(key);
      }
      debugPrint("All article caches cleared.");
    } catch (e) {
      throw CacheException('Gagal membersihkan cache: $e');
    }
  }

  // Dispose ApiService (jika perlu)
  void dispose() {
    _apiService.dispose(); // Panggil dispose ApiService
  }
}
