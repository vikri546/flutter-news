import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/article.dart';
import '../providers/language_provider.dart';
import '../utils/strings.dart';
import '../utils/auth_service.dart';
import '../services/bookmark_service.dart';
import 'login_screen.dart';
import 'article_detail_screen.dart';
import '../utils/custom_page_transitions.dart';
import '../providers/theme_provider.dart';

class BookmarkScreen extends StatefulWidget {
  final VoidCallback? onNavigateToHome;
  final Function(Article)? onBookmarkToggle;
  final List<Article>? bookmarkedArticles;

  const BookmarkScreen({
    Key? key,
    this.onNavigateToHome,
    this.onBookmarkToggle,
    this.bookmarkedArticles,
  }) : super(key: key);

  @override
  State<BookmarkScreen> createState() => _BookmarkScreenState();
}

class _BookmarkScreenState extends State<BookmarkScreen> {
  bool _isLoggedIn = false;
  bool _isLoading = true;
  final BookmarkService _bookmarkService = BookmarkService();
  List<Article> _bookmarkedArticles = [];

  @override
  void initState() {
    super.initState();
    _initializeBookmarks();
  }

  Future<void> _initializeBookmarks() async {
    await _checkLoginStatus();
    if (_isLoggedIn) {
      await _loadBookmarks();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _checkLoginStatus() async {
    final authService = AuthService();
    final user = await authService.getCurrentUser();
    setState(() {
      _isLoggedIn = user != null && user['username'] != 'Guest';
    });
  }

  Future<void> _loadBookmarks() async {
    try {
      final bookmarks = await _bookmarkService.getAllBookmarkedArticlesSimple();
      if (mounted) {
        setState(() {
          _bookmarkedArticles = bookmarks;
        });
      }
    } catch (e) {
      debugPrint('Error loading bookmarks: $e');
    }
  }

  Future<void> _removeBookmark(Article article) async {
    try {
      await _bookmarkService.removeBookmark(article);
      if (mounted) {
        setState(() {
          _bookmarkedArticles.removeWhere((a) => a.id == article.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Bookmark dihapus'),
            duration: const Duration(seconds: 2),
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? ThemeProvider.lightColor
                : ThemeProvider.darkColor,
          ),
        );
        // Callback jika ada
        if (widget.onBookmarkToggle != null) {
          widget.onBookmarkToggle!(article);
        }
      }
    } catch (e) {
      debugPrint("Error removing bookmark: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Gagal menghapus bookmark'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  void _navigateToHome() {
    if (widget.onNavigateToHome != null) {
      widget.onNavigateToHome!();
    } else {
      Navigator.pop(context);
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes < 1) return 'Baru saja';
        return '${difference.inMinutes} mnt';
      }
      return '${difference.inHours} jam';
    } else if (difference.inDays == 1) {
      return 'Kemarin';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari';
    } else {
      return DateFormat('d MMM', 'id_ID').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: () async {
        _navigateToHome();
        return false;
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: isDark ? Colors.white : Colors.black,
            ),
            onPressed: _navigateToHome,
          ),
          title: Text(
            'Bookmarks', // Judul sudah 'Bookmarks'
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(
              color: isDark ? Colors.grey[800] : Colors.grey[300],
              height: 1.0,
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(isDark),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (!_isLoggedIn) {
      return _buildLoginRequired(isDark);
    }

    if (_bookmarkedArticles.isEmpty) {
      return _buildEmptyBookmarks(isDark);
    }

    return _buildBookmarkList(isDark);
  }

  // --- WIDGET YANG DIMODIFIKASI ---
  Widget _buildLoginRequired(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.bookmark_border_rounded, // Menggunakan ikon bookmark
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Buat akun untuk menyimpan dan mengakses Bookmark Anda di semua perangkat.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 18,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
            // Tombol "Create an account" dan "Log in" dihapus sesuai permintaan
          ],
        ),
      ),
    );
  }
  // --- AKHIR MODIFIKASI ---

  Widget _buildEmptyBookmarks(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Belum Ada Bookmark',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Artikel yang Anda simpan akan muncul di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarkList(bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: _bookmarkedArticles.length,
      itemBuilder: (context, index) {
        final article = _bookmarkedArticles[index];
        return _buildBookmarkItem(article, isDark);
      },
      separatorBuilder: (context, index) {
        return DottedDivider(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        );
      },
    );
  }

  Widget _buildBookmarkItem(Article article, bool isDark) {
    return Dismissible(
      key: Key(article.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        color: Colors.red,
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
          size: 28,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Hapus Bookmark'),
              content: const Text('Apakah Anda yakin ingin menghapus bookmark ini?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Batal'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text(
                    'Hapus',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) {
        _removeBookmark(article);
      },
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            HeroDialogRoute(
              builder: (context) => ArticleDetailScreen(
                article: article,
                isBookmarked: true,
                onBookmarkToggle: () {
                  _removeBookmark(article);
                },
                heroTag: 'bookmark-${article.id}',
              ),
            ),
          ).then((_) {
            // Refresh bookmarks setelah kembali dari detail
            _loadBookmarks();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          color: Colors.transparent,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gambar 4:3
              SizedBox(
                width: 120,
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.zero,
                    child: CachedNetworkImage(
                      imageUrl: article.urlToImage ?? '',
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.image_outlined, color: Colors.grey),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.broken_image_outlined, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Teks
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kategori dan Waktu
                    Row(
                      children: [
                        Text(
                          (article.category ?? 'GENERAL').toUpperCase(),
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatDate(article.publishedAt ?? DateTime.now()),
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Judul
                    Text(
                      article.title ?? 'No Title',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'CrimsonPro',
                        color: isDark ? Colors.white : Colors.black,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Dotted Divider Widget
class DottedDivider extends StatelessWidget {
  final double height;
  final Color color;

  const DottedDivider({
    Key? key,
    this.height = 1,
    this.color = Colors.grey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 1.0;
        const dashSpace = 3.0;
        final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(dashCount, (_) {
              return SizedBox(
                width: dashWidth,
                height: height,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: color, shape: BoxShape.rectangle),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
