import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/article.dart';
import '../providers/article_provider.dart';
import '../utils/strings.dart';
import '../utils/auth_service.dart';
import 'login_screen.dart';
import '../providers/language_provider.dart';
import '../services/bookmark_service.dart';
import '../widgets/bookmark_group_modal.dart';
import 'package:flutter/foundation.dart';
import 'article_detail_screen.dart';
import '../utils/custom_page_transitions.dart';
import '../widgets/article_card.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../providers/theme_provider.dart';
// 💡 Tambahan: Impor repository untuk mengambil data secara independen
import '../repositories/article_repository.dart';
// --- AWAL TAMBAHAN: Impor untuk SearchScreen ---
import 'search_screen.dart';
// --- AKHIR TAMBAHAN ---

class HomeScreen extends StatefulWidget {
  final List<Article> bookmarkedArticles;
  final Function(Article) onBookmarkToggle;

  const HomeScreen({
    Key? key,
    required this.bookmarkedArticles,
    required this.onBookmarkToggle,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _categoryScrollController = ScrollController();
  String? _previousCategory;
  String _currentUsername = 'Guest';
  final BookmarkService _bookmarkService = BookmarkService();
  // 💡 Tambahan: Buat instance repository
  final ArticleRepository _articleRepository = ArticleRepository();
  List<Article> _allBookmarkedArticles = [];
  bool _isLoadingBookmarks = true;

  // bool _showLogo = true; // <-- DIHAPUS: Header sekarang sticky
  late AnimationController _shakeController;

  List<Article> _cachedRecommendations = [];
  ArticleLoadingStatus? _previousStatus;

  // 🔑 Map GlobalKey untuk scrolling
  final Map<String, GlobalKey> _categoryKeys = {};

  // 💡 Tambahan: State untuk menyimpan Future dari kategori 'Terbaru'
  Future<List<Article>>? _latestCategory1Future;
  Future<List<Article>>? _latestCategory2Future;
  String? _latestCategory1Code; // Untuk melacak kategori
  String? _latestCategory2Code; // Untuk melacak kategori

  // --- AWAL PERUBAHAN: State untuk "Berita Terkini" (Load More) ---
  int _beritaTerkiniCount = 7; // Mulai dengan 7 artikel
  bool _isLoadMoreBeritaTerkini = false; // Status loading untuk tombol
  final Color _loadMoreColor = const Color(0xFFE5FF10); // Warna tombol
  // --- AKHIR PERUBAHAN ---

  final List<Map<String, dynamic>> _allCategories = [
    {'title': 'Hype', 'category': 'HYPE'},
    {'title': 'Olahraga', 'category': 'OLAHRAGA'},
    {'title': 'Ekonomi Bisnis', 'category': 'EKBIS'},
    {'title': 'Megapolitan', 'category': 'MEGAPOLITAN'},
    {'title': 'Daerah', 'category': 'DAERAH'},
    {'title': 'Nasional', 'category': 'NASIONAL'},
    {'title': 'Internasional', 'category': 'INTERNASIONAL'},
    // --- TAMBAHAN ---
    {'title': 'Politik', 'category': 'POLITIK'},
    {'title': 'Kesehatan', 'category': 'KESEHATAN'},
    // --- AKHIR TAMBAHAN ---
  ];

  List<String> _selectedCategories = [];

  // --- 💡 PERUBAHAN: Variabel untuk kategori harian ---
  Map<String, dynamic>? _dailyCategory1;
  Map<String, dynamic>? _dailyCategory2;

  // Daftar kategori yang akan dirotasi
  final List<String> _rotatingCategoryPoolCodes = [
    'HYPE',
    'OLAHRAGA',
    'EKBIS',
    'MEGAPOLITAN',
    'DAERAH',
  ];

  // Kunci SharedPreferences
  static const String _prefsDailyCategoriesDateKey = 'daily_categories_date';
  static const String _prefsDailyCategoriesListKey = 'daily_categories_list';

  // --- 💡 PERUBAHAN MINGGUAN: Variabel untuk 7 Artikel Pilihan ---
  int _weeklySeed = 0;
  // v2 ditambahkan untuk memastikan pengguna lama mendapat pembaruan jika kunci lama ter-cache
  static const String _prefsWeeklySeedDateKey = 'weekly_seed_date_v2';
  static const String _prefsWeeklySeedValueKey = 'weekly_seed_value_v2';
  // --- 💡 AKHIR PERUBAHAN ---

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll); // <-- Listener masih diperlukan untuk pagination
    _loadCurrentUser();
    _loadAllBookmarks();
    _loadSelectedCategories();
    _loadOrUpdateDailyCategories(); // ⬅️ PANGGIL FUNGSI BARU
    _loadOrUpdateWeeklySeed(); // ⬅️ PANGGIL FUNGSI MINGGUAN

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    final provider = Provider.of<ArticleProvider>(context, listen: false);
    provider.addListener(_onProviderUpdate);
    // Simpan kategori sebelumnya untuk mendeteksi perubahan
    _previousCategory = provider.currentCategory;

    // --- 🔑 PERUBAHAN: Set 'Top News' sebagai kategori default saat masuk ---
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // 1. Cek apakah kategori saat ini *bukan* 'Top News'
        if (_previousCategory != 'Top News') {
          // 2. Jika bukan, ubah ke 'Top News'.
          //    Ini akan memicu provider load artikel DAN memicu _onProviderUpdate
          //    yang kemudian akan memanggil _scrollToSelectedCategory.
          provider.changeCategory('Top News');
        } else {
          // 3. Jika defaultnya SUDAH 'Top News', kita tetap harus
          //    load artikel & panggil scroll secara manual.
          provider.loadArticles();
          _scrollToSelectedCategory('Top News');
        }
      }
    });
    // --- 🔑 AKHIR PERUBAHAN ---
  }

  // --- 💡 PERUBAHAN: Fungsi baru untuk load/update kategori harian ---
  Future<void> _loadOrUpdateDailyCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    // Format YYYY-MM-DD
    final currentDate =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final savedDate = prefs.getString(_prefsDailyCategoriesDateKey);
    List<String> chosenCategoryCodes = [];

    if (savedDate == currentDate) {
      // Masih hari yang sama, load dari cache
      chosenCategoryCodes =
          prefs.getStringList(_prefsDailyCategoriesListKey) ?? [];
    } else {
      // Hari baru atau cache kosong, generate kategori baru
      List<String> pool = List.from(_rotatingCategoryPoolCodes);
      pool.shuffle(Random());

      // Ambil 2 kategori teratas
      chosenCategoryCodes = pool.take(2).toList();

      // Simpan ke SharedPreferences
      await prefs.setString(_prefsDailyCategoriesDateKey, currentDate);
      await prefs.setStringList(_prefsDailyCategoriesListKey, chosenCategoryCodes);
    }

    // Setelah dapat 'chosenCategoryCodes', ubah menjadi Map<String, dynamic>
    // dan update state
    Map<String, dynamic>? cat1;
    Map<String, dynamic>? cat2;

    if (chosenCategoryCodes.isNotEmpty) {
      cat1 = _allCategories.firstWhere(
        (cat) => cat['category'] == chosenCategoryCodes[0],
        orElse: () => <String, dynamic>{}, // empty map
      );
      if (cat1.isEmpty) cat1 = null; // jika tidak ketemu, set null
    }

    if (chosenCategoryCodes.length > 1) {
      cat2 = _allCategories.firstWhere(
        (cat) => cat['category'] == chosenCategoryCodes[1],
        orElse: () => <String, dynamic>{}, // empty map
      );
      if (cat2.isEmpty) cat2 = null; // jika tidak ketemu, set null
    }

    if (mounted) {
      setState(() {
        _dailyCategory1 = cat1;
        _dailyCategory2 = cat2;
      });
    }
  }
  // --- 💡 AKHIR PERUBAHAN ---

  void _onProviderUpdate() {
    if (!mounted) return;
    final provider = Provider.of<ArticleProvider>(context, listen: false);
    final currentStatus = provider.status;

    bool wasLoading =
        (_previousStatus == ArticleLoadingStatus.loading || _previousStatus == null);

    bool isNotLoadingAnymore = currentStatus != ArticleLoadingStatus.loading;

    if (wasLoading && isNotLoadingAnymore) {
      if (currentStatus != ArticleLoadingStatus.error) {
        _updateCachedRecommendations(provider.articles);
      }
    }

    // Cek jika kategori berubah
    if (_previousCategory != provider.currentCategory) {
      _previousCategory = provider.currentCategory;
      // Panggil scroll setelah frame di-render
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // --- 🔑 PERUBAHAN: Tambahkan cek 'mounted' ---
        if (mounted) {
          _scrollToSelectedCategory(provider.currentCategory);
        }
        // --- 🔑 AKHIR PERUBAHAN ---
      });
    }

    _previousStatus = currentStatus;
  }

  void _updateCachedRecommendations(List<Article> articles) {
    if (articles.isEmpty) {
      if (mounted) {
        setState(() {
          _cachedRecommendations = [];
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _cachedRecommendations = _getRecommendations(articles);
      });
    }
  }

  // --- 💡 PERBAIKAN: Menambahkan metode yang hilang ---
  Future<void> _loadCurrentUser() async {
    final authService = AuthService();
    final user = await authService.getCurrentUser();
    if (mounted) {
      setState(() => _currentUsername = user?['username'] ?? 'Guest');
    }
  }

  Future<void> _loadAllBookmarks() async {
    if (_isLoadingBookmarks) {
      if (mounted) setState(() => _isLoadingBookmarks = true);
    }
    try {
      final bookmarks = await _bookmarkService.getAllBookmarkedArticles();
      if (mounted) {
        setState(() {
          _allBookmarkedArticles = bookmarks;
          _isLoadingBookmarks = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading all bookmarks: $e");
      if (mounted) setState(() => _isLoadingBookmarks = false);
    }
  }

  Future<void> _saveSelectedCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('selected_categories', _selectedCategories);
  }
  // --- 💡 AKHIR PERBAIKAN ---

  Future<void> _loadSelectedCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCategories = prefs.getStringList('selected_categories') ?? [];
    if (mounted) {
      setState(() {
        _selectedCategories = savedCategories;
      });
    }
  }

  // --- 💡 PERUBAHAN MINGGUAN: Fungsi baru untuk load/update seed mingguan ---
  Future<void> _loadOrUpdateWeeklySeed() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    final savedDateString = prefs.getString(_prefsWeeklySeedDateKey);
    int seedToUse;
    // Format YYYY-MM-DD
    final currentDateString =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    bool isNewWeek = false;

    if (savedDateString == null) {
      isNewWeek = true;
      debugPrint("Weekly Seed: First time run.");
    } else {
      try {
        final savedDate = DateTime.parse(savedDateString);
        // Cek apakah sudah 7 hari atau lebih
        if (now.difference(savedDate).inDays >= 7) {
          isNewWeek = true;
          debugPrint("Weekly Seed: New week detected.");
        } else {
          debugPrint("Weekly Seed: Same week.");
        }
      } catch (e) {
        // Jika parse gagal (format tanggal lama, dll), anggap minggu baru
        isNewWeek = true;
        debugPrint("Weekly Seed: Parse error, generating new seed.");
      }
    }

    if (isNewWeek) {
      seedToUse = now.millisecondsSinceEpoch; // Seed baru
      await prefs.setString(_prefsWeeklySeedDateKey, currentDateString);
      await prefs.setInt(_prefsWeeklySeedValueKey, seedToUse);
      debugPrint("Weekly Seed: New seed generated and saved: $seedToUse");
    } else {
      // Gunakan seed yang ada. Jika null (error aneh), buat seed baru
      seedToUse =
          prefs.getInt(_prefsWeeklySeedValueKey) ?? now.millisecondsSinceEpoch;
      debugPrint("Weekly Seed: Loaded existing seed: $seedToUse");
    }

    if (mounted) {
      setState(() {
        _weeklySeed = seedToUse;
      });
    }
  }

  /// Mengacak daftar artikel berdasarkan seed mingguan.
  List<Article> _getWeeklyShuffledArticles(List<Article> articles) {
    // Jangan acak jika list kosong atau seed belum siap
    if (articles.isEmpty || _weeklySeed == 0) return articles;
    // Buat salinan list agar tidak mengubah list aslinya (penting!)
    final shuffledList = List<Article>.from(articles);
    // Acak list menggunakan seed mingguan
    shuffledList.shuffle(Random(_weeklySeed));
    return shuffledList;
  }
  // --- 💡 AKHIR PERUBAHAN ---

  // --- 💡 PERBAIKAN: Mengganti duplikat _onProviderUpdate dengan _onReorderCategory ---
  void _onReorderCategory(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final String item = _selectedCategories.removeAt(oldIndex);
      _selectedCategories.insert(newIndex, item);

      _shakeController.stop(canceled: false);
    });
    _saveSelectedCategories();
  }
  // --- 💡 AKHIR PERBAIKAN ---

  Widget _buildProxyDecorator(
      Widget child, int index, Animation<double> animation) {
    return ScaleTransition(
      scale: animation.drive(Tween(begin: 1.0, end: 1.05)),
      child: AnimatedBuilder(
        animation: _shakeController,
        builder: (context, _) {
          final double rotation = (_shakeController.value - 0.5) * 0.05;
          return Transform.rotate(
            angle: rotation,
            child: child,
          );
        },
        child: child,
      ),
    );
  }

  void _onScroll() {
    if (!mounted) return;
    
    // --- AWAL PERUBAHAN: Logika _showLogo dihapus ---
    // final offset = _scrollController.offset;

    // if (offset <= 0 && !_showLogo) {
    //   setState(() => _showLogo = true);
    // } else if (offset > 0 && _showLogo) {
    //   setState(() => _showLogo = false);
    // }
    // --- AKHIR PERUBAHAN ---

    final maxScroll = _scrollController.position.maxScrollExtent;
    final offset = _scrollController.offset; // <-- Pindahkan ini ke sini
    if (offset >= maxScroll - 300 &&
        _scrollController.position.outOfRange == false) {
      Provider.of<ArticleProvider>(context, listen: false).loadMoreArticles();
    }
  }

  Future<void> _handleBookmarkTap(BuildContext context, Article article) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isCurrentlyBookmarked =
        _allBookmarkedArticles.any((a) => a.id == article.id);

    final authService = AuthService();
    final user = await authService.getCurrentUser();
    final bool isGuest = user == null || user['username'] == 'Guest';
    if (isGuest) {
      _showLoginRequiredSnackBar("Masuk untuk menyimpan artikel ini");
      return;
    }

    if (isCurrentlyBookmarked) {
      try {
        bool removed = await _bookmarkService.removeBookmark(article);
        if (removed && mounted) {
          setState(() {
            _allBookmarkedArticles.removeWhere((a) => a.id == article.id);
          });
          widget.onBookmarkToggle(article);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Artikel dihapus dari koleksi'),
              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[600],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        if (mounted) _showErrorSnackBar('Gagal menghapus bookmark: $e');
      }
    } else {
      final selectedGroup = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) => BookmarkGroupModal(
          article: article,
          bookmarkService: _bookmarkService,
        ),
      );

      if (selectedGroup != null && selectedGroup.isNotEmpty && mounted) {
        setState(() {
          _allBookmarkedArticles.insert(0, article);
        });
        widget.onBookmarkToggle(article);
        _showSuccessSnackBar('Artikel disimpan ke "$selectedGroup"');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(child: Text(message))
        ]),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
            label: 'TUTUP',
            textColor: Colors.white,
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentSnackBar()),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(Icons.check_circle_outline, color: Colors.green[300]),
          const SizedBox(width: 12),
          Expanded(
              child: Text(message,
                  style: const TextStyle(color: Colors.white)))
        ]),
        backgroundColor: const Color(0xFF333333),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showLoginRequiredSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(Icons.lock_outline, color: Colors.yellow[700]),
          const SizedBox(width: 12),
          Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)))
        ]),
        backgroundColor: const Color(0xFF333333),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
            label: 'LOGIN',
            textColor: Colors.yellow[700],
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const LoginScreen()))),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes < 1) return 'Baru saja';
        return '${difference.inMinutes} menit yang lalu';
      }
      return '${difference.inHours} jam yang lalu';
    } else if (difference.inDays == 1) {
      return 'Kemarin';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari yang lalu';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  List<Article> _getPopularArticles(List<Article> articles) {
    if (articles.isEmpty) return [];
    final sorted = List<Article>.from(articles);
    return sorted.take(1).toList();
  }

  // --- AWAL PERUBAHAN: Ganti nama dan logika _getMustReadArticles ---
  List<Article> _getBeritaTerkiniArticles(List<Article> articles) {
    if (articles.isEmpty) return [];
    // Ambil artikel berdasarkan jumlah state, bukan hardcode 7
    return articles.skip(1).take(_beritaTerkiniCount).toList();
  }
  // --- AKHIR PERUBAHAN ---

  List<Article> _getDiscoverMoreArticles(List<Article> articles) {
    if (articles.isEmpty) return [];
    return articles.skip(8).toList();
  }

  List<Article> _getArticlesByCategory(List<Article> articles, String category) {
    if (articles.isEmpty) return [];
    return articles
        .where((article) => article.category.toUpperCase() == category.toUpperCase())
        .toList();
  }

  List<Article> _getRecommendations(List<Article> articles) {
    if (articles.isEmpty) return [];
    final shuffled = List<Article>.from(articles)..shuffle(Random());
    return shuffled.take(5).toList();
  }

  void _navigateToSeeAll(String title, List<Article> articles) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SeeAllArticlesScreen(
          title: title,
          articles: articles,
          bookmarkedArticles: widget.bookmarkedArticles,
          onBookmarkToggle: widget.onBookmarkToggle,
        ),
      ),
    );
  }

  // --- TAMBAHKAN FUNGSI INI ---
  // Fungsi ini disalin dari search_screen.dart untuk menangani navigasi
  // dari card kustom yang akan kita buat.
  void _openArticle(Article article) {
    final heroTag = 'home-article-${article.id}'; // Ubah hero tag agar unik
    final isBookmarked = widget.bookmarkedArticles.any((a) => a.id == article.id);
    
    Navigator.of(context).push(
      HeroDialogRoute(
        builder: (context) => ArticleDetailScreen(
          article: article,
          isBookmarked: isBookmarked,
          onBookmarkToggle: () => widget.onBookmarkToggle(article),
          heroTag: heroTag,
        ),
      ),
    );
  }
  // --- AKHIR PENAMBAHAN ---

  // --- AWAL PERUBAHAN: Fungsi handler untuk load more ---
  void _loadMoreBeritaTerkini() {
    // Jangan lakukan apapun jika sedang loading
    if (_isLoadMoreBeritaTerkini) return;

    setState(() {
      _isLoadMoreBeritaTerkini = true;
    });

    // Simulasi penundaan jaringan (AJAX call)
    Future.delayed(const Duration(milliseconds: 750), () {
      if (mounted) { // Pastikan widget masih ada di tree
        setState(() {
          _beritaTerkiniCount += 7; // Tambah 7 artikel lagi
          _isLoadMoreBeritaTerkini = false; // Selesai loading
        });
      }
    });
  }
  // --- AKHIR PERUBAHAN ---


  // --- 💡 PERBAIKAN: Menambahkan kembali 'dispose' yang hilang ---
  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _categoryScrollController.dispose();
    _shakeController.dispose();
    Provider.of<ArticleProvider>(context, listen: false)
        .removeListener(_onProviderUpdate);
    super.dispose();
  }
  // --- 💡 AKHIR PERBAIKAN ---

  Future<void> _showCategoryCustomizer() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CategoryCustomizerScreen(
          allCategories: _allCategories,
          selectedCategories: _selectedCategories,
        ),
      ),
    );

    if (result != null && result is List<String>) {
      setState(() {
        _selectedCategories = result;
      });
      await _saveSelectedCategories();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // --- AWAL PERUBAHAN: Dapatkan ThemeProvider di sini ---
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    // --- AKHIR PERUBAHAN ---
    final articleProvider = Provider.of<ArticleProvider>(context);
    final status = articleProvider.status;
    final articles = articleProvider.articles;
    final currentCategory = articleProvider.currentCategory;

    // 💡 PERUBAHAN: Logika untuk menentukan tampilan konten
    final isTopNews = currentCategory == 'Top News';
    final isAllNews = currentCategory == 'ALL_NEWS';
    // 💡 AKHIR PERUBAHAN

    return Scaffold(
      // backgroundColor: isDark ? Colors.black : Colors.white,
      // --- AWAL PERUBAHAN: Tambahkan drawer ---
      drawer: _buildAppDrawer(isDark),
      // --- AKHIR PERUBAHAN ---
      body: SafeArea(
        child: Column(
          children: [
            // --- AWAL PERUBAHAN: Ganti _buildHeader dengan _buildStickyHeader ---
            _buildStickyHeader(isDark, themeProvider),
            // _buildHeader(isDark), // <-- DIGANTI
            // --- AKHIR PERUBAHAN ---
            Divider(
              height: 1,
              thickness: 1,
              color: isDark ? Colors.grey[800] : Colors.grey[300],
            ),
            _buildCategoriesBar(articleProvider, isDark),
            Divider(
              height: 1,
              thickness: 1,
              color: isDark ? Colors.grey[800] : Colors.grey[300],
            ),
            Expanded(
              // 💡 PERUBAHAN: Mengirim state kategori baru
              child: _buildContent(status, articles, isDark, articleProvider,
                  isTopNews, isAllNews),
              // 💡 AKHIR PERUBAHAN
            ),
          ],
        ),
      ),
    );
  }

  // --- AWAL PERUBAHAN: _buildHeader diganti dengan _buildStickyHeader ---
  Widget _buildStickyHeader(bool isDark, ThemeProvider themeProvider) {
    // SVG untuk hamburger menu
    final String svgFillColor = isDark ? "white" : "black";
    final String svgIcon = '''
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M23 11H1C0.4 11 0 11.4 0 12C0 12.6 0.4 13 1 13H23C23.6 13 24 12.6 24 12C24 11.4 23.6 11 23 11Z" fill="$svgFillColor"></path>
      <path d="M12 6H23C23.6 6 24 5.6 24 5C24 4.4 23.6 4 23 4H12C11.4 4 11 4.4 11 5C11 5.6 11.4 6 12 6Z" fill="$svgFillColor"></path>
      <path d="M12 18H1C0.4 18 0 18.4 0 19C0 19.6 0.4 20 1 20H12C12.6 20 13 19.6 13 19C13 18.4 12.6 18 12 18Z" fill="$svgFillColor"></path>
      </svg>
    ''';

    return Container(
      height: 60,
      color: isDark ? Colors.black : Colors.white, // Latar belakang header
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Row(
        children: [
          // 1. Hamburger Menu
          Builder( // Builder diperlukan agar Scaffold.of(context) menemukan drawer
            builder: (context) {
              return IconButton(
                icon: SvgPicture.string(
                  svgIcon,
                  width: 24,
                  height: 24,
                ),
                // --- PERUBAHAN: Aksi klik hamburger diubah untuk membuka drawer ---
                onPressed: () => Scaffold.of(context).openDrawer(),
                // --- AKHIR PERUBAHAN ---
              );
            }
          ),

          // --- TAMBAHAN: Jarak antara hamburger dan logo ---
          const SizedBox(width: 8.0),
          // --- AKHIR TAMBAHAN ---

          // 2. Logo
          Image.asset(
            isDark
                ? 'assets/images/banner-owrite-black.jpg'
                : 'assets/images/banner-owrite-white.jpg',
            height: 44,
          ),

          // Spacer untuk mendorong item ke kanan
          const Spacer(),

          // 3. Tombol Search
          IconButton(
            icon: SvgPicture.string(
              '''
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
                <g id="Layer_63" data-name="Layer 63">
                  <path d="M53.08,51l-9.84-9.84c10.24-11.82,1.63-30.7-14.15-30.64a18.63,18.63,0,0,0-18.61,18.6c-.06,15.79,18.82,24.4,30.64,14.16L51,53.08A1.5,1.5,0,0,0,53.08,51ZM13.48,29.08a15.62,15.62,0,0,1,15.61-15.6c20.69.86,20.69,30.35,0,31.21A15.62,15.62,0,0,1,13.48,29.08Z"
                    fill="${isDark ? "white" : "black"}"/>
                </g>
              </svg>
              ''',
              width: 32,
              height: 32,
            ),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => SearchScreen(
                  bookmarkedArticles: widget.bookmarkedArticles,
                  onBookmarkToggle: widget.onBookmarkToggle,
                ),
              ));
            },
          ),

          // 4. Theme Toggle
          _buildThemeToggle(isDark, themeProvider),
        ],
      ),
    );
  }
  
  // --- AWAL TAMBAHAN: Drawer Kategori ---
  Widget _buildAppDrawer(bool isDark) {
    // _allCategories tersedia langsung di dalam state
    return Drawer(
      backgroundColor: isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
      // Memastikan tidak ada radius (non radius) sesuai permintaan
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Drawer
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 16.0), // Tambah padding atas
              child: Text(
                'Semua Kategori',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900, // Dibuat lebih tebal
                  fontFamily: 'Arimo',
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: isDark ? Colors.grey[800] : Colors.grey[300],
            ),
            // Daftar Kategori
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _allCategories.length, // Menggunakan _allCategories dari state
                itemBuilder: (context, index) {
                  final category = _allCategories[index];
                  final categoryCode = category['category'];
                  final categoryTitle = category['title'];

                  // --- AWAL PERUBAHAN: Tambahkan Column dan DottedDivider ---
                  return Column(
                    children: [
                      ListTile(
                        title: Text(
                          categoryTitle,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w500, // Sedikit lebih tebal
                          ),
                        ),
                        onTap: () {
                          // 1. Ganti kategori
                          Provider.of<ArticleProvider>(context, listen: false)
                              .changeCategory(categoryCode);
                          // 2. Tutup drawer
                          Navigator.of(context).pop();
                        },
                      ),
                      // Tambahkan divider titik-titik dengan jarak (indent)
                      DottedDivider(
                        color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                        height: 1,
                        indent: 16.0, // Jarak dari kiri
                        endIndent: 16.0, // Jarak dari kanan
                      ),
                    ],
                  );
                  // --- AKHIR PERUBAHAN ---
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  // --- AKHIR TAMBAHAN ---

  // Widget untuk toggle tema
  Widget _buildThemeToggle(bool isDark, ThemeProvider themeProvider) {
    return GestureDetector(
      onTap: () {
        themeProvider.toggleTheme();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 50,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.transparent, // polos/tidak berwarna
          border: Border.all(color: Colors.grey, width: 1),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 300),
          alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
          curve: Curves.easeInOut,
          child: Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent, // polos/tidak berwarna
              border: Border.all(color: Colors.grey, width: 1),
            ),
            child: Icon(
              isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
              size: 16,
              color: Colors.grey, // polos
            ),
          ),
        ),
      ),
    );
  }
  
  // --- FUNGSI _openAllCategories DIHAPUS karena digantikan drawer ---
  // void _openAllCategories() {
  //   Navigator.of(context).push(MaterialPageRoute(
  //     builder: (context) => AllCategoriesScreen(allCategories: _allCategories),
  //   ));
  // }
  // --- AKHIR PERUBAHAN ---

  // 💡 PERUBAHAN: Memperbarui logika keyString
  void _scrollToSelectedCategory(String? categoryCode) {
    final String keyString;
    if (categoryCode == 'Top News' || categoryCode == null) {
      keyString = 'top-news'; // ⬅️ Key untuk Top News
    } else if (categoryCode == 'ALL_NEWS') {
      keyString = 'all-news'; // ⬅️ Key untuk All News
    } else {
      keyString = categoryCode; // ⬅️ Key untuk kategori lain
    }
    // 💡 AKHIR PERUBAHAN

    final GlobalKey? key = _categoryKeys[keyString];

    if (key == null ||
        key.currentContext == null ||
        !_categoryScrollController.hasClients) return;

    final RenderBox? renderBox =
        key.currentContext!.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    // Hitung posisi target
    final position = renderBox.localToGlobal(Offset.zero);
    final viewportWidth = _categoryScrollController.position.viewportDimension;
    final itemWidth = renderBox.size.width;

    // Kita perlu offset item relatif terhadap area scroll
    // Global position - Global position of scroll area
    // Cara lebih mudah: Gunakan Scrollable.ensureVisible
    Scrollable.ensureVisible(
      key.currentContext!,
      alignment: 0.5, // 0.5 = tengah
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildCategoryItem(
    Map<String, dynamic> category,
    ArticleProvider provider,
    bool isDark,
  ) {
    // 💡 Variabel isAllNews dihapus karena tidak digunakan
    // 💡 Gunakan 'Top News' jika category null
    final categoryCode = category['category'] ?? 'Top News';
    final bool isSelected = provider.currentCategory == categoryCode;

    return GestureDetector(
      onTap: () {
        // 💡 Gunakan categoryCode
        provider.changeCategory(categoryCode);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8), // 🔑 lebih lega
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00FF00)
              : (isDark ? Colors.grey[900] : Colors.grey[200]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            category['title'] ?? 'Top News',
            overflow: TextOverflow.ellipsis, // 🔑 kalau teks panjang, kasih "..."
            style: TextStyle(
              color: isSelected
                  ? Colors.black
                  : (isDark ? Colors.white : Colors.black),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesBar(ArticleProvider provider, bool isDark) {
    // 💡 PERUBAHAN: Mendefinisikan Top News dan All News secara terpisah
    final Map<String, dynamic> topNewsCategory = {
      'title': 'Top News',
      'category': null, // 💡 category null akan diterjemahkan jadi 'Top News'
      'isAdd': false
    };

    final Map<String, dynamic> allBeritaCategory = {
      'title': 'All News',
      'category': 'ALL_NEWS', // 💡 Kode kategori baru
      'isAdd': false
    };
    // 💡 AKHIR PERUBAHAN

    final List<Map<String, dynamic>> customCategories =
        _selectedCategories.map((categoryCode) {
      return _allCategories.firstWhere(
        (cat) => cat['category'] == categoryCode,
        orElse: () => {'title': '', 'category': ''},
      );
    }).where((cat) => cat['title'] != '').toList();

    const double addButtonWidth = 56.0;

    return Container(
      height: 50,
      color: isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
      child: Stack(
        children: [
          Positioned.fill(
            child: Row(
              children: [
                Flexible(
                  child: Stack(
                    children: [
                      ReorderableListView.builder(
                        key: UniqueKey(), // 💡 Ganti key agar rebuild saat _selectedCategories berubah
                        scrollDirection: Axis.horizontal,
                        scrollController: _categoryScrollController,
                        buildDefaultDragHandles: false,
                        // 💡 PERUBAHAN: itemCount +2 (Top News & All News)
                        itemCount: customCategories.length + 2,
                        // 💡 AKHIR PERUBAHAN
                        // 💡 Tambah padding kiri untuk tombol Add
                        padding: const EdgeInsets.only(
                            left: addButtonWidth + 8.0,
                            top: 8,
                            bottom: 8,
                            right: 32),
                        proxyDecorator: _buildProxyDecorator,
                        onReorderStart: (index) =>
                            _shakeController.repeat(reverse: true),
                        onReorderEnd: (index) =>
                            _shakeController.stop(canceled: false),
                        onReorder: (oldIndex, newIndex) {
                          // 💡 PERUBAHAN: Lock "Top News" (0) dan "All News" (1)
                          if (oldIndex == 0 || oldIndex == 1) return;

                          // 💡 Cegah drop *ke* posisi "Top News" (0) atau "All News" (1)
                          if (newIndex == 0 || newIndex == 1) {
                            return;
                          }

                          // 💡 Panggil fungsi reorder dengan indeks yang disesuaikan (-2)
                          _onReorderCategory(oldIndex - 2, newIndex - 2);
                          // 💡 AKHIR PERUBAHAN
                        },
                        itemBuilder: (context, index) {
                          final String keyString;
                          final Map<String, dynamic> category;
                          final Widget categoryWidget;

                          // 💡 PERUBAHAN: Logika itemBuilder untuk 3 kondisi
                          if (index == 0) {
                            // 1. Top News
                            category = topNewsCategory;
                            keyString = 'top-news'; // ⬅️ Key unik
                          } else if (index == 1) {
                            // 2. All News
                            category = allBeritaCategory;
                            keyString = 'all-news'; // ⬅️ Key unik
                          } else {
                            // 3. Custom Categories
                            final categoryIndex = index - 2; // ⬅️ Disesuaikan

                            // 🚨 Safety Check (Fix RangeError)
                            if (categoryIndex < 0 ||
                                categoryIndex >= customCategories.length) {
                              // Ini tidak seharusnya terjadi, tapi sebagai pengaman
                              return SizedBox.shrink(key: UniqueKey());
                            }
                            category = customCategories[categoryIndex];
                            keyString = category['category'];
                          }
                          // 💡 AKHIR PERUBAHAN

                          // 🔑 Pastikan GlobalKey ada dan unik
                          if (!_categoryKeys.containsKey(keyString)) {
                            _categoryKeys[keyString] = GlobalKey();
                          }
                          final itemKey = _categoryKeys[keyString]!; // ⬅️ Gunakan GlobalKey

                          // Buat widget kategori
                          categoryWidget =
                              _buildCategoryItem(category, provider, isDark);

                          // 💡 PERUBAHAN: Logika untuk item non-draggable dan draggable

                          // 1. Handle "Top News" (0) dan "All News" (1) (tidak bisa di-drag)
                          if (index == 0 || index == 1) {
                            return Container(
                              key: itemKey, // ⬅️ Gunakan GlobalKey
                              child: categoryWidget, // Langsung return widget
                            );
                          }

                          // 2. Handle custom categories (index 2 dan seterusnya)
                          final Widget itemContent = Row(
                            key: ValueKey('row_${keyString}'), // Key untuk Row
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildSeparator(isDark), // ⬅️ Separator hanya di sini
                              categoryWidget,
                            ],
                          );

                          // 3. Buat item ini bisa di-drag
                          return ReorderableDelayedDragStartListener(
                            key: itemKey, // ⬅️ Key untuk Reorderable
                            index: index,
                            child: itemContent,
                          );
                          // 💡 AKHIR PERUBAHAN
                        },
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        width: 32,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerRight,
                              end: Alignment.centerLeft,
                              colors: [
                                isDark
                                    ? ThemeProvider.darkColor
                                    : ThemeProvider.lightColor,
                                (isDark
                                        ? ThemeProvider.darkColor
                                        : ThemeProvider.lightColor)
                                    .withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Gradient kiri (overlay)
          Positioned(
            left: 50, // 💡 Mulai setelah tombol Add
            top: 0,
            bottom: 0,
            width: 16, // 💡 Lebar gradient
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
                    (isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor)
                        .withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          // Tombol Add (di atas)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: addButtonWidth,
            child: Container(
              color: isDark
                  ? ThemeProvider.darkColor
                  : ThemeProvider.lightColor, // 💡 Samakan BG
              child: Center(
                child: GestureDetector(
                  onTap: _showCategoryCustomizer,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.add,
                      size: 20,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeparator(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Icon(
        Icons.more_vert,
        size: 16,
        color: isDark ? Colors.grey[600] : Colors.grey[400],
      ),
    );
  }

  // 💡 PERUBAHAN: Memperbarui tanda tangan metode
  Widget _buildContent(ArticleLoadingStatus status, List<Article> articles,
      bool isDark, ArticleProvider provider, bool isTopNews, bool isAllNews) {
    // 💡 AKHIR PERUBAHAN
    if (status == ArticleLoadingStatus.loading && articles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (status == ArticleLoadingStatus.error && articles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Gagal memuat artikel',
                style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => provider.refreshArticles(),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (articles.isEmpty) {
      return const Center(child: Text('Tidak ada artikel'));
    }

    // --- 💡 PERUBAHAN MINGGUAN: Acak artikel di sini ---
    // Gunakan list yang diacak secara mingguan HANYA untuk "Top News"
    // Jika tidak, gunakan list 'articles' biasa.
    // 💡 PERUBAHAN: Gunakan isTopNews
    final List<Article> displayArticles =
        isTopNews ? _getWeeklyShuffledArticles(articles) : articles;
    // 💡 AKHIR PERUBAHAN ---

    return RefreshIndicator(
      onRefresh: () async => await provider.refreshArticles(),
      color: const Color(0xFF00FF00),
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          // 💡 PERUBAHAN: Logika tampilan berdasarkan isTopNews, isAllNews
          if (isTopNews) ...[
            // Tampilan khusus "Top News"
            // 💡 PERUBAHAN: Popular section
            // Selalu tampilkan artikel terbaru (dari list asli), bukan yg diacak mingguan
            _buildPopularSection(articles, isDark),

            // --- AWAL PERUBAHAN: Ganti nama pemanggilan fungsi ---
            // 💡 PERUBAHAN: Must Read section
            // Gunakan list yg diacak mingguan (displayArticles)
            _buildBeritaTerkiniSection(displayArticles, isDark),
            // --- AKHIR PERUBAHAN ---

            /* Bagian "Temukan lebih banyak" dihapus sesuai permintaan
            const SizedBox(height: 32),

            // 💡 PERUBAHAN: Discover More section
            // Gunakan list asli (articles), shuffle akan terjadi di dalam method
            _buildDiscoverMoreSection(articles, isDark),
            */
            
            // --- AWAL BLOK TAMBAHAN ---
            // HAPUS BLOK 'Builder' YANG HARDCODED UNTUK POLITIK
            /*
            Builder(
              builder: (context) {
                // Ambil artikel politik dari daftar 'articles' (bukan 'displayArticles' yg diacak)
                // Kita asumsikan kategori 'Politik' ada di data
                final politikArticles = _getArticlesByCategory(articles, 'POLITIK');
                
                // Hanya tampilkan jika ada artikel
                if (politikArticles.isNotEmpty) {
                  return Column(
                    children: [
                      const SizedBox(height: 32),
                      _buildPoliticsSection(context, 'Politik', politikArticles, isDark),
                      const SizedBox(height: 32),
                      // Tambahkan divider seperti di search_screen
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: isDark ? Colors.grey[800] : Colors.grey[300],
                        ),
                      ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              }
            ),
            */
            // --- AKHIR BLOK TAMBAHAN ---

            // --- AWAL BLOK YANG DIKEMBALIKAN ---
            Builder(
              builder: (context) {
                // Ambil artikel politik dari daftar 'articles' (bukan 'displayArticles' yg diacak)
                // Kita asumsikan kategori 'Politik' ada di data
                final politikArticles = _getArticlesByCategory(articles, 'POLITIK');
                
                // Hanya tampilkan jika ada artikel
                if (politikArticles.isNotEmpty) {
                  return Column(
                    children: [
                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: isDark ? Colors.grey[800] : Colors.grey[300],
                        ),
                      ),
                      _buildCustomCategorySection(context, 'POLITIK', 'Politik', politikArticles, isDark),
                      const SizedBox(height: 32),
                      // Tambahkan divider seperti di search_screen
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: isDark ? Colors.grey[800] : Colors.grey[300],
                        ),
                      ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              }
            ),
            // --- AKHIR BLOK YANG DIKEMBALIKAN ---

            const SizedBox(height: 32),
            // Bagian "Terbaru" harus selalu pakai 'articles' asli (bukan yg diacak)
            _buildLatestSection(articles, isDark),
          ] else if (isAllNews) ...[
            // Tampilan "All News" (daftar semua artikel)
            // Gunakan 'articles' (daftar asli, bukan yg diacak)
            _buildCategoryArticlesList(articles, isDark),
          ] else ...[
            // Tampilan Kategori Lain (misal: HYPE, OLAHRAGA)
            // 'displayArticles' akan sama dengan 'articles' jika bukan "Top News"
            // (Provider sudah memfilter daftarnya)
            _buildCategoryArticlesList(displayArticles, isDark),
          ],
          // 💡 AKHIR PERUBAHAN
        ],
      ),
    );
  }

  Widget _buildCategoryLatestSection(
    Future<List<Article>>? future, // 💡 Terima Future
    String categoryCode, // 💡 Tetap terima code & title untuk tombol
    String categoryTitle, 
    bool isDark
  ) {
    
    // 💡 Gunakan FutureBuilder untuk mengambil data terpisah
    return FutureBuilder<List<Article>>(
      // 💡 Gunakan Future yang sudah stabil
      future: future,
      builder: (context, snapshot) {
        
        // --- Tampilan Judul (selalu tampil) ---
        final titleWidget = Text(
          categoryTitle,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            fontFamily: 'BG_Condensed',
            color: isDark ? Colors.white : Colors.black,
          ),
        );

        // 1. Saat Sedang Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleWidget,
              const SizedBox(height: 16),
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ],
          );
        }

        // 2. Jika Gagal (Error) atau Tidak Ada Data
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          String message = 'Belum ada artikel terbaru di $categoryTitle';
          if (snapshot.hasError) {
            message = 'Gagal memuat $categoryTitle';
            // Log error untuk debugging
            debugPrint("Error fetching latest for $categoryCode: ${snapshot.error}");
          }
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleWidget,
              const SizedBox(height: 16),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Text(
                    message, // Pesan error/kosong
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Divider(
                height: 1,
                thickness: 1,
                color: isDark ? Colors.grey[800] : Colors.grey[300],
              ),
              const SizedBox(height: 16),
              // 💡 Tombol 'Lihat Semua' tetap ada
              _buildLihatSemuaButton(context, categoryTitle, categoryCode, isDark),
            ],
          );
        }

        // 3. Jika Berhasil dan Ada Data
        final displayArticles = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleWidget, // Judul
            const SizedBox(height: 16),
            
            // --- Logika tampilan list (disalin dari kode asli) ---
            if (displayArticles.isNotEmpty)
              ArticleCard(
                article: displayArticles[0],
                isBookmarked: widget.bookmarkedArticles
                    .any((b) => b.id == displayArticles[0].id),
                onBookmarkToggle: () => widget.onBookmarkToggle(displayArticles[0]),
                index: 0,
                layout: ArticleCardLayout.defaultCard,
              ),
            if (displayArticles.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: DottedDivider(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  indent: 0,
                  endIndent: 0,
                ),
              ),
            if (displayArticles.length > 1)
              ArticleCard(
                article: displayArticles[1],
                isBookmarked: widget.bookmarkedArticles
                    .any((b) => b.id == displayArticles[1].id),
                onBookmarkToggle: () => widget.onBookmarkToggle(displayArticles[1]),
                index: 1,
                layout: ArticleCardLayout.layout1,
              ),
            if (displayArticles.length > 2)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: DottedDivider(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  indent: 0,
                  endIndent: 0,
                ),
              ),
            if (displayArticles.length > 2)
              ArticleCard(
                article: displayArticles[2],
                isBookmarked: widget.bookmarkedArticles
                    .any((b) => b.id == displayArticles[2].id),
                onBookmarkToggle: () => widget.onBookmarkToggle(displayArticles[2]),
                index: 2,
                layout: ArticleCardLayout.layout1,
              ),
            
            const SizedBox(height: 16),
            Divider(
              height: 1,
              thickness: 1,
              color: isDark ? Colors.grey[800] : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            // 💡 Tombol 'Lihat Semua'
            _buildLihatSemuaButton(context, categoryTitle, categoryCode, isDark),
          ],
        );
      },
    );
  }

  // 💡 BUAT FUNGSI HELPER BARU untuk tombol 'Lihat Semua'
  // Ini membersihkan kode dan mengubah logika navigasi
  Widget _buildLihatSemuaButton(BuildContext context, String categoryTitle, String categoryCode, bool isDark) {
    return GestureDetector(
      onTap: () {
        // 💡 KEMBALIKAN LOGIKA: Buka halaman baru 'CategoryLatestScreen'
        // Halaman ini akan mengambil datanya sendiri.
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                CategoryLatestScreen(
              categoryTitle: categoryTitle,
              categoryCode: categoryCode,
              // 💡 'articles' dihapus, CategoryLatestScreen akan fetch sendiri
              bookmarkedArticles: widget.bookmarkedArticles,
              onBookmarkToggle: widget.onBookmarkToggle,
            ),
            // Animasi slide-in dari atas (sesuai permintaan user sebelumnya)
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              const begin = Offset(0.0, -1.0); // dari atas ke bawah
              const end = Offset.zero;
              const curve = Curves.easeInOut;
              var tween = Tween(begin: begin, end: end)
                  .chain(CurveTween(curve: curve));
              var offsetAnimation = animation.drive(tween);
              return SlideTransition(
                  position: offsetAnimation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Lihat Semua',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFe5ff10), // circle color: green
                ),
                child: Center(
                  child: Builder(
                    builder: (context) {
                      final isDark =
                          Theme.of(context).brightness == Brightness.dark;
                      return IconTheme(
                        data: IconThemeData(
                          size: 20,
                          color: isDark ? Colors.black : Colors.white,
                        ),
                        child: SvgPicture.string(
                          '''
                            <svg clip-rule="evenodd" fill-rule="evenodd" stroke-linejoin="round" stroke-miterlimit="2" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                              <path d="m12.012 1.995c-5.518 0-9.998 4.48-9.998 9.998s4.48 9.998 9.998 9.998 9.997-4.48 9.997-9.998-4.479-9.998-9.997-9.998zm0 1.5c4.69 0 8.497 3.808 8.497 8.498s-3.807 8.498-8.497 8.498-8.498-3.808-8.498-8.498 3.808-8.498 8.498-8.498zm1.528 4.715s1.502 1.505 3.255 3.259c.146.147.219.339.219.531s-.073.383-.219.53c-1.753 1.754-3.254 3.258-3.254 3.258-.145.145-.336.217-.527.217-.191-.001-.383-.074-.53-.221-.293-.293-.295-.766-.004-1.057l1.978-1.977h-6.694c-.414 0-.75-.336-.75-.75s.336-.75.75-.75h6.694l-1.979-1.979c-.289-.289-.286-.762.006-1.054.147-.147.339-.221.531-.222.19 0 .38.071.524.215z" fill="${isDark ? '#000000' : '#ffffff'}" fill-rule="nonzero"/>
                            </svg>
                          ''',
                          height: 20,
                          width: 20,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildCategoryArticlesList(List<Article> articles, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          ...articles.asMap().entries.map((entry) {
            final index = entry.key;
            final article = entry.value;
            final isBookmarked =
                widget.bookmarkedArticles.any((b) => b.id == article.id);

            return ArticleCard(
              article: article,
              isBookmarked: isBookmarked,
              onBookmarkToggle: () => widget.onBookmarkToggle(article),
              index: index,
              layout: ArticleCardLayout.defaultCard,
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildPopularSection(List<Article> articles, bool isDark) {
    final popularArticles = _getPopularArticles(articles);
    if (popularArticles.isEmpty) return const SizedBox.shrink();

    final article = popularArticles.first;
    final isBookmarked =
        widget.bookmarkedArticles.any((b) => b.id == article.id);

    return ArticleCard(
      article: article,
      isBookmarked: isBookmarked,
      onBookmarkToggle: () => widget.onBookmarkToggle(article),
      index: 0,
      layout: ArticleCardLayout.layout3,
    );
  }

  // --- AWAL PERUBAHAN: Modifikasi besar pada _buildMustReadSection ---
  Widget _buildBeritaTerkiniSection(List<Article> articles, bool isDark) {
    // 'articles' di sini adalah 'displayArticles' (shuffled list) dari _buildContent
    
    // Ambil *semua* artikel yang tersedia untuk pengecekan 'hasMore'
    final allBeritaTerkini = articles.skip(1).toList();
    
    // Ambil hanya sejumlah '_beritaTerkiniCount' untuk ditampilkan
    final displayArticles = allBeritaTerkini.take(_beritaTerkiniCount).toList();

    // Cek apakah masih ada artikel tersisa di 'allBeritaTerkini'
    final bool hasMore = allBeritaTerkini.length > _beritaTerkiniCount;

    if (displayArticles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: Text(
            'Belum ada artikel pilihan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Berita Terkini', // <-- Judul diubah
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              fontFamily: 'Arimo',
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 24),
          // Tampilkan list artikel (sejumlah _beritaTerkiniCount)
          ...displayArticles.asMap().entries.map((entry) {
            final index = entry.key;
            final article = entry.value;
            final isBookmarked =
                widget.bookmarkedArticles.any((b) => b.id == article.id);

            return Column(
              children: [
                ArticleCard(
                  article: article,
                  isBookmarked: isBookmarked,
                  onBookmarkToggle: () => widget.onBookmarkToggle(article),
                  index: index,
                  layout: ArticleCardLayout.layout1,
                ),
                if (index < displayArticles.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: DottedDivider(
                      color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                      indent: 0,
                      endIndent: 0,
                    ),
                  ),
              ],
            );
          }).toList(),

          // --- Tambahan Tombol Load More ---
          const SizedBox(height: 24), // Spasi sebelum tombol
          if (_isLoadMoreBeritaTerkini) ...[
            // 1. Tampilkan Indikator Loading
            Center(
              child: SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_loadMoreColor),
                  strokeWidth: 3,
                ),
              ),
            ),
          ] else if (hasMore) ...[
            // 2. Tampilkan Tombol "Muat Lebih Banyak"
            Center(
              child: ElevatedButton(
                onPressed: _loadMoreBeritaTerkini, // Panggil fungsi handler
                style: ElevatedButton.styleFrom(
                  backgroundColor: _loadMoreColor, // Warna background
                  foregroundColor: Colors.black, // Warna teks
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20), // Shape radius
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text(
                  'Muat Lebih Banyak', // Teks tombol
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
          // --- Akhir Tambahan Tombol Load More ---
        ],
      ),
    );
  }
  // --- AKHIR PERUBAHAN ---

  Widget _buildDiscoverMoreSection(List<Article> articles, bool isDark) {
    // 💡 PERUBAHAN: Ambil list asli, skip, lalu shuffle (random per session)
    final discoverMoreArticles = _getDiscoverMoreArticles(articles);
    discoverMoreArticles.shuffle(Random());
    // 💡 AKHIR PERUBAHAN

    if (discoverMoreArticles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: Text(
            'Belum ada artikel lainnya',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final displayArticles = discoverMoreArticles.take(10).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Temukan lebih banyak',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              fontFamily: 'Arimo',
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 24),
          ...displayArticles.asMap().entries.map((entry) {
            final index = entry.key;
            final article = entry.value;
            final isBookmarked =
                widget.bookmarkedArticles.any((b) => b.id == article.id);

            return ArticleCard(
              article: article,
              isBookmarked: isBookmarked,
              onBookmarkToggle: () => widget.onBookmarkToggle(article),
              index: index,
              layout: ArticleCardLayout.defaultCard,
            );
          }).toList(),
        ],
      ),
    );
  }
  
  // --- TAMBAHKAN FUNGSI INI ---
  // Widget ini disalin dari search_screen.dart untuk membuat card kustom
  // yang sesuai dengan tampilan di halaman pencarian.
  Widget _buildCategoryArticleCard(BuildContext context, Article article, bool isDark) {
    return GestureDetector(
      onTap: () => _openArticle(article), // Memanggil _openArticle yang baru ditambahkan
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gambar
            SizedBox(
              height: 160,
              width: double.infinity,
              child: article.urlToImage != null
                  ? CachedNetworkImage(
                      imageUrl: article.urlToImage!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: isDark ? Colors.grey[800] : Colors.grey[300],
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: isDark ? Colors.grey[800] : Colors.grey[300],
                        child: Icon(Icons.image_not_supported,
                            color: isDark ? Colors.grey[600] : Colors.grey[400], size: 40),
                      ),
                    )
                  : Container(
                      color: isDark ? Colors.grey[800] : Colors.grey[300],
                      child: Icon(Icons.image_not_supported,
                          color: isDark ? Colors.grey[600] : Colors.grey[400], size: 40),
                    ),
            ),

            // Judul di luar gambar dengan background sesuai tema
            Container(
              width: double.infinity,
              color: isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
              padding: const EdgeInsets.all(8),
              child: Text(
                article.title,
                style: TextStyle(
                  fontFamily: 'Arimo',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                  height: 1.3,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
  // --- AKHIR PENAMBAHAN ---
  
  // --- AWAL PERUBAHAN: FUNGSI _buildCustomCategorySection DIPERBARUI ---
  // Widget ini diubah agar sesuai dengan tampilan slide di search_screen.dart
  Widget _buildCustomCategorySection(BuildContext context, String categoryCode, String categoryTitle, List<Article> articles, bool isDark) {
    
    return Padding( // <-- Padding luar 24.0 dipertahankan
      padding: const EdgeInsets.symmetric(horizontal: 24.0), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // <-- DITAMBAHKAN
            children: [
              Text(
                categoryTitle, // <-- Gunakan parameter categoryTitle
                style: TextStyle(
                  fontFamily: 'Arimo', // <-- Font dari file asli
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),

              // --- Tombol More di-aktifkan ---
              GestureDetector(
                onTap: () => _navigateToSeeAll(categoryTitle, articles), // <-- Navigasi disesuaikan ke _navigateToSeeAll
                child: Row(
                  children: [
                    Text(
                      'More',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCCFF00),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: isDark ? Colors.black : Colors.white, // <-- Sesuai search_screen.dart
                      ),
                    ),
                  ],
                ),
              ),
              // --- Akhir Tombol More ---
            ],
          ),
          const SizedBox(height: 12), // <-- Spasi dikurangi (sesuai search_screen)
          
          // --- BAGIAN YANG DIUBAH (Meniru search_screen) ---
          SizedBox(
            height: 240, // <-- Tinggi slider dari search_screen
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              // List dimulai dari tepi (padding 24.0 sudah ada di luar)
              padding: EdgeInsets.zero, 
              itemCount: articles.length, // <-- Ambil semua artikel
              itemBuilder: (context, index) {
                final article = articles[index];
                // Panggil card kustom dari search_screen
                // yang sudah ada di home_screen
                return _buildCategoryArticleCard(context, article, isDark);
              },
            ),
          ),
          // --- AKHIR BAGIAN YANG DIUBAH ---
        ],
      ),
    );
  }
  // --- AKHIR PERUBAHAN ---

  // --- 💡 PERUBAHAN: Logika untuk menentukan kategori dinamis ---
  Widget _buildLatestSection(List<Article> articles, bool isDark) {
    Map<String, dynamic> category1;
    Map<String, dynamic>? category2;

    // Prioritas 1: Gunakan _dailyCategory1 jika ada
    if (_dailyCategory1 != null) {
      category1 = _dailyCategory1!;
      // Prioritas 2: Gunakan _dailyCategory2 jika ada DAN BEDA
      if (_dailyCategory2 != null &&
          _dailyCategory2!['category'] != category1['category']) {
        category2 = _dailyCategory2!;
      } else {
        // _dailyCategory2 null atau sama, cari fallback
        // Fallback 1: 'NASIONAL' jika beda
        if (category1['category'] != 'NASIONAL') {
          category2 = {'title': 'Nasional', 'category': 'NASIONAL'};
        } else {
          // Fallback 2: 'INTERNASIONAL' (pasti beda)
          category2 = {'title': 'Internasional', 'category': 'INTERNASIONAL'};
        }
      }
    } else {
      // _dailyCategory1 null, gunakan default
      category1 = {'title': 'Nasional', 'category': 'NASIONAL'};
      // Cek _dailyCategory2. Jika ada dan BEDA, pakai.
      if (_dailyCategory2 != null &&
          _dailyCategory2!['category'] != 'NASIONAL') {
        category2 = _dailyCategory2!;
      } else {
        // _dailyCategory2 null atau sama, pakai default kedua
        category2 = {'title': 'Internasional', 'category': 'INTERNASIONAL'};
      }
    }

    // 💡 PERUBAHAN: Inisialisasi atau perbarui Future HANYA jika kategori berubah
    // Logika ini memastikan future hanya dibuat sekali per kategori,
    // atau ketika kategori harian berganti.
    if (category1['category'] != _latestCategory1Code || _latestCategory1Future == null) {
      _latestCategory1Code = category1['category']!;
      _latestCategory1Future = _articleRepository.getArticlesByCategory(
        _latestCategory1Code!,
        page: 1,
        pageSize: 3,
      );
    }

    if (category2 != null && (category2['category'] != _latestCategory2Code || _latestCategory2Future == null)) {
      _latestCategory2Code = category2['category']!;
      _latestCategory2Future = _articleRepository.getArticlesByCategory(
        _latestCategory2Code!,
        page: 1,
        pageSize: 3,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Terbaru',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              fontFamily: 'BG_Condensed',
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 24),

          // Kategori 1 (Pasti ada, dinamis atau default)
          _buildCategoryLatestSection(
              _latestCategory1Future, // 💡 Kirim Future
              category1['category']!,
              category1['title']!, 
              isDark),

          const SizedBox(height: 32),

          // Kategori 2 (Pasti ada, dinamis atau default)
          _buildCategoryLatestSection(
              _latestCategory2Future, // 💡 Kirim Future
              category2!['category']!, // category2 dijamin non-null di sini
              category2['title']!, 
              isDark),
        ],
      ),
    );
  }
  // --- 💡 AKHIR PERUBAHAN ---
}

// --- AWAL PERUBAHAN: Widget AllCategoriesScreen DIHAPUS karena digantikan oleh Drawer ---
// class AllCategoriesScreen extends StatelessWidget {
//   final List<Map<String, dynamic>> allCategories;
// 
//   const AllCategoriesScreen({Key? key, required this.allCategories}) : super(key: key);
// 
//   @override
//   Widget build(BuildContext context) {
//     final themeProvider = Provider.of<ThemeProvider>(context);
//     final isDark = themeProvider.isDarkMode;
// 
//     return Scaffold(
//       backgroundColor: isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
//       appBar: AppBar(
//         title: const Text('Semua Kategori'),
//         backgroundColor: isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
//         foregroundColor: isDark ? Colors.white : Colors.black,
//         elevation: 0,
//       ),
//       body: ListView.builder(
//         itemCount: allCategories.length,
//         itemBuilder: (context, index) {
//           final category = allCategories[index];
//           final categoryCode = category['category'];
//           final categoryTitle = category['title'];
// 
//           return ListTile(
//             title: Text(
//               categoryTitle,
//               style: TextStyle(color: isDark ? Colors.white : Colors.black),
//             ),
//             onTap: () {
//               // Ganti kategori di provider
//               Provider.of<ArticleProvider>(context, listen: false).changeCategory(categoryCode);
//               // Tutup halaman
//               Navigator.of(context).pop();
//             },
//           );
//         },
//       ),
//     );
//   }
// }
// --- AKHIR PERUBAHAN ---

class DottedDivider extends StatelessWidget {
  final double height;
  final Color color;
  final double indent;
  final double endIndent;

  const DottedDivider({
    Key? key,
    this.height = 1,
    this.color = Colors.grey,
    this.indent = 16,
    this.endIndent = 16,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth() - indent - endIndent;
        const dashWidth = 1.0;
        const dashSpace = 3.0;
        final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();

        return Padding(
          padding:
              EdgeInsets.only(left: indent, right: endIndent, top: 8, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(dashCount, (_) {
              return SizedBox(
                width: dashWidth,
                height: height,
                child: DecoratedBox(decoration: BoxDecoration(color: color)),
              );
            }),
          ),
        );
      },
    );
  }
}

// 💡 UBAH: Menjadi StatefulWidget agar bisa mengambil data sendiri
class CategoryLatestScreen extends StatefulWidget {
  final String categoryTitle;
  final String categoryCode;
  // final List<Article> articles; // 💡 Dihapus
  final List<Article> bookmarkedArticles;
  final Function(Article) onBookmarkToggle;

  const CategoryLatestScreen({
    Key? key,
    required this.categoryTitle,
    required this.categoryCode,
    // required this.articles, // 💡 Dihapus
    required this.bookmarkedArticles,
    required this.onBookmarkToggle,
  }) : super(key: key);

  @override
  State<CategoryLatestScreen> createState() => _CategoryLatestScreenState();
}

class _CategoryLatestScreenState extends State<CategoryLatestScreen> {
  // 💡 State untuk menampung data yang di-fetch
  late Future<List<Article>> _articlesFuture;
  final ArticleRepository _repository = ArticleRepository(); // Repository

  @override
  void initState() {
    super.initState();
    // 💡 Panggil fetch saat widget pertama kali dibuat
    _articlesFuture = _repository.getArticlesByCategory(
      widget.categoryCode,
      page: 1,
      pageSize: 50, // Ambil 50 artikel untuk "Lihat Semua"
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
      appBar: AppBar(
        backgroundColor:
            isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
        foregroundColor: isDark ? Colors.white : Colors.black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.categoryTitle, // 💡 Ambil dari widget
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'CrimsonPro',
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        // 💡 Tombol kembali akan muncul otomatis
      ),
      body: SafeArea(
        // 💡 Gunakan FutureBuilder untuk menampilkan data
        child: FutureBuilder<List<Article>>(
          future: _articlesFuture,
          builder: (context, snapshot) {
            // 1. Loading
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // 2. Error
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Gagal memuat artikel',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              );
            }

            // 3. Data Kosong
            final articles = snapshot.data;
            if (articles == null || articles.isEmpty) {
              return Center(
                child: Text(
                  'Tidak ada artikel',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              );
            }

            // 4. Sukses, tampilkan list
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: articles.length,
              itemBuilder: (context, index) {
                final article = articles[index];
                final isBookmarked =
                    widget.bookmarkedArticles.any((b) => b.id == article.id); // 💡 Ambil dari widget

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ArticleCard(
                    article: article,
                    isBookmarked: isBookmarked,
                    onBookmarkToggle: () => widget.onBookmarkToggle(article), // 💡 Ambil dari widget
                    index: index,
                    layout: ArticleCardLayout.defaultCard,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class SeeAllArticlesScreen extends StatelessWidget {
  final String title;
  final List<Article> articles;
  final List<Article> bookmarkedArticles;
  final Function(Article) onBookmarkToggle;

  const SeeAllArticlesScreen({
    Key? key,
    required this.title,
    required this.articles,
    required this.bookmarkedArticles,
    required this.onBookmarkToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
      appBar: AppBar(
        backgroundColor:
            isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
        foregroundColor: isDark ? Colors.white : Colors.black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'CrimsonPro',
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
      body: SafeArea(
        child: articles.isEmpty
            ? const Center(child: Text('Tidak ada artikel'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: articles.length,
                itemBuilder: (context, index) {
                  final article = articles[index];
                  final isBookmarked =
                      bookmarkedArticles.any((b) => b.id == article.id);

                  return ArticleCard(
                    article: article,
                    isBookmarked: isBookmarked,
                    onBookmarkToggle: () => onBookmarkToggle(article),
                    index: index,
                    layout: ArticleCardLayout.defaultCard,
                  );
                },
              ),
      ),
    );
  }
}

class CategoryCustomizerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> allCategories;
  final List<String> selectedCategories;

  const CategoryCustomizerScreen({
    Key? key,
    required this.allCategories,
    required this.selectedCategories,
  }) : super(key: key);

  @override
  State<CategoryCustomizerScreen> createState() =>
      _CategoryCustomizerScreenState();
}

class _CategoryCustomizerScreenState extends State<CategoryCustomizerScreen> {
  late List<String> _tempSelectedCategories;

  @override
  void initState() {
    super.initState();
    _tempSelectedCategories = List.from(widget.selectedCategories);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor =
        isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor;
    final textColor = isDark ? Colors.white : Colors.black;
    final cardColor = isDark ? Colors.grey[900] : Colors.white;
    final borderColor = isDark ? Colors.grey[700] : Colors.grey[300];
    final selectedColor = const Color(0xFF00FF00);
    final checkIconColor = Colors.black;
    final addIconColor = isDark ? Colors.grey[400] : Colors.grey;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Sesuaikan Kategori',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: textColor,
          ),
          textAlign: TextAlign.center,
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.allCategories.map((category) {
                  final categoryCode = category['category'] as String;
                  final isSelected =
                      _tempSelectedCategories.contains(categoryCode);

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _tempSelectedCategories.remove(categoryCode);
                        } else {
                          _tempSelectedCategories.add(categoryCode);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: isSelected ? selectedColor : borderColor!,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? selectedColor
                                  : Colors.transparent,
                              border: Border.all(
                                color: isSelected
                                    ? selectedColor
                                    : addIconColor!,
                                width: 1.5,
                              ),
                            ),
                            child: isSelected
                                ? Icon(
                                    Icons.check,
                                    size: 14,
                                    color: checkIconColor,
                                  )
                                : Icon(
                                    Icons.add,
                                    size: 14,
                                    color: addIconColor,
                                  ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            category['title'],
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: backgroundColor,
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.white : Colors.black)
                      .withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(_tempSelectedCategories);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: textColor,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Simpan Preferensi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}