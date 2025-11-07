import 'dart:convert'; // Untuk encode/decode JSON
import 'dart:math'; // Untuk fungsi 'min'
import 'package:shared_preferences/shared_preferences.dart'; // Penyimpanan lokal
import '../models/article.dart'; // Sesuaikan path ke model Article Anda
import 'package:flutter/foundation.dart'; // Untuk listEquals dan debugPrint

// Kelas untuk mengelola logika bookmark (simpan, hapus, kelompokkan)
class BookmarkService {
  // Kunci utama SharedPreferences untuk menyimpan daftar nama grup
  static const _groupsKey = 'bookmark_groups_list_v2'; // v2 untuk menandai versi struktur data
  // Awalan unik untuk kunci SharedPreferences tempat data artikel per grup disimpan
  static const _bookmarksPrefix = 'bookmarks_data_v2_';
  // Kunci baru untuk menyimpan SEMUA artikel bookmark (tanpa grup awal)
  static const _allBookmarksKey = 'all_bookmarked_articles_v2';

  /// Mendapatkan daftar semua nama grup bookmark yang telah dibuat pengguna.
  Future<List<String>> getGroups() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_groupsKey) ?? [];
    } catch (e) {
      debugPrint("Error getting bookmark groups: $e");
      return [];
    }
  }

  /// Menambahkan nama grup baru ke daftar grup (jika belum ada).
  Future<bool> addGroup(String groupName) async {
     final trimmedName = groupName.trim();
     if (trimmedName.isEmpty) {
        debugPrint("Attempted to add empty group name.");
        return false;
     }
     try {
       final prefs = await SharedPreferences.getInstance();
       final groups = await getGroups();
       if (!groups.any((g) => g.toLowerCase() == trimmedName.toLowerCase())) {
          groups.add(trimmedName);
          await prefs.setStringList(_groupsKey, groups);
          debugPrint("Bookmark group added: $trimmedName");
          return true;
       }
       debugPrint("Bookmark group already exists: $trimmedName");
       return false;
     } catch (e) {
       debugPrint("Error adding bookmark group '$trimmedName': $e");
       return false;
     }
  }

  /// Mendapatkan daftar [Article] untuk grup bookmark tertentu.
  Future<List<Article>> getBookmarksByGroup(String groupName) async {
    final trimmedGroupName = groupName.trim();
    if (trimmedGroupName.isEmpty) return [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_bookmarksPrefix$trimmedGroupName';
      final List<String>? articlesJsonList = prefs.getStringList(key);
      if (articlesJsonList == null) return [];
      List<Article> articles = [];
      for (String jsonString in articlesJsonList) {
         try { articles.add(Article.fromJson(jsonDecode(jsonString))); }
         catch (decodeError) { debugPrint("Error decoding article in group '$trimmedGroupName': $decodeError"); }
      }
      return articles;
    } catch (e) {
      debugPrint("Error getting bookmarks for group '$trimmedGroupName': $e");
      return [];
    }
  }

  /// Menyimpan [Article] ke grup bookmark tertentu. (Dipanggil setelah grup dipilih/dibuat)
  Future<void> addBookmark(Article article, String groupName) async {
     final trimmedGroupName = groupName.trim();
     if (trimmedGroupName.isEmpty) throw ArgumentError("Nama grup tidak boleh kosong.");
     try {
       await addGroup(trimmedGroupName); // Pastikan grup ada
       final prefs = await SharedPreferences.getInstance();
       final key = '$_bookmarksPrefix$trimmedGroupName';
       final List<Article> currentBookmarks = await getBookmarksByGroup(trimmedGroupName);
       if (!currentBookmarks.any((a) => a.id == article.id)) {
         currentBookmarks.insert(0, article);
         final List<String> articlesJsonList = currentBookmarks.map((a) => jsonEncode(a.toJson())).toList();
         await prefs.setStringList(key, articlesJsonList);
         final titleSnippet = article.title.substring(0,min(15, article.title.length));
         debugPrint("Article ${article.id} ('$titleSnippet...') added to group '$trimmedGroupName'");
       } else {
          debugPrint("Article ${article.id} already exists in group '$trimmedGroupName'");
       }
     } catch (e) {
       debugPrint("Error adding bookmark to group '$trimmedGroupName': $e");
       throw Exception('Gagal menyimpan bookmark ke grup "$trimmedGroupName".');
     }
  }

  /// [BARU] Menyimpan artikel ke daftar utama (tanpa grup).
  Future<bool> addSimpleBookmark(Article article) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Gunakan getAllBookmarkedArticlesSimple (nama baru dari getAllBookmarkedArticles sebelumnya)
      final List<Article> currentBookmarks = await getAllBookmarkedArticlesSimple();
      if (!currentBookmarks.any((a) => a.id == article.id)) {
        currentBookmarks.insert(0, article);
        final List<String> articlesJsonList = currentBookmarks.map((a) => jsonEncode(a.toJson())).toList();
        await prefs.setStringList(_allBookmarksKey, articlesJsonList);
        debugPrint("Simple bookmark added: ${article.id}");
        return true;
      } else {
        debugPrint("Simple bookmark already exists: ${article.id}");
        return false;
      }
    } catch (e) {
      debugPrint("Error adding simple bookmark: $e");
      throw Exception('Gagal menyimpan bookmark.');
    }
  }

  /// [NAMA BARU & FUNGSI UTAMA] Mendapatkan semua artikel dari daftar utama (tanpa grup).
  /// Sebelumnya bernama getAllBookmarkedArticles.
  Future<List<Article>> getAllBookmarkedArticlesSimple() async {
     try {
       final prefs = await SharedPreferences.getInstance();
       final List<String>? articlesJsonList = prefs.getStringList(_allBookmarksKey);
       if (articlesJsonList == null) return [];
       List<Article> articles = [];
        for (String jsonString in articlesJsonList) {
           try { articles.add(Article.fromJson(jsonDecode(jsonString))); }
           catch (decodeError) { debugPrint("Error decoding simple bookmark article: $decodeError"); }
        }
       // Urutkan berdasarkan tanggal (opsional)
       articles.sort((a,b) => b.publishedAt.compareTo(a.publishedAt));
       return articles;
     } catch (e) {
       debugPrint("Error getting all simple bookmarks: $e");
       return [];
     }
  }

  /// Menghapus [Article] dari daftar utama DAN semua grup.
   Future<bool> removeBookmark(Article article) async {
     bool removedFromSimpleList = false;
     bool removedFromGroup = false;
     try {
       // Hapus dari daftar utama
       final prefs = await SharedPreferences.getInstance();
       List<Article> simpleBookmarks = await getAllBookmarkedArticlesSimple();
       int initialSimpleLength = simpleBookmarks.length;
       simpleBookmarks.removeWhere((a) => a.id == article.id);
       if (simpleBookmarks.length < initialSimpleLength) {
          removedFromSimpleList = true;
          final List<String> simpleJsonList = simpleBookmarks.map((a) => jsonEncode(a.toJson())).toList();
          await prefs.setStringList(_allBookmarksKey, simpleJsonList);
          debugPrint("Simple bookmark removed: ${article.id}");
       }

       // Hapus dari semua grup
       final groups = await getGroups();
       for (final groupName in groups) {
          final key = '$_bookmarksPrefix$groupName';
          List<Article> groupBookmarks = await getBookmarksByGroup(groupName);
          int initialGroupLength = groupBookmarks.length;
          groupBookmarks.removeWhere((a) => a.id == article.id);
          if (groupBookmarks.length < initialGroupLength) {
             removedFromGroup = true;
             final List<String> groupJsonList = groupBookmarks.map((a) => jsonEncode(a.toJson())).toList();
             if (groupJsonList.isEmpty) {
                await prefs.remove(key);
                await removeGroupNameIfEmpty(groupName); // Hapus nama grup jika kosong
             } else {
                await prefs.setStringList(key, groupJsonList);
             }
             debugPrint("Article ${article.id} removed from group '$groupName'");
          }
       }
     } catch (e) {
        debugPrint("Error removing bookmark globally for ${article.id}: $e");
        throw Exception('Gagal menghapus bookmark.');
     }
     return removedFromSimpleList || removedFromGroup; // Return true jika terhapus dari salah satu
  }

   /// Cek apakah artikel ada di daftar utama ATAU di salah satu grup.
   Future<bool> isBookmarked(Article article) async {
     try {
       // Cek daftar utama dulu
       final prefs = await SharedPreferences.getInstance();
       final List<String>? simpleJsonList = prefs.getStringList(_allBookmarksKey);
       final articleIdJsonSnippet = '"id":"${article.id}"';
       if (simpleJsonList != null && simpleJsonList.any((jsonString) => jsonString.contains(articleIdJsonSnippet))) {
          return true;
       }
       // Jika tidak ada di daftar utama, cek semua grup
       final groups = await getGroups();
       for (final groupName in groups) {
          final key = '$_bookmarksPrefix$groupName';
          final List<String>? groupJsonList = prefs.getStringList(key);
          if (groupJsonList != null && groupJsonList.any((jsonString) => jsonString.contains(articleIdJsonSnippet))) {
             return true;
          }
       }
       return false; // Tidak ditemukan di mana pun
     } catch (e) {
       debugPrint("Error checking if article ${article.id} is bookmarked: $e");
       return false;
     }
  }

  // HAPUS DEFINISI getAllBookmarkedArticles yang kedua (yang mengambil dari grup)

  /// [BARU] Memindahkan/Menambahkan sekumpulan artikel ke grup tertentu.
  Future<void> assignArticlesToGroup(List<Article> articles, String groupName) async {
     if (articles.isEmpty) return;
     final trimmedGroupName = groupName.trim();
     if (trimmedGroupName.isEmpty) throw ArgumentError("Nama grup tidak boleh kosong.");
     try {
       await addGroup(trimmedGroupName);
       final prefs = await SharedPreferences.getInstance();
       final key = '$_bookmarksPrefix$trimmedGroupName';
       List<Article> groupBookmarks = await getBookmarksByGroup(trimmedGroupName);
       List<String> addedIds = [];
       for (final article in articles) {
          if (!groupBookmarks.any((a) => a.id == article.id)) {
             groupBookmarks.insert(0, article);
             addedIds.add(article.id);
          }
       }
       if (addedIds.isNotEmpty) {
          // Urutkan ulang grup setelah ditambah (opsional)
          groupBookmarks.sort((a,b) => b.publishedAt.compareTo(a.publishedAt));
          final List<String> articlesJsonList = groupBookmarks.map((a) => jsonEncode(a.toJson())).toList();
          await prefs.setStringList(key, articlesJsonList);
          debugPrint("${addedIds.length} articles assigned to group '$trimmedGroupName'. IDs: $addedIds");
       } else {
          debugPrint("No new articles to assign to group '$trimmedGroupName'.");
       }
     } catch (e) {
        debugPrint("Error assigning articles to group '$trimmedGroupName': $e");
        throw Exception('Gagal mengelompokkan artikel.');
     }
  }

   /// Mendapatkan nama grup pertama tempat [Article] disimpan.
   /// Mengembalikan nama grup (String) atau `null` jika tidak ditemukan.
   Future<String?> getGroupForArticle(Article article) async {
      try {
        final groups = await getGroups();
        for (final groupName in groups) {
           final List<Article> groupBookmarks = await getBookmarksByGroup(groupName);
           if (groupBookmarks.any((a) => a.id == article.id)) {
              return groupName; // Kembalikan nama grup pertama yang cocok
           }
        }
        return null; // Tidak ditemukan
      } catch (e) {
         debugPrint("Error getting group for article ${article.id}: $e");
         return null;
      }
   }

   /// Mendapatkan *semua* artikel yang di-bookmark dari semua grup.
   /// Berguna untuk menampilkan semua bookmark atau untuk sinkronisasi awal.
   Future<List<Article>> getAllBookmarkedArticles() async {
      List<Article> allBookmarks = [];
      // Gunakan Set untuk efisiensi pengecekan duplikasi ID
      Set<String> addedArticleIds = {};

      try {
        final groups = await getGroups();
        for (final groupName in groups) {
           final List<Article> groupBookmarks = await getBookmarksByGroup(groupName);
           for (final article in groupBookmarks) {
              // Jika ID artikel belum ditambahkan ke Set, tambahkan ke hasil dan Set
              if (addedArticleIds.add(article.id)) {
                 allBookmarks.add(article);
              }
           }
        }
        // Urutkan semua bookmark berdasarkan tanggal terbit terbaru (opsional)
        allBookmarks.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      } catch (e) {
         debugPrint("Error getting all bookmarked articles: $e");
         // Kembalikan list yang sudah terkumpul sejauh ini jika error
      }
      return allBookmarks;
   }

   /// Menghapus nama grup dari daftar utama jika grup tersebut sudah tidak berisi artikel.
   Future<void> removeGroupNameIfEmpty(String groupName) async {
       try {
         // Cek dulu apakah grup memang kosong
         final List<Article> bookmarks = await getBookmarksByGroup(groupName);
         if (bookmarks.isEmpty) {
             final prefs = await SharedPreferences.getInstance();
             final groups = await getGroups();
             // Hapus nama grup dari list (gunakan trim untuk konsistensi)
             if (groups.remove(groupName.trim())) {
                 // Simpan list nama grup yang sudah diperbarui
                 await prefs.setStringList(_groupsKey, groups);
                 // Pastikan juga data grupnya benar-benar dihapus (sebagai pengaman)
                 await prefs.remove('$_bookmarksPrefix${groupName.trim()}');
                 debugPrint("Removed empty group name from list: ${groupName.trim()}");
             }
         }
       } catch (e) {
          debugPrint("Error removing empty group name '${groupName.trim()}': $e");
       }
   }

  /// **[BARU]** Mengganti nama grup bookmark.
  /// Mengembalikan `true` jika berhasil, `false` jika nama lama tidak ditemukan, nama baru kosong, atau nama baru sudah ada.
  Future<bool> renameGroup(String oldGroupName, String newGroupName) async {
    final trimmedOldName = oldGroupName.trim();
    final trimmedNewName = newGroupName.trim();

    // Validasi nama tidak boleh kosong
    if (trimmedOldName.isEmpty || trimmedNewName.isEmpty) {
       debugPrint("Rename failed: Group names cannot be empty.");
       return false;
    }
    // Nama baru tidak boleh sama dengan nama lama (case insensitive)
    if (trimmedOldName.toLowerCase() == trimmedNewName.toLowerCase()) {
       debugPrint("Rename skipped: New name is the same as the old name.");
       return true; // Anggap berhasil jika sama
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> groups = await getGroups();

      // Cek apakah nama baru sudah ada (case insensitive)
      if (groups.any((g) => g.toLowerCase() == trimmedNewName.toLowerCase())) {
        debugPrint("Rename failed: New group name '$trimmedNewName' already exists.");
        return false;
      }

      // Cari index nama lama (case insensitive)
      int oldIndex = groups.indexWhere((g) => g.toLowerCase() == trimmedOldName.toLowerCase());

      // Jika nama lama tidak ditemukan
      if (oldIndex == -1) {
        debugPrint("Rename failed: Old group name '$trimmedOldName' not found.");
        return false;
      }

      // Ganti nama di daftar grup dengan nama baru yang sudah di-trim
      groups[oldIndex] = trimmedNewName;
      await prefs.setStringList(_groupsKey, groups);

      // Pindahkan data artikel dari kunci lama ke kunci baru
      // Gunakan nama asli (non-trimmed) untuk kunci lama jika perlu, tapi lebih aman pakai trimmed
      final oldKey = '$_bookmarksPrefix$trimmedOldName';
      final newKey = '$_bookmarksPrefix$trimmedNewName';
      final List<String>? articlesJsonList = prefs.getStringList(oldKey);
      if (articlesJsonList != null) {
        await prefs.setStringList(newKey, articlesJsonList); // Simpan data di kunci baru
        await prefs.remove(oldKey); // Hapus data di kunci lama
        debugPrint("Moved bookmark data from key '$oldKey' to '$newKey'");
      } else {
         debugPrint("No bookmark data found for old key '$oldKey' to move.");
      }

      debugPrint("Bookmark group renamed from '$trimmedOldName' to '$trimmedNewName'");
      return true;
    } catch (e) {
      debugPrint("Error renaming group '$trimmedOldName' to '$trimmedNewName': $e");
      return false;
    }
  }

  /// **[BARU]** Menghapus grup bookmark beserta semua artikel di dalamnya.
  /// Mengembalikan `true` jika berhasil, `false` jika grup tidak ditemukan.
  Future<bool> removeGroup(String groupName) async {
    final trimmedName = groupName.trim();
    if (trimmedName.isEmpty) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> groups = await getGroups();

      // Cari nama grup (case insensitive) dan hapus dari list
      String? nameToRemove;
      int removeIndex = groups.indexWhere((g) => g.toLowerCase() == trimmedName.toLowerCase());
      if (removeIndex != -1) {
         nameToRemove = groups.removeAt(removeIndex); // Hapus dari list dan simpan nama aslinya
      }

      // Jika nama grup ditemukan dan dihapus dari list
      if (nameToRemove != null) {
        // Simpan daftar grup yang sudah diperbarui
        await prefs.setStringList(_groupsKey, groups);
        // Hapus data artikel yang tersimpan untuk grup tersebut (gunakan nama asli yang dihapus)
        final dataKey = '$_bookmarksPrefix$nameToRemove';
        await prefs.remove(dataKey);
        debugPrint("Bookmark group removed: $nameToRemove (key: $dataKey)");
        return true;
      } else {
        debugPrint("Remove group failed: Group '$trimmedName' not found in list.");
        return false; // Grup tidak ada di daftar
      }
    } catch (e) {
      debugPrint("Error removing group '$trimmedName': $e");
      return false;
    }
  }

   /// Membersihkan semua data bookmark (semua grup dan artikel di dalamnya).
   /// **PERHATIAN:** Gunakan dengan hati-hati!
   Future<void> clearAllBookmarks() async {
      try {
         final prefs = await SharedPreferences.getInstance();
         final groups = await getGroups();

         // Hapus data artikel untuk setiap grup
         for (final groupName in groups) {
            await prefs.remove('$_bookmarksPrefix${groupName.trim()}'); // Gunakan trim
         }

         // Hapus daftar nama grup itu sendiri
         await prefs.remove(_groupsKey);
         debugPrint("Cleared all bookmark groups and data.");
      } catch (e) {
         debugPrint("Error clearing all bookmarks: $e");
         throw Exception("Gagal membersihkan semua bookmark.");
      }
   }
}

