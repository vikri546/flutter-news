import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/article_provider.dart';
import '../providers/language_provider.dart';
import '../utils/strings.dart';
import '../models/article.dart';
import '../screens/article_detail_screen.dart';
import '../services/notification_scheduler.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  List<Article> _pickRandom(List<Article> source, int count) {
    final list = List<Article>.from(source);
    list.shuffle();
    return list.take(count).toList();
  }

  void _navigateToArticle(BuildContext context, Article article) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArticleDetailScreen(
            article: article,
            isBookmarked: false,
            onBookmarkToggle: () {},
            heroTag: ''),
      ),
    );
  }

  Widget _buildNewsItem({
    required Article article,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.info_outline,
                color: Colors.blue,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (article.description != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      article.description!,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[300] : Colors.grey[600],
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(article.publishedAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[500],
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.trending_up,
                        size: 12,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Trending',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _testNotification(BuildContext context) {
    NotificationScheduler().sendTestNotification();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          Provider.of<LanguageProvider>(context, listen: false)
                      .locale
                      .languageCode ==
                  'en'
              ? 'Test notification sent!'
              : 'Notifikasi test dikirim!',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _testMaximumVolumeNotification(BuildContext context) async {
    await NotificationService().testMaximumVolumeNotification();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          Provider.of<LanguageProvider>(context, listen: false)
                      .locale
                      .languageCode ==
                  'en'
              ? 'Maximum volume test notification sent!'
              : 'Notifikasi test volume maksimum dikirim!',
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings =
        AppStrings(context.watch<LanguageProvider>().locale.languageCode);
    final provider = context.watch<ArticleProvider>();
    final all = provider.articles;
    final recommended = _pickRandom(all, 5);
    final trending = _pickRandom(all, 5);
    final popular = _pickRandom(all, 5);
    final hot = _pickRandom(all, 5);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.isEn ? 'News Articles' : 'Artikel Berita'),
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        elevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Test notification button
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            child: ElevatedButton.icon(
              onPressed: () => _testNotification(context),
              icon: const Icon(Icons.notifications_active),
              label:
                  Text(strings.isEn ? 'Test Notification' : 'Test Notifikasi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          Text(
            strings.isEn
                ? 'Are you searching for something like this?'
                : 'Anda sedang mencari berita seperti ini?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ...recommended.map((article) => _buildNewsItem(
                article: article,
                isDark: isDark,
                onTap: () => _navigateToArticle(context, article),
              )),

          const SizedBox(height: 24),
          Text(
            strings.isEn
                ? 'Maybe this matches what you searched'
                : 'Ini mungkin berita yang cocok seperti Anda cari',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ...trending.map((article) => _buildNewsItem(
                article: article,
                isDark: isDark,
                onTap: () => _navigateToArticle(context, article),
              )),

          const SizedBox(height: 24),
          Text(
            strings.isEn ? 'Hot Today' : 'Hari Ini Trending',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ...hot.map((article) => _buildNewsItem(
                article: article,
                isDark: isDark,
                onTap: () => _navigateToArticle(context, article),
              )),

          const SizedBox(height: 24),
          Text(
            strings.isEn
                ? 'Popular & Most Searched'
                : 'Populer & Paling Dicari',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ...popular.map((article) => _buildNewsItem(
                article: article,
                isDark: isDark,
                onTap: () => _navigateToArticle(context, article),
              )),
        ],
      ),
    );
  }
}
