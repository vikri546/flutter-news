import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../models/article.dart';
import '../screens/article_detail_screen.dart';
import '../utils/custom_page_transitions.dart';
import '../utils/auth_service.dart';
import '../screens/login_screen.dart';
import '../providers/theme_provider.dart';

enum ArticleCardLayout {
  defaultCard,
  layout1,
  layout2,
  layout3,
}

class FeaturedArticleCard extends StatefulWidget {
  final Article article;
  final bool isBookmarked;
  final VoidCallback onBookmarkToggle;
  final int index;

  const FeaturedArticleCard({
    Key? key,
    required this.article,
    required this.isBookmarked,
    required this.onBookmarkToggle,
    required this.index,
  }) : super(key: key);

  @override
  State<FeaturedArticleCard> createState() => _FeaturedArticleCardState();
}

class _FeaturedArticleCardState extends State<FeaturedArticleCard> {
  @override
  Widget build(BuildContext context) {
    final heroTag = 'featured-article-image-${widget.article.id}';
    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          HeroDialogRoute(
            builder: (context) => ArticleDetailScreen(
              article: widget.article,
              isBookmarked: widget.isBookmarked,
              onBookmarkToggle: widget.onBookmarkToggle,
              heroTag: heroTag,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: heroTag,
              child: CachedNetworkImage(
                imageUrl: widget.article.urlToImage ?? '',
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.grey.shade300),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.image_not_supported, color: Colors.grey),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.8)
                  ],
                  stops: const [0.5, 0.7, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.yellow,
                    ),
                    child: Text(
                      widget.article.category,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(color: Colors.white.withOpacity(0.7), blurRadius: 2),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.article.title,
                    style: const TextStyle(
                      fontFamily: 'CrimsonPro',
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontSize: 18,
                      shadows: [
                        Shadow(
                          color: Colors.black87,
                          blurRadius: 5,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ArticleCard extends StatefulWidget {
  final Article article;
  final bool isBookmarked;
  final VoidCallback onBookmarkToggle;
  final int index;
  final ArticleCardLayout layout;

  const ArticleCard({
    Key? key,
    required this.article,
    required this.isBookmarked,
    required this.onBookmarkToggle,
    required this.index,
    this.layout = ArticleCardLayout.defaultCard,
  }) : super(key: key);

  @override
  State<ArticleCard> createState() => _ArticleCardState();
}

class _ArticleCardState extends State<ArticleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  final AuthService _authService = AuthService();
  bool _isGuestUser = false;

  static const Color _stabiloGreen = Color(0xFFAEEE00);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
    _checkGuestStatus();
  }

  Future<void> _checkGuestStatus() async {
    final user = await _authService.getCurrentUser();
    if (user == null || user['username'] == 'Guest') {
      if (mounted) {
        setState(() {
          _isGuestUser = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showLoginRequiredSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.yellow[700]),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: const Color(0xFF333333),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'LOGIN',
          textColor: Colors.yellow[700],
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => const LoginScreen()));
          },
        ),
      ),
    );
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
    setState(() {
      _isPressed = true;
    });
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    setState(() {
      _isPressed = false;
    });
  }

  void _onTapCancel() {
    _controller.reverse();
    setState(() {
      _isPressed = false;
    });
  }

  // Fitur longpress telah dihapus.

  void _navigateToDetail(String heroTag) async {
    await Navigator.of(context).push(
      HeroDialogRoute(
        builder: (context) => ArticleDetailScreen(
          article: widget.article,
          isBookmarked: widget.isBookmarked,
          onBookmarkToggle: widget.onBookmarkToggle,
          heroTag: heroTag,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final heroTag = 'article-image-${widget.article.id}-${widget.index}';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        // onLongPress dihapus sesuai instruksi
        onTap: () => _navigateToDetail(heroTag),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: _buildCardLayout(context, heroTag, isDark),
        ),
      ),
    );
  }

  Widget _buildCardLayout(BuildContext context, String heroTag, bool isDark) {
    switch (widget.layout) {
      case ArticleCardLayout.layout1:
        return _buildLayout1(context, heroTag, isDark);
      case ArticleCardLayout.layout2:
        return _buildLayout2(context, heroTag, isDark);
      case ArticleCardLayout.layout3:
        return _buildLayout3(context, heroTag, isDark);
      case ArticleCardLayout.defaultCard:
      default:
        return _buildDefaultLayout(context, heroTag, isDark);
    }
  }

  Widget _buildLayout1(BuildContext context, String heroTag, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Thumbnail kiri
        Expanded(
          flex: 1,
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: _buildImage(heroTag, isDark, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 12),

        // Konten kanan
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Baris kategori + waktu
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: _buildCategoryChip(context, isDark),
                  ),
                  const SizedBox(width: 8),
                  _buildTimeText(isDark, fontSize: 10),
                ],
              ),
              const SizedBox(height: 6),

              // Judul berita
              _buildTitle(
                isDark,
                maxLines: 5, // 🔑 batasi 2 baris
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLayout2(BuildContext context, String heroTag, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: _buildImage(heroTag, isDark, fit: BoxFit.cover),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: _buildTitle(isDark, maxLines: 3, fontSize: 18),
        ),
      ],
    );
  }

  Widget _buildLayout3(BuildContext context, String heroTag, bool isDark) {
    return Column(
      children: [
        _buildImage(heroTag, isDark, fit: BoxFit.cover),
        Transform.translate(
          offset: const Offset(0, -20), // geser ke atas biar overlap
          child: Align(
            alignment: Alignment.centerLeft, // biar nempel kiri
            child: Container(
              // kasih lebar tidak full, biar kanan ada ruang kosong
              width: MediaQuery.of(context).size.width * 0.95, // 90% lebar layar
              decoration: BoxDecoration(
                color: isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(0), // radius hanya di kiri
                  topRight: Radius.circular(0), // kanan lurus
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildCategoryChip(context, isDark),
                      _buildTimeText(isDark, fontSize: 10),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTitle(isDark, maxLines: 3, fontSize: 22, fontWeight: FontWeight.bold),
                  const SizedBox(height: 8),
                  _buildDescription(isDark, maxLines: 5, fontSize: 14),
                  
                  const SizedBox(height: 32),
                  // 🔄 Tambahan: garis tipis pemisah (opsional)
                  Divider(
                    color: isDark ? Colors.grey[800] : Colors.grey[500],
                    thickness: 1,
                    height: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultLayout(BuildContext context, String heroTag, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Hero(
          tag: heroTag,
          child: SizedBox(
            height: 200,
            width: double.infinity,
            child: _buildImage(heroTag, isDark, useHero: false, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildCategoryChip(context, isDark),
            _buildTimeText(isDark, fontSize: 10),
          ],
        ),
        const SizedBox(height: 10),
        _buildTitle(isDark, maxLines: 3, fontSize: 20),
      ],
    );
  }

  Widget _buildImage(String heroTag, bool isDark, {bool useHero = true, BoxFit fit = BoxFit.cover}) {
    Widget imageWidget = widget.article.urlToImage != null
        ? CachedNetworkImage(
            imageUrl: widget.article.urlToImage!,
            fit: fit,
            placeholder: (context, url) => Container(
              color: isDark ? Colors.grey[800] : Colors.grey[300],
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              color: isDark ? Colors.grey[800] : Colors.grey[300],
              child: Icon(
                Icons.image_not_supported,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
                size: 40,
              ),
            ),
          )
        : Container(
            color: isDark ? Colors.grey[800] : Colors.grey[300],
            child: Icon(
              Icons.image_not_supported,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
              size: 40,
            ),
          );

    if (useHero) {
      return Hero(
        tag: heroTag,
        child: imageWidget,
      );
    }
    return imageWidget;
  }

  Widget _buildCategoryChip(BuildContext context, bool isDark) {
    return Text(
      widget.article.category.toUpperCase(),
      style: TextStyle(
        fontFamily: 'Inter',
        color: _stabiloGreen, // Warna stabilo green untuk teks
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildTimeText(bool isDark, {double fontSize = 10.0}) {
    return Text(
      _formatDate(widget.article.publishedAt),
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: fontSize,
        color: isDark ? Colors.grey[400] : Colors.grey[600],
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildTitle(
    bool isDark, {
    int maxLines = 3,
    double fontSize = 20.0,
    FontWeight fontWeight = FontWeight.w800,
  }) {
    final title = widget.article.title?.trim();
    return Text(
      title?.isNotEmpty == true ? title! : 'Untitled',
      style: TextStyle(
        fontFamily: 'Arimo',
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: isDark ? Colors.white : Colors.black,
        height: 1.3,
        letterSpacing: 0.2, // ✨ sedikit spasi biar lebih rapi
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildDescription(
    bool isDark, {
    int maxLines = 3,
    double fontSize = 14.0,
    Color? color,
  }) {
    final desc = widget.article.description?.trim();
    return Text(
      desc?.isNotEmpty == true ? desc! : 'No description available.',
      style: TextStyle(
        fontFamily: 'SourceSerif4',
        fontSize: fontSize,
        color: isDark ? Colors.grey[400] : Colors.grey[700],
        height: 1.4,
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes < 1) return 'NEW';
        return '${difference.inMinutes} MIN';
      }
      return '${difference.inHours} HOUR';
    } else if (difference.inDays == 1) {
      return 'YESTERDAY';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} DAY';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class ShareButton extends StatefulWidget {
  final Article article;

  const ShareButton({
    Key? key,
    required this.article,
  }) : super(key: key);

  @override
  State<ShareButton> createState() => _ShareButtonState();
}

class _ShareButtonState extends State<ShareButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.3),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0),
        weight: 50,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () async {
        _controller.forward(from: 0.0);
        setState(() {
          _isPressed = !_isPressed;
        });
        
        try {
          await Share.share(
            '${widget.article.title}\n\n${widget.article.url}',
            subject: widget.article.title,
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to share: ${e.toString()}'),
              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[600],
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Icon(
              Icons.share,
              color: isDark ? Colors.white70 : Colors.black54,
              size: 16,
            ),
          );
        },
      ),
    );
  }
}