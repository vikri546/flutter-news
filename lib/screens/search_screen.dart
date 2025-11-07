import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/article.dart';
import '../widgets/article_card.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/error_view.dart';
import '../providers/article_provider.dart';
import '../screens/article_detail_screen.dart';
import '../utils/custom_page_transitions.dart';
import '../providers/language_provider.dart';
import '../utils/strings.dart';
import '../utils/auth_service.dart';
import '../screens/login_screen.dart';
import '../providers/theme_provider.dart';

class SearchScreen extends StatefulWidget {
  final List<Article> bookmarkedArticles;
  final Function(Article) onBookmarkToggle;

  const SearchScreen({
    Key? key,
    required this.bookmarkedArticles,
    required this.onBookmarkToggle,
  }) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  // Variabel baru untuk mengontrol visibilitas kursor
  bool _showCursor = false;

  final List<String> _searchRecommendations = [
    'Politik',
    'Ekonomi',
    'Olahraga',
    'Teknologi',
    'Hukum',
    'Kesehatan',
  ];
  
  List<String> _searchHistory = [];
  bool _isTyping = false;
  List<Article> _mostPopularArticles = [];
  Map<String, List<Article>> _categorizedArticles = {};
  List<Article> _topStoriesArticles = [];
  bool _isLoggedIn = false;
  
  Timer? _debounce;
  List<Article> _liveResults = [];
  bool _isSearching = false;
  
  // Slider variables
  late PageController _sliderPageController;
  int _currentSliderPage = 0;
  Timer? _sliderTimer;
  AnimationController? _progressAnimationController;
  
  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadSearchHistory();
    _checkLoginStatus();

    // Tambahkan listener untuk FocusNode
    _searchFocusNode.addListener(_onFocusChange);
    
    // Initialize slider
    _sliderPageController = PageController();
    _progressAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    
    _progressAnimationController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextSliderPage();
      }
    });
    
    // Load articles first, then start slider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadArticlesByCategory();
    });
  }

  // Fungsi baru untuk menangani perubahan fokus
  void _onFocusChange() {
    if (mounted) {
      setState(() {
        _showCursor = _searchFocusNode.hasFocus;
      });
    }
  }
  
  Future<void> _checkLoginStatus() async {
    final authService = AuthService();
    final user = await authService.getCurrentUser();
    setState(() {
      _isLoggedIn = user != null && user['username'] != 'Guest';
    });
  }
  
  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _searchHistory = prefs.getStringList('search_history') ?? [];
    });
  }
  
  Future<void> _saveSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('search_history', _searchHistory);
  }
  
  void _loadArticlesByCategory() {
    final articleProvider = Provider.of<ArticleProvider>(context, listen: false);
    if (articleProvider.articles.isNotEmpty) {
      if (mounted) {
        setState(() {
          // Top Stories - ambil 5 artikel random untuk slider
          var randomArticles = List<Article>.from(articleProvider.articles);
          randomArticles.shuffle();
          _topStoriesArticles = randomArticles.take(5).toList();
          
          // Most Popular - ambil 5 artikel random
          var allArticles = List<Article>.from(articleProvider.articles);
          allArticles.shuffle();
          _mostPopularArticles = allArticles.take(5).toList();
          
          // Kategorikan artikel
          _categorizedArticles.clear();
          for (var category in _searchRecommendations) {
            var categoryArticles = articleProvider.articles
                .where((article) => article.category.toLowerCase() == category.toLowerCase())
                .take(5)
                .toList();
            if (categoryArticles.isNotEmpty) {
              _categorizedArticles[category] = categoryArticles;
            }
          }
        });
        
        // Start animation after data loaded
        if (_topStoriesArticles.isNotEmpty) {
          _progressAnimationController?.forward();
          _startAutoSlider();
        }
      }
    }
  }
  
  void _startAutoSlider() {
    // Cancel existing timer
    _sliderTimer?.cancel();
    
    // Don't use Timer.periodic, instead rely on animation controller
  }
  
  void _nextSliderPage() {
    if (!mounted || _progressAnimationController == null || _topStoriesArticles.isEmpty) return;
    
    int nextPage = (_currentSliderPage + 1) % _topStoriesArticles.length;
    
    _sliderPageController.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    ).then((_) {
      if (mounted) {
        setState(() {
          _currentSliderPage = nextPage;
        });
        _progressAnimationController!.reset();
        _progressAnimationController!.forward();
      }
    });
  }
  
  void _onSliderPageChanged(int index) {
    if (!mounted || _progressAnimationController == null) return;
    
    setState(() {
      _currentSliderPage = index;
    });
    
    _progressAnimationController!.reset();
    _progressAnimationController!.forward();
  }
  
  void _addToSearchHistory(String query) {
    if (query.trim().isEmpty) return;
    
    setState(() {
      _searchHistory.removeWhere((item) => item.toLowerCase() == query.toLowerCase());
      _searchHistory.insert(0, query);
      if (_searchHistory.length > 10) {
        _searchHistory = _searchHistory.sublist(0, 10);
      }
    });
    
    _saveSearchHistory();
  }
  
  void _clearSearchHistory() async {
    setState(() => _searchHistory.clear());
    _saveSearchHistory();
  }
  
  void _onSearchChanged() {
    final query = _searchController.text;
    
    if (mounted) setState(() => _isTyping = query.isNotEmpty);
    
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    if (query.isEmpty) {
      if (mounted) setState(() { _liveResults = []; _isSearching = false; });
      return;
    }
    
    if (mounted) setState(() => _isSearching = true);
    
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performLiveSearch(query);
    });
  }
  
  void _performLiveSearch(String query) {
    if (query.trim().isEmpty) return;
    
    final articleProvider = Provider.of<ArticleProvider>(context, listen: false);
    final allArticles = articleProvider.articles;
    
    final results = allArticles.where((article) {
      final titleLower = article.title.toLowerCase();
      final descLower = (article.description ?? '').toLowerCase();
      final authorLower = (article.author ?? '').toLowerCase();
      final categoryLower = article.category.toLowerCase();
      final queryLower = query.toLowerCase();
      
      return titleLower.contains(queryLower) ||
             descLower.contains(queryLower) ||
             authorLower.contains(queryLower) ||
             categoryLower.contains(queryLower);
    }).toList();
    
    if (mounted) {
      setState(() {
        _liveResults = results;
        _isSearching = false;
      });
    }
  }
  
  void _performSearch(String query) {
    if (query.trim().isNotEmpty) {
      _addToSearchHistory(query);
      _performLiveSearch(query);
      FocusScope.of(context).unfocus();
    }
  }
  
  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    
    // Hapus listener dari FocusNode
    _searchFocusNode.removeListener(_onFocusChange);
    _searchFocusNode.dispose();
    
    _debounce?.cancel();
    _sliderTimer?.cancel();
    _sliderPageController.dispose();
    _progressAnimationController?.dispose();
    super.dispose();
  }
  
  void _selectRecommendation(String recommendation) {
    _searchController.text = recommendation;
    _searchController.selection = TextSelection.fromPosition(TextPosition(offset: _searchController.text.length));
    _performSearch(recommendation);
  }
  
  void _openArticle(Article article) {
    final heroTag = 'search-article-${article.id}';
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
  
  void _navigateToCategory(String category, List<Article> articles) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CategoryArticlesScreen(
          category: category,
          articles: articles,
          bookmarkedArticles: widget.bookmarkedArticles,
          onBookmarkToggle: widget.onBookmarkToggle,
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings(context.watch<LanguageProvider>().locale.languageCode);
    
    return Scaffold(
      backgroundColor: isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
      appBar: AppBar(
        backgroundColor: isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
        foregroundColor: isDark ? Colors.white : Colors.black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Padding(
          padding: const EdgeInsets.only(top: 10.0, bottom: 10.0), // padding atas & bawah setelah boxdecoration
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
              border: Border.all(
                color: isDark ? ThemeProvider.lightColor : ThemeProvider.darkColor,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(5),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              autofocus: false, // <-- DIUBAH
              showCursor: _showCursor, // <-- DITAMBAHKAN
              decoration: InputDecoration(
                hintText: '${strings.search}...',
                border: InputBorder.none,
                prefixIcon: Icon(
                  Icons.search,
                  color: isDark ? Colors.white70 : Colors.black54,
                  size: 20,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                hintStyle: TextStyle(
                  fontFamily: 'SourceSerif4',
                  color: isDark ? Colors.white54 : Colors.black45,
                  fontSize: 14,
                ),
              ),
              style: TextStyle(
                fontFamily: 'SourceSerif4',
                color: isDark ? Colors.white : Colors.black,
                fontSize: 14,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: _performSearch,
            ),
          ),
        ),
        actions: [
          if (_isTyping)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () {
                _searchController.clear();
              },
            ),
        ],
      ),
      body: Consumer<ArticleProvider>(
        builder: (context, articleProvider, child) {
          if (_categorizedArticles.isEmpty && articleProvider.articles.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadArticlesByCategory();
            });
          }
          
          // Mode Searching
          if (_isTyping && _liveResults.isNotEmpty) {
            return Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.grey[50],
                    border: Border(bottom: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!, width: 1)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.filter_list, size: 16, color: isDark ? Colors.white70 : Colors.black54),
                      const SizedBox(width: 8),
                      Text(
                        '${_liveResults.length} artikel ditemukan',
                        style: TextStyle(fontFamily: 'SourceSerif4', fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.black54),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: _liveResults.length,
                    itemBuilder: (context, index) {
                      final article = _liveResults[index];
                      final isBookmarked = widget.bookmarkedArticles.any((a) => a.id == article.id);
                      
                      return ArticleCard(
                        article: article,
                        isBookmarked: isBookmarked,
                        onBookmarkToggle: () => widget.onBookmarkToggle(article),
                        index: index,
                        layout: ArticleCardLayout.layout1, // ✅ Gunakan layout1 untuk hasil pencarian
                      );
                    },
                  ),
                ),
              ],
            );
          }
          
          if (_isTyping && _isSearching) {
            return Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.grey[50],
                    border: Border(bottom: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!, width: 1)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(isDark ? Colors.white70 : Colors.black54),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Mencari...',
                        style: TextStyle(fontFamily: 'SourceSerif4', fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.black54),
                      ),
                    ],
                  ),
                ),
                Expanded(child: ShimmerLoading(isDark: isDark)),
              ],
            );
          }
          
          if (_isTyping && _liveResults.isEmpty && !_isSearching) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Tidak Ada Hasil',
                      style: TextStyle(fontFamily: 'SourceSerif4', fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Coba gunakan kata kunci lain',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'SourceSerif4', fontSize: 14, color: isDark ? Colors.white70 : Colors.black54, height: 1.5),
                    ),
                  ],
                ),
              ),
            );
          }
          
          // Default View - Discover Mode
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Stories Slider
                if (_topStoriesArticles.isNotEmpty) 
                  _buildTopStoriesSlider(context, isDark),
                
                // Login Form (jika belum login)
                if (!_isLoggedIn)
                  _buildLoginForm(context, isDark),
                
                // Divider after slider/login form
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: _buildSolidDivider(isDark),
                ),
                
                // Category Sections with horizontal scroll (before Most Popular)
                ...['Politik', 'Ekonomi', 'Hukum'].map((category) {
                  if (_categorizedArticles.containsKey(category)) {
                    return Column(
                      children: [
                        _buildCategorySection(
                          context,
                          category,
                          _categorizedArticles[category]!,
                          isDark,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                          child: _buildSolidDivider(isDark),
                        ),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                }).toList(),

                const SizedBox(height: 16),
                
                // Most Popular Section
                if (_mostPopularArticles.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0),
                    child: Text(
                      'Most Popular',
                      style: TextStyle(
                        fontFamily: 'BG_Condensed',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: _mostPopularArticles.length,
                    itemBuilder: (context, index) {
                      final article = _mostPopularArticles[index];
                      return _buildMostPopularItem(context, article, index + 1, isDark);
                    },
                    separatorBuilder: (context, index) {
                      return DottedDivider(
                        color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        indent: 16,     // ✅ sejajar dengan padding konten
                        endIndent: 16,  // ✅ sejajar dengan padding konten
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: _buildSolidDivider(isDark),
                  ),
                ],
                
                // Category Sections after Most Popular (Teknologi, Kesehatan)
                ...['Teknologi', 'Kesehatan'].map((category) {
                  if (_categorizedArticles.containsKey(category)) {
                    return Column(
                      children: [
                        _buildCategorySection(
                          context,
                          category,
                          _categorizedArticles[category]!,
                          isDark,
                        ),
                        if (category != 'Kesehatan')
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                            child: _buildSolidDivider(isDark),
                          ),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                }).toList(),
                
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildLoginForm(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[300],
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'owrite',
            style: TextStyle(
              fontFamily: 'Domine',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Penasaran dengan apa yang ada disini? Jelajahi konten berita terbaru kami setiap hari dan dapatkan informasi terkini yang Anda butuhkan.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCCFF00),
                foregroundColor: isDark ? Colors.white : Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                elevation: 0,
              ),
              child: Text(
                'Sign Up',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTopStoriesSlider(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 24),
      child: Container(
        height: 280,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        child: Stack(
          children: [
            // PageView Slider
            PageView.builder(
              controller: _sliderPageController,
              onPageChanged: _onSliderPageChanged,
              itemCount: _topStoriesArticles.length,
              itemBuilder: (context, index) {
                final article = _topStoriesArticles[index];
                return GestureDetector(
                  onTap: () => _openArticle(article),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Image
                      article.urlToImage != null
                          ? CachedNetworkImage(
                              imageUrl: article.urlToImage!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: isDark ? Colors.grey[800] : Colors.grey[300],
                                child: const Center(child: CircularProgressIndicator()),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: isDark ? Colors.grey[800] : Colors.grey[300],
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                                  size: 60,
                                ),
                              ),
                            )
                          : Container(
                              color: isDark ? Colors.grey[800] : Colors.grey[300],
                              child: Icon(
                                Icons.image_not_supported,
                                color: isDark ? Colors.grey[600] : Colors.grey[400],
                                size: 60,
                              ),
                            ),
                      
                      // Gradient shadow for title area only
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 200,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(1.0),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      // Title
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 24,
                        child: Text(
                          article.title,
                          style: const TextStyle(
                            fontFamily: 'BG_Condensed',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.3,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            
            // Progress indicators (inside image, on top)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Row(
                children: List.generate(
                  _topStoriesArticles.length,
                  (i) => Expanded(
                    child: Container(
                      height: 3,
                      margin: EdgeInsets.only(right: i == _topStoriesArticles.length - 1 ? 0 : 4),
                      child: _progressAnimationController != null
                          ? AnimatedBuilder(
                              animation: _progressAnimationController!,
                              builder: (context, child) {
                                double progress = 0.0;
                                if (i < _currentSliderPage) {
                                  progress = 1.0;
                                } else if (i == _currentSliderPage) {
                                  progress = _progressAnimationController!.value;
                                }
                                
                                return LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.white.withOpacity(0.3),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                );
                              },
                            )
                          : LinearProgressIndicator(
                              value: 0.0,
                              backgroundColor: Colors.white.withOpacity(0.3),
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCategorySection(BuildContext context, String category, List<Article> articles, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                category,
                style: TextStyle(
                  fontFamily: 'BG_Condensed',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              GestureDetector(
                onTap: () => _navigateToCategory(category, articles),
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
                        color: isDark ? Colors.black : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: articles.length,
            itemBuilder: (context, index) {
              final article = articles[index];
              return _buildCategoryArticleCard(context, article, isDark);
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildCategoryArticleCard(BuildContext context, Article article, bool isDark) {
    return GestureDetector(
      onTap: () => _openArticle(article),
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
                  fontFamily: 'Domine',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMostPopularItem(BuildContext context, Article article, int rank, bool isDark) {
    return GestureDetector(
      onTap: () => _openArticle(article),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gambar dengan angka di pojok kiri bawah
            SizedBox(
              width: 120,
              height: 90, // 4:3 ratio
              child: Stack(
                children: [
                  // Gambar
                  CachedNetworkImage(
                    imageUrl: article.urlToImage ?? '',
                    fit: BoxFit.cover,
                    width: 120,
                    height: 90,
                    placeholder: (context, url) => Container(
                      color: isDark ? Colors.grey[800] : Colors.grey[300],
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: isDark ? Colors.grey[800] : Colors.grey[300],
                      child: Icon(Icons.image_not_supported,
                          color: isDark ? Colors.grey[600] : Colors.grey[400]),
                    ),
                  ),

                  // Angka ranking di pojok kiri bawah
                  Positioned(
                    left: -2,
                    bottom: -15,
                    child: Text(
                      rank.toString().padLeft(2, '0'), // format 01, 02, 03...
                      style: const TextStyle(
                        color: Colors.white, // langsung putih tanpa background
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Judul artikel
            Expanded(
              child: Text(
                article.title,
                style: TextStyle(
                  fontFamily: 'Domine',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                  height: 1.3,
                ),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Solid Divider
  Widget _buildSolidDivider(bool isDark) {
    return Container(
      height: 2,
      color: isDark ? Colors.grey[800] : Colors.grey[300],
    );
  }
}

class DottedDivider extends StatelessWidget {
  final double height;
  final Color color;
  final double indent;
  final double endIndent;

  const DottedDivider({
    Key? key,
    this.height = 1,
    this.color = Colors.grey,
    this.indent = 0,
    this.endIndent = 0,
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
          padding: EdgeInsets.only(
            left: indent,
            right: endIndent,
            top: 8,
            bottom: 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(dashCount, (_) {
              return SizedBox(
                width: dashWidth,
                height: height,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: color),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

// Category Articles Full Screen
class CategoryArticlesScreen extends StatelessWidget {
  final String category;
  final List<Article> articles;
  final List<Article> bookmarkedArticles;
  final Function(Article) onBookmarkToggle;

  const CategoryArticlesScreen({
    Key? key,
    required this.category,
    required this.articles,
    required this.bookmarkedArticles,
    required this.onBookmarkToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
      appBar: AppBar(
        backgroundColor: isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
        foregroundColor: isDark ? Colors.white : Colors.black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          category,
          style: const TextStyle(
            fontFamily: 'BG_Condensed',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: articles.length,
        itemBuilder: (context, index) {
          final article = articles[index];
          final isBookmarked = bookmarkedArticles.any((a) => a.id == article.id);
          
          return ArticleCard(
            article: article,
            isBookmarked: isBookmarked,
            onBookmarkToggle: () => onBookmarkToggle(article),
            index: index,
          );
        },
      ),
    );
  }
}
