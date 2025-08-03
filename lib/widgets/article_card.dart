import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/article.dart';
import '../screens/article_detail_screen.dart';
import '../utils/custom_page_transitions.dart';

class ArticleCard extends StatefulWidget {
  final Article article;
  final bool isBookmarked;
  final VoidCallback onBookmarkToggle;
  final int index;

  const ArticleCard({
    Key? key,
    required this.article,
    required this.isBookmarked,
    required this.onBookmarkToggle,
    required this.index,
  }) : super(key: key);

  @override
  State<ArticleCard> createState() => _ArticleCardState();
}

class _ArticleCardState extends State<ArticleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final heroTag = 'article-image-${widget.article.id}-${widget.index}';

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
        onTap: () {
          Navigator.of(context).push(
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
        child: Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: _isPressed ? 1 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gambar Artikel
              Hero(
                tag: heroTag,
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                  child: widget.article.urlToImage != null
                      ? CachedNetworkImage(
                          imageUrl: widget.article.urlToImage!,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 180,
                            color: Colors.grey[300],
                            child: const Center(
                                child: CircularProgressIndicator()),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 180,
                            color: Colors.grey[300],
                            child: const Center(
                              child: Icon(Icons.image_not_supported,
                                  color: Colors.grey),
                            ),
                          ),
                        )
                      : Container(
                          height: 180,
                          color: Colors.grey[300],
                          child: const Center(
                            child: Icon(Icons.image_not_supported,
                                color: Colors.grey),
                          ),
                        ),
                ),
              ),

              // Container dengan border bawah dan kanan KUNING
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.yellow, width: 2.0),
                    right: BorderSide(color: Colors.yellow, width: 2.0),
                  ),
                  borderRadius: BorderRadius.only(
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category and date
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.article.category,
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDate(widget.article.publishedAt),
                            style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Title
                      Text(
                        widget.article.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // Description
                      if (widget.article.description != null)
                        Text(
                          widget.article.description!,
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 16),

                      // Source dan Bookmark
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'From ${widget.article.source.name}',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          BookmarkButton(
                            isBookmarked: widget.isBookmarked,
                            onToggle: widget.onBookmarkToggle,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} min ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class BookmarkButton extends StatefulWidget {
  final bool isBookmarked;
  final VoidCallback onToggle;

  const BookmarkButton({
    Key? key,
    required this.isBookmarked,
    required this.onToggle,
  }) : super(key: key);

  @override
  State<BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends State<BookmarkButton>
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
    return GestureDetector(
      onTap: () {
        _controller.forward(from: 0.0);
        setState(() {
          _isPressed = !_isPressed;
        });
        widget.onToggle();
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Icon(
              widget.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: widget.isBookmarked || _isPressed ? Colors.blue : Colors.grey,
              size: 24,
            ),
          );
        },
      ),
    );
  }
}