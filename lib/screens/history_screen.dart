import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/article.dart';
import '../providers/language_provider.dart';
import '../utils/strings.dart';
import '../utils/auth_service.dart';
import '../services/history_service.dart';
import 'login_screen.dart';

class HistoryScreen extends StatefulWidget {
  final VoidCallback? onNavigateToHome;

  const HistoryScreen({
    Key? key,
    this.onNavigateToHome,
  }) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isLoggedIn = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _historyArticles = [];
  final HistoryService _historyService = HistoryService();

  @override
  void initState() {
    super.initState();
    _initializeHistory();
  }

  Future<void> _initializeHistory() async {
    await _checkLoginStatus();
    if (_isLoggedIn) {
      await _loadHistory();
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

  Future<void> _loadHistory() async {
    try {
      final history = await _historyService.getHistory();
      setState(() {
        _historyArticles = history;
      });
    } catch (e) {
      debugPrint('Error loading history: $e');
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Clear History'),
        content: const Text('Are you sure you want to clear all history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Clear',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _historyService.clearHistory();
      setState(() {
        _historyArticles = [];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, color: Colors.green[300]),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('History cleared', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF333333),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        _navigateToHome();
        return false;
      },
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: _navigateToHome,
          ),
          title: const Text(
            'Recent stories',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          backgroundColor: isDark ? Colors.black : Colors.white,
          elevation: 0,
          actions: _isLoggedIn && _historyArticles.isNotEmpty
              ? [
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: _clearHistory,
                    tooltip: 'Clear history',
                  ),
                ]
              : null,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(
              height: 1,
              thickness: 1,
              color: isDark ? Colors.grey[800] : Colors.grey[200],
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

    if (_historyArticles.isEmpty) {
      return _buildEmptyHistory(isDark);
    }

    return _buildHistoryList(isDark);
  }

  Widget _buildLoginRequired(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 200,
              height: 150,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  Icons.access_time_rounded,
                  size: 80,
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Create an account and save\narticles across multiple devices',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                ).then((_) => _initializeHistory());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(200, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Create an account',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                ).then((_) => _initializeHistory());
              },
              child: Text(
                'Already have an account? Log in',
                style: TextStyle(
                  fontSize: 14,
                  decoration: TextDecoration.underline,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHistory(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_rounded,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'No recent stories',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your reading history will appear here.\nHistory automatically clears after 24 hours.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: _historyArticles.length,
      separatorBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Divider(
          height: 1,
          thickness: 1,
          color: isDark ? Colors.grey[800] : Colors.grey[200],
        ),
      ),
      itemBuilder: (context, index) {
        final item = _historyArticles[index];
        return _buildHistoryItem(item, isDark);
      },
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> item, bool isDark) {
    final String title = item['title'] ?? 'No Title';
    final String? imageUrl = item['imageUrl'];
    final String category = (item['category'] ?? 'GENERAL').toUpperCase();
    final DateTime readAt = DateTime.parse(item['readAt']);
    final int readTime = item['readTime'] ?? 3;

    return InkWell(
      onTap: () {
        // Navigate to article detail
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail image (4:3 ratio)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 100,
                    height: 75,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 100,
                      height: 75,
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 100,
                      height: 75,
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.grey[500],
                      ),
                    ),
                  )
                : Container(
                    width: 100,
                    height: 75,
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.grey[500],
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          // Article info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category and read time
                Text(
                  '$category        $readTime MIN READ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                // Title
                Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}