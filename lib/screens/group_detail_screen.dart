import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Untuk SystemNavigator
import 'dart:ui'; // Untuk ImageFilter (blur)
import 'package:share_plus/share_plus.dart'; // Import Share Plus
import 'package:intl/intl.dart'; // Import intl for date formatting
import 'package:cached_network_image/cached_network_image.dart';
import '../models/article.dart'; // Sesuaikan path
import '../services/bookmark_service.dart'; // Sesuaikan path
import '../widgets/theme_toggle_button.dart'; // Sesuaikan path (opsional)
import '../widgets/article_card.dart'; // Gunakan ArticleCard biasa atau buat versi BookmarkCard
import 'article_detail_screen.dart'; // Untuk navigasi ke detail artikel
import '../utils/custom_page_transitions.dart'; // Jika menggunakan transisi khusus

// Enum untuk aksi menu popup
enum GroupAction { rename, share, delete }

class GroupDetailScreen extends StatefulWidget {
  final String groupName;
  final BookmarkService bookmarkService;
  // Callback untuk memberitahu parent bahwa grup berubah (rename/delete)
  final VoidCallback? onGroupChanged;
  // Callback untuk menangani toggle bookmark dari dalam grup
  // Terima BuildContext agar bisa menampilkan modal dari sini
  final Function(BuildContext, Article) onBookmarkToggle;
  // Daftar semua bookmark (untuk cek status isBookmarked di ArticleCard)
  final List<Article> allBookmarkedArticles;

  const GroupDetailScreen({
    Key? key,
    required this.groupName,
    required this.bookmarkService,
    this.onGroupChanged,
    required this.onBookmarkToggle,
    required this.allBookmarkedArticles,
  }) : super(key: key);

  @override
  _GroupDetailScreenState createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  late String _currentGroupName; // Nama grup bisa berubah
  List<Article> _articlesInGroup = [];
  bool _isLoading = true;

  // --- State Baru untuk Mode Seleksi ---
  bool _isSelectionMode = false;
  final Set<String> _selectedArticleIds = {}; // Menyimpan ID artikel yang dipilih
  // --- Akhir State Baru ---

  @override
  void initState() {
    super.initState();
    _currentGroupName = widget.groupName; // Simpan nama awal
    _loadArticles(); // Muat artikel saat masuk
  }

  // Memuat artikel untuk grup ini
  Future<void> _loadArticles() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final articles = await widget.bookmarkService.getBookmarksByGroup(_currentGroupName);
      articles.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      if (mounted) {
        setState(() {
          _articlesInGroup = articles;
          _isLoading = false;
          // <-- PERUBAHAN DIMULAI -->
          // Keluar dari mode seleksi jika artikel habis setelah load ulang
          if (_articlesInGroup.isEmpty && _isSelectionMode) {
             _exitSelectionMode();
          }
          // <-- PERUBAHAN SELESAI -->
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Gagal memuat artikel grup: $e');
      }
    }
  }


  // --- Fungsi Snackbar ---
   void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar( SnackBar( content: Row(children: [ const Icon(Icons.error_outline, color: Colors.white), const SizedBox(width: 8), Expanded(child: Text(message))]), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), action: SnackBarAction( label: 'TUTUP', textColor: Colors.white, onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar())));
  }

  void _showSuccessSnackBar(String message) {
     if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar( SnackBar( content: Row(children: [ Icon(Icons.check_circle_outline_rounded, color: Colors.green[300]), const SizedBox(width: 12), Expanded(child: Text(message, style: const TextStyle(color: Colors.white)))]), backgroundColor: const Color(0xFF333333), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  }
  // --- Akhir Fungsi Snackbar ---


  // --- Fungsi untuk Aksi Menu ---

  // Menampilkan dialog untuk mengganti nama grup
  Future<void> _showRenameDialog() async {
    final TextEditingController renameController = TextEditingController(text: _currentGroupName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
        title: const Text('Ganti Nama Koleksi'),
        content: TextField(
          controller: renameController,
          autofocus: true,
          decoration: InputDecoration(
             hintText: 'Nama koleksi baru...',
              focusedBorder: UnderlineInputBorder( borderSide: BorderSide(color: Colors.yellow[700]!)),
          ),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (value) => _submitRenameDialog(value, renameController), // Handle submit keyboard
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Batal', style: TextStyle(color: Theme.of(context).hintColor))),
          TextButton(
            onPressed: () => _submitRenameDialog(renameController.text, renameController),
            child: Text('Simpan', style: TextStyle(color: Colors.yellow[700], fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    // Proses rename jika nama baru valid dan berbeda
    if (newName != null && newName != _currentGroupName && mounted) {
      // Tampilkan loading indicator kecil
      showDialog(context: context, builder: (context) => const Center(child: CircularProgressIndicator()), barrierDismissible: false);
      bool success = await widget.bookmarkService.renameGroup(_currentGroupName, newName);
      Navigator.pop(context); // Tutup loading indicator

      if (success && mounted) {
        setState(() => _currentGroupName = newName); // Update nama di state AppBar
        widget.onGroupChanged?.call(); // Beri tahu parent (MainScreen) untuk refresh daftar grup
        _showSuccessSnackBar('Koleksi diganti nama menjadi "$newName"');
      } else if (mounted) {
         _showErrorSnackBar('Gagal mengganti nama. Nama "$newName" mungkin sudah ada.');
      }
    }
  }

  // Helper untuk submit rename dialog
  void _submitRenameDialog(String value, TextEditingController controller) {
     final name = value.trim();
     if (name.isNotEmpty) {
        Navigator.pop(context, name); // Kembalikan nama baru jika valid
     } else {
        _showErrorSnackBar('Nama tidak boleh kosong');
     }
  }


  // --- PERBAIKAN: Fungsi untuk berbagi grup ---
  Future<void> _shareGroup() async {
    if (_articlesInGroup.isEmpty) {
      _showErrorSnackBar('Koleksi ini kosong, tidak ada yang bisa dibagikan.');
      return;
    }

    // Format teks untuk dibagikan
    StringBuffer shareText = StringBuffer();
    shareText.writeln('Koleksi Bookmark Owrite: $_currentGroupName\n');

    for (int i = 0; i < _articlesInGroup.length; i++) {
      final article = _articlesInGroup[i];
      shareText.writeln('${i + 1}. ${article.title}');
      // Format tanggal
      final formattedDate = DateFormat('d MMM y HH:mm', 'id_ID').format(article.publishedAt.toLocal());
      shareText.writeln('   (${article.author} - $formattedDate)');
      shareText.writeln('   Baca: ${article.url}\n'); // Tambah baris kosong
    }

    try {
      // Gunakan share_plus untuk membagikan teks
      await Share.share(shareText.toString(), subject: 'Koleksi Bookmark: $_currentGroupName');
    } catch (e) {
      _showErrorSnackBar('Gagal membagikan koleksi: $e');
    }
  }
  // --- AKHIR PERBAIKAN ---

  // Menampilkan dialog konfirmasi hapus grup
//   Future<void> _confirmDeleteGroup() async {
//     final bool? confirm = await showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
//         title: const Text('Hapus Koleksi?'),
//         content: Text('Anda yakin ingin menghapus koleksi "$_currentGroupName" beserta ${_articlesInGroup.length} artikel di dalamnya? Aksi ini tidak dapat dibatalkan.'),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Batal', style: TextStyle(color: Theme.of(context).hintColor))),
//           TextButton(
//             onPressed: () => Navigator.pop(context, true),
//             child: const Text('Hapus', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
//           ),
//         ],
//       ),
//     );

//     if (confirm == true && mounted) {
//        showDialog(context: context, builder: (context) => const Center(child: CircularProgressIndicator()), barrierDismissible: false);
//        bool success = await widget.bookmarkService.removeGroup(_currentGroupName);
//        Navigator.pop(context); // Tutup loading

//        if (success && mounted) {
//          // --- PASTIKAN CALLBACK DIPANGGIL SEBELUM POP ---
//          widget.onGroupChanged?.call(); // Beri tahu parent (MainScreen) untuk refresh SEMUA bookmark
//          // --- AKHIR PEMASTIAN ---
//          Navigator.pop(context); // Kembali ke layar bookmark utama SETELAH callback
//          // Tampilkan notifikasi di layar sebelumnya (opsional, karena parent akan refresh)
//          // ScaffoldMessenger.of(context).showSnackBar(...);
//        } else if (mounted) {
//           _showErrorSnackBar('Gagal menghapus koleksi "$_currentGroupName"');
//        }
//     }
//   }

  // --- Akhir Fungsi Aksi Menu ---

  // <-- PERUBAHAN DIMULAI -->
  // --- Fungsi untuk Mode Seleksi ---

  void _enterSelectionMode(String articleId) {
    if (!_isSelectionMode && mounted) {
      setState(() {
        _isSelectionMode = true;
        _selectedArticleIds.add(articleId); // Langsung pilih item yang di-long press
      });
      debugPrint("Entered selection mode. Selected: $_selectedArticleIds");
    }
  }

  void _exitSelectionMode() {
    if (_isSelectionMode && mounted) {
      setState(() {
        _isSelectionMode = false;
        _selectedArticleIds.clear(); // Kosongkan pilihan saat keluar mode
      });
      debugPrint("Exited selection mode.");
    }
  }

  void _toggleSelection(String articleId) {
    if (mounted) {
      setState(() {
        if (_selectedArticleIds.contains(articleId)) {
          _selectedArticleIds.remove(articleId);
          debugPrint("Deselected article: $articleId. Remaining: $_selectedArticleIds");
          // Otomatis keluar mode seleksi jika tidak ada lagi yang dipilih
          if (_selectedArticleIds.isEmpty) {
             _isSelectionMode = false;
             debugPrint("Exited selection mode (no selection left).");
          }
        } else {
          _selectedArticleIds.add(articleId);
          debugPrint("Selected article: $articleId. All selected: $_selectedArticleIds");
        }
      });
    }
  }

  void _selectAll() {
    if (mounted && _articlesInGroup.isNotEmpty) { // Pastikan ada artikel untuk dipilih
      setState(() {
        _selectedArticleIds.addAll(_articlesInGroup.map((a) => a.id));
      });
      debugPrint("Selected all articles. Selected: $_selectedArticleIds");
    }
  }

  void _deselectAll() {
     if (mounted) {
       setState(() {
         _selectedArticleIds.clear();
         _isSelectionMode = false; // Keluar mode seleksi saat batal semua
       });
       debugPrint("Deselected all articles and exited selection mode.");
     }
  }

  Future<void> _deleteSelectedArticles() async {
    final count = _selectedArticleIds.length;
    if (count == 0) return; // Jangan lakukan apa-apa jika tidak ada yang dipilih

    // Tampilkan dialog konfirmasi
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
        title: Text('Hapus $count Artikel?'),
        // Ubah pesan sedikit
        content: const Text('Artikel yang dipilih akan dihapus dari SEMUA koleksi Anda. Aksi ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Batal', style: TextStyle(color: Theme.of(context).hintColor))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      showDialog(context: context, builder: (context) => const Center(child: CircularProgressIndicator()), barrierDismissible: false);
      int successCount = 0;
      int failCount = 0;

      // Buat salinan ID yang dipilih karena _selectedArticleIds akan diubah oleh _loadArticles
      final List<String> idsToDelete = List.from(_selectedArticleIds);

      // Hapus satu per satu
      for (final articleId in idsToDelete) {
         // Cari objek Article berdasarkan ID dari daftar saat ini (_articlesInGroup)
         // Gunakan try-catch untuk firstWhere jika artikel mungkin sudah tidak ada
         Article? articleToRemove;
         try {
            articleToRemove = _articlesInGroup.firstWhere((a) => a.id == articleId);
         } catch (e) {
            articleToRemove = null; // Artikel tidak ditemukan di list saat ini
         }

         if (articleToRemove != null) {
            try {
               // Panggil removeBookmark (yang menghapus dari semua grup terkait)
               bool removed = await widget.bookmarkService.removeBookmark(articleToRemove);
               if(removed) successCount++;
               else failCount++;
            } catch (e) {
               failCount++;
               debugPrint("Error removing article $articleId: $e");
            }
         } else {
            failCount++;
             debugPrint("Article with ID $articleId not found in current list for removal.");
         }
      }
       Navigator.pop(context); // Tutup loading

       if (mounted) {
          // Keluar dari mode seleksi SEBELUM memuat ulang
          _exitSelectionMode(); // Ini akan membersihkan _selectedArticleIds
          await _loadArticles(); // Muat ulang artikel dalam grup (seharusnya sudah berkurang)
          widget.onGroupChanged?.call(); // Beri tahu parent (MainScreen) untuk refresh state global

          if (successCount > 0) {
             _showSuccessSnackBar('$successCount artikel berhasil dihapus.');
          }
          if (failCount > 0) {
              _showErrorSnackBar('$failCount artikel gagal dihapus.');
          }
       }
    }
  }

  // --- Akhir Fungsi Mode Seleksi ---
  // <-- PERUBAHAN SELESAI -->

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // <-- PERUBAHAN DIMULAI -->
    final bool canSelectAll = _articlesInGroup.isNotEmpty && _selectedArticleIds.length < _articlesInGroup.length;
    // <-- PERUBAHAN SELESAI -->

    // <-- PERUBAHAN DIMULAI -->
    return WillPopScope( // Handle tombol back fisik saat mode seleksi
      onWillPop: () async {
        if (_isSelectionMode) {
          _exitSelectionMode(); // Keluar mode seleksi
          return false; // Jangan tutup layar
        }
        return true; // Izinkan tutup layar
      },
      // <-- PERUBAHAN SELESAI -->
      child: Scaffold(
        backgroundColor: Colors.transparent, // Latar belakang transparan
        body: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 40.0).copyWith(top: MediaQuery.of(context).padding.top + 10),
            color: Colors.black.withOpacity(0.3),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.0),
              child: Scaffold(
                backgroundColor: isDark ? Colors.grey[900] : Colors.grey[100],
                // <-- PERUBAHAN DIMULAI -->
                // --- AppBar Dinamis ---
                appBar: AppBar(
                  backgroundColor: isDark ? Colors.grey[850] : Colors.white,
                  elevation: 1,
                  // Tombol Leading: Back atau Cancel Selection
                  leading: IconButton(
                    icon: Icon(_isSelectionMode ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded),
                    onPressed: () {
                      if (_isSelectionMode) {
                        _exitSelectionMode(); // Keluar mode seleksi
                      } else {
                        Navigator.pop(context); // Kembali
                      }
                    },
                    tooltip: _isSelectionMode ? 'Batal Pilih' : 'Kembali',
                  ),
                  // Judul: Nama Grup atau Jumlah Terpilih
                  title: Text(
                    _isSelectionMode ? '${_selectedArticleIds.length} Dipilih' : _currentGroupName,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: _isSelectionMode ? 16 : 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Aksi AppBar: Menu Grup atau Aksi Seleksi
                  actions: _isSelectionMode
                  ? [ // Aksi saat mode seleksi
                      // Tombol Pilih Semua / Batal Pilih Semua
                      if (_articlesInGroup.isNotEmpty) // Tampilkan hanya jika ada artikel
                         IconButton(
                            icon: Icon(canSelectAll ? Icons.select_all_rounded : Icons.deselect_rounded),
                            tooltip: canSelectAll ? 'Pilih Semua' : 'Batal Pilih Semua',
                            onPressed: canSelectAll ? _selectAll : _deselectAll,
                         ),
                      // Tombol Hapus Pilihan (aktif jika ada yang dipilih)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded),
                        tooltip: 'Hapus Pilihan',
                        onPressed: _selectedArticleIds.isNotEmpty ? _deleteSelectedArticles : null, // Nonaktifkan jika kosong
                        color: _selectedArticleIds.isNotEmpty ? (isDark ? Colors.red[300]: Colors.red[700]) : Colors.grey, // Warna indikasi
                      ),
                    ]
                  : [ // Aksi saat mode normal
                     // Tombol Menu Aksi Grup (Rename, Share)
                     // Pastikan Hapus Grup sudah dihapus dari sini
                     PopupMenuButton<GroupAction>(
                       icon: const Icon(Icons.more_vert_rounded),
                       tooltip: 'Opsi Koleksi',
                       onSelected: (GroupAction result) {
                        switch (result) {
                        case GroupAction.rename:
                            _showRenameDialog();
                            break;
                        case GroupAction.share:
                            _shareGroup();
                            break;
                        case GroupAction.delete:
                            // TODO: implement delete group
                            break;
                        }
                       },
                       itemBuilder: (BuildContext context) => <PopupMenuEntry<GroupAction>>[
                         const PopupMenuItem<GroupAction>( value: GroupAction.rename, child: ListTile(leading: Icon(Icons.edit_rounded), title: Text('Ganti Nama'))),
                         const PopupMenuItem<GroupAction>( value: GroupAction.share, child: ListTile(leading: Icon(Icons.share_rounded), title: Text('Bagikan Koleksi'))),
                       ],
                     ),
                    ],
                ),
                // --- Akhir AppBar Dinamis ---
                // <-- PERUBAHAN SELESAI -->

                // Body: Loading, Empty State, atau List Artikel
                body: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _articlesInGroup.isEmpty
                        ? _buildEmptyGroupState()
                        : _buildArticleList(), // Gunakan helper list
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper Widget: Tampilan jika grup kosong
  Widget _buildEmptyGroupState() {
     return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmarks_outlined, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('Koleksi Kosong', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Simpan artikel ke koleksi "$_currentGroupName" untuk melihatnya di sini.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], height: 1.5)),
          ],
        ),
      ),
    );
  }

  // Helper Widget: Tampilan daftar artikel dalam grup
  Widget _buildArticleList() {
     return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16), // Sesuaikan padding
      itemCount: _articlesInGroup.length,
      itemBuilder: (context, index) {
        final article = _articlesInGroup[index];
        // <-- PERUBAHAN DIMULAI -->
        final isSelected = _selectedArticleIds.contains(article.id);
        // <-- PERUBAHAN SELESAI -->

        // <-- PERUBAHAN DIMULAI -->
        // Gunakan ListTile atau widget kustom yang lebih simpel untuk tampilan item
        return _buildSelectableArticleTile(article, isSelected);
        // <-- PERUBAHAN SELESAI -->
      },
    );
  }

  // <-- PERUBAHAN DIMULAI -->
  // --- WIDGET BARU: Tampilan item artikel yang bisa dipilih ---
  Widget _buildSelectableArticleTile(Article article, bool isSelected) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Warna latar belakang berubah jika terpilih
    final Color tileColor = isSelected
        ? Colors.blue.withOpacity(0.15) // Warna highlight saat terpilih
        : (isDark ? Colors.grey[850]! : Colors.white); // Warna normal
    // Warna border berubah jika terpilih
    final Color borderColor = isSelected
        ? Colors.blue // Warna border saat terpilih
        : (isDark ? Colors.grey[700]! : Colors.grey[300]!); // Warna border normal

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
        // Gunakan borderColor yang sudah ditentukan
        side: BorderSide(color: borderColor, width: isSelected ? 2.0 : 1.0),
      ),
      color: tileColor,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (_isSelectionMode) {
            _toggleSelection(article.id); // Pilih/batal pilih dalam mode seleksi
          } else {
             // Navigasi ke detail artikel jika tidak dalam mode seleksi
             Navigator.push(context, MaterialPageRoute(builder: (_) => ArticleDetailScreen(
                article: article,
                // Cek status bookmark dari daftar global yang diteruskan
                isBookmarked: widget.allBookmarkedArticles.any((a) => a.id == article.id),
                // Teruskan callback onToggleBookmarkAction dari parent
                onBookmarkToggle: () => widget.onBookmarkToggle(context, article),
                heroTag: 'bookmark-detail-${article.id}',
             )));
          }
        },
        onLongPress: () {
           _enterSelectionMode(article.id); // Masuk mode seleksi saat long press
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gambar Thumbnail
              Stack( // Stack untuk overlay checkbox
                 children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: CachedNetworkImage(
                        imageUrl: article.urlToImage ?? '',
                        width: 80, height: 80, fit: BoxFit.cover,
                        placeholder: (context, url) => Container(width: 80, height: 80, color: Colors.grey[300]),
                        errorWidget: (context, url, error) => Container(width: 80, height: 80, color: Colors.grey[300], child: Icon(Icons.image_not_supported_rounded, color: Colors.grey[500])),
                      ),
                    ),
                    // Overlay Checkbox/Radio
                    if (_isSelectionMode)
                       Positioned(
                         top: 4, left: 4,
                         child: IgnorePointer( // Abaikan tap pada ikon agar InkWell di atasnya bekerja
                            child: Container(
                               padding: const EdgeInsets.all(2),
                               decoration: BoxDecoration(
                                 color: Colors.black.withOpacity(0.4),
                                 shape: BoxShape.circle,
                               ),
                              child: Icon(
                                isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                color: isSelected ? Colors.blue : Colors.white.withOpacity(0.8),
                                size: 22,
                              ),
                            ),
                         ),
                       ),
                 ],
              ),
              const SizedBox(width: 12),
              // Info Teks
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, height: 1.3),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      article.author ?? 'Unknown',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                     const SizedBox(height: 4),
                     Text(
                      DateFormat('d MMM y', 'id_ID').format(article.publishedAt.toLocal()), // Format tanggal
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              // Hapus indikator seleksi dari sini karena sudah di overlay gambar
            ],
          ),
        ),
      ),
    );
  }
  // --- AKHIR WIDGET BARU ---
  // <-- PERUBAHAN SELESAI -->

}

