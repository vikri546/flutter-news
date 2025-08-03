import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import '../models/article.dart';
import '../widgets/browser_chooser_dialog.dart';
import '../utils/intent_helper.dart';
import 'dart:io';

class ArticleDetailScreen extends StatefulWidget {
  final Article article;
  final bool isBookmarked;
  final VoidCallback onBookmarkToggle;
  final String heroTag;

  const ArticleDetailScreen({
    Key? key,
    required this.article,
    required this.isBookmarked,
    required this.onBookmarkToggle,
    required this.heroTag,
  }) : super(key: key);

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  late Animation<Offset> _slideAnimation;

  bool _showAppBarTitle = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeInAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.offset > 180 && !_showAppBarTitle) {
      setState(() {
        _showAppBarTitle = true;
      });
    } else if (_scrollController.offset <= 180 && _showAppBarTitle) {
      setState(() {
        _showAppBarTitle = false;
      });
    }
  }

  /// Main method to open article - platform specific implementation
  Future<void> _openArticleUrl() async {
    final url = widget.article.url;

    try {
      // Check platform and use appropriate method
      if (kIsWeb) {
        // Web platform - use url_launcher
        await _launchUrlForWeb(url);
      } else if (Platform.isWindows) {
        // Windows platform - use url_launcher
        await _launchUrlForWindows(url);
      } else if (Platform.isAndroid) {
        // Android platform - use android_intent_plus for native chooser
        await _launchUrlForAndroid(url);
      } else if (Platform.isIOS) {
        // iOS platform - use url_launcher with iOS specific options
        await _launchUrlForIOS(url);
      } else {
        // Other platforms - use default url_launcher
        await _launchUrlDefault(url);
      }
    } catch (e) {
      _showErrorSnackBar('Error opening URL: ${e.toString()}');
      // Final fallback
      await _launchUrlFallback(Uri.parse(url));
    }
  }

  /// Web platform implementation
  Future<void> _launchUrlForWeb(String url) async {
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault, // Opens in new tab
        webOnlyWindowName: '_blank',
      );

      if (launched) {
        _showSuccessSnackBar('Opening article in new tab...');
      } else {
        throw Exception('Failed to launch URL on web');
      }
    } catch (e) {
      throw Exception('Web launch failed: ${e.toString()}');
    }
  }

  /// Windows platform implementation
  Future<void> _launchUrlForWindows(String url) async {
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication, // Opens in default browser
      );

      if (launched) {
        _showSuccessSnackBar('Opening article in default browser...');
      } else {
        throw Exception('Failed to launch URL on Windows');
      }
    } catch (e) {
      throw Exception('Windows launch failed: ${e.toString()}');
    }
  }

  /// Android platform implementation using android_intent_plus
  Future<void> _launchUrlForAndroid(String url) async {
    try {
      // First try native Android intent chooser
      final success = await IntentHelper.launchUrlWithChooser(
        url,
        title: 'Open with',
      );

      if (success) {
        _showSuccessSnackBar('Opening article...');
      } else {
        // Fallback to custom dialog for Android
        await _showCustomBrowserChooser();
      }
    } catch (e) {
      // If android_intent_plus fails, fallback to url_launcher
      _showErrorSnackBar('Native chooser failed, using fallback...');
      await _launchUrlWithUrlLauncher(url);
    }
  }

  /// iOS platform implementation
  Future<void> _launchUrlForIOS(String url) async {
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (launched) {
        _showSuccessSnackBar('Opening article in Safari...');
      } else {
        throw Exception('Failed to launch URL on iOS');
      }
    } catch (e) {
      throw Exception('iOS launch failed: ${e.toString()}');
    }
  }

  /// Default platform implementation
  Future<void> _launchUrlDefault(String url) async {
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      );

      if (launched) {
        _showSuccessSnackBar('Opening article...');
      } else {
        throw Exception('Failed to launch URL');
      }
    } catch (e) {
      throw Exception('Default launch failed: ${e.toString()}');
    }
  }

  /// Fallback to url_launcher when android_intent_plus fails
  Future<void> _launchUrlWithUrlLauncher(String url) async {
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (launched) {
        _showSuccessSnackBar('Opening article in browser...');
      } else {
        throw Exception('URL launcher failed');
      }
    } catch (e) {
      throw Exception('URL launcher fallback failed: ${e.toString()}');
    }
  }

  /// Show custom browser chooser dialog (for Android fallback or other platforms)
  Future<void> _showCustomBrowserChooser() async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => BrowserChooserDialog(
        url: widget.article.url,
        title: widget.article.title,
      ),
    );
  }

  /// Final fallback method
  Future<void> _launchUrlFallback(Uri url) async {
    try {
      final launched = await launchUrl(
        url,
        mode: LaunchMode.platformDefault,
      );

      if (!launched) {
        throw Exception('Failed to launch URL');
      }
    } catch (e) {
      _showErrorSnackBar('Could not open URL: ${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          action: SnackBarAction(
            label: 'Close',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 8),
              Text(message),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // App bar with image
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: AnimatedOpacity(
                opacity: _showAppBarTitle ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Text(
                  widget.article.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).appBarTheme.titleTextStyle?.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              background: Hero(
                tag: widget.heroTag,
                child: widget.article.urlToImage != null
                    ? CachedNetworkImage(
                        imageUrl: widget.article.urlToImage!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              color: Colors.grey,
                              size: 48,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                            size: 48,
                          ),
                        ),
                      ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeInAnimation,
                    child: child,
                  );
                },
                child: BookmarkIconButton(
                  isBookmarked: widget.isBookmarked,
                  onToggle: () {
                    widget.onBookmarkToggle();
                    setState(() {});
                  },
                ),
              ),
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeInAnimation,
                    child: child,
                  );
                },
                child: IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () async {
                    try {
                      await Share.share(
                        '${widget.article.title}\n\n${widget.article.url}',
                        subject: widget.article.title,
                      );
                    } catch (e) {
                      _showErrorSnackBar(
                          'Failed to share article: ${e.toString()}');
                    }
                  },
                ),
              ),
            ],
          ),
          // Article content
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeInAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: child,
                  ),
                );
              },
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
                            horizontal: 8,
                            vertical: 4,
                          ),
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
                            color: Theme.of(context).textTheme.bodySmall?.color,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Title
                    Text(
                      widget.article.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Source
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.grey[300],
                          child: Text(
                            widget.article.source.name.substring(0, 1),
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.article.source.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _formatDate(widget.article.publishedAt),
                              style: TextStyle(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Content
                    if (widget.article.description != null)
                      Text(
                        widget.article.description!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (widget.article.content != null)
                      Text(
                        widget.article.content!,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.6,
                        ),
                      ),
                    const SizedBox(height: 32),

                    // Platform-specific Read Full Article Button
                    Center(
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.lightBlue,
                            width: 2,
                          ),
                          color: Colors.transparent,
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _openArticleUrl,
                          icon: Icon(
                            _getPlatformIcon(),
                            color: Colors.lightBlue,
                            size: 24,
                          ),
                          label: Text(
                            _getPlatformButtonText(),
                            style: TextStyle(
                              color: Colors.lightBlue,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Platform info
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getPlatformInfoIcon(),
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _getPlatformInfo(),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return ScaleTransition(
            scale: CurvedAnimation(
              parent: _animationController,
              curve: const Interval(0.6, 1.0, curve: Curves.elasticOut),
            ),
            child: FloatingActionButton.extended(
              onPressed: () async {
                try {
                  await Share.share(
                    '${widget.article.title}\n\n${widget.article.url}',
                    subject: widget.article.title,
                  );
                } catch (e) {
                  _showErrorSnackBar(
                      'Failed to share article: ${e.toString()}');
                }
              },
              icon: const Icon(Icons.share),
              label: const Text('Share'),
              tooltip: 'Share Article',
            ),
          );
        },
      ),
    );
  }

  /// Get platform-specific icon for the button
  IconData _getPlatformIcon() {
    if (kIsWeb) {
      return Icons.open_in_new;
    } else if (Platform.isWindows) {
      return Icons.open_in_browser;
    } else if (Platform.isAndroid) {
      return Icons.apps;
    } else if (Platform.isIOS) {
      return Icons.open_in_browser;
    } else {
      return Icons.open_in_browser;
    }
  }

  /// Get platform-specific button text
  String _getPlatformButtonText() {
    if (kIsWeb) {
      return 'Open in New Tab';
    } else if (Platform.isWindows) {
      return 'Open in Browser';
    } else if (Platform.isAndroid) {
      return 'Choose App to Open';
    } else if (Platform.isIOS) {
      return 'Open in Safari';
    } else {
      return 'Read Full Article';
    }
  }

  /// Get platform info icon
  IconData _getPlatformInfoIcon() {
    if (kIsWeb) {
      return Icons.web;
    } else if (Platform.isWindows) {
      return Icons.desktop_windows;
    } else if (Platform.isAndroid) {
      return Icons.android;
    } else if (Platform.isIOS) {
      return Icons.phone_iphone;
    } else {
      return Icons.devices;
    }
  }

  /// Get platform-specific info text
  String _getPlatformInfo() {
    if (kIsWeb) {
      return 'Web • Opens in new browser tab';
    } else if (Platform.isWindows) {
      return 'Windows • Opens in default browser';
    } else if (Platform.isAndroid) {
      return 'Android • Native app chooser';
    } else if (Platform.isIOS) {
      return 'iOS • Opens in Safari';
    } else {
      return 'Platform default';
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class BookmarkIconButton extends StatefulWidget {
  final bool isBookmarked;
  final VoidCallback onToggle;

  const BookmarkIconButton({
    Key? key,
    required this.isBookmarked,
    required this.onToggle,
  }) : super(key: key);

  @override
  State<BookmarkIconButton> createState() => _BookmarkIconButtonState();
}

class _BookmarkIconButtonState extends State<BookmarkIconButton>
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
        tween: Tween<double>(begin: 1.0, end: 1.5),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.5, end: 1.0),
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
    return IconButton(
      icon: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Icon(
              widget.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: widget.isBookmarked || _isPressed ? Colors.blue : null,
            ),
          );
        },
      ),
      onPressed: () {
        _controller.forward(from: 0.0);
        setState(() {
          _isPressed = !_isPressed;
        });
        widget.onToggle();
      },
    );
  }
}
