import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/article_provider.dart';
import '../providers/language_provider.dart';
import '../utils/strings.dart';
import '../models/article.dart';
import '../screens/article_detail_screen.dart';
import '../services/notification_scheduler.dart';
import '../services/notification_service.dart';
import '../utils/custom_page_transitions.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  List<Article> _pickRandom(List<Article> source, int count) {
    final list = List<Article>.from(source);
    list.shuffle();
    return list.take(count).toList();
  }

  void _navigateToArticle(BuildContext context, Article article) {
    final heroTag = 'notif-article-${article.id}';
    Navigator.push(
      context,
      HeroDialogRoute(
        builder: (context) => ArticleDetailScreen(
          article: article,
          isBookmarked: false,
          onBookmarkToggle: () {},
          heroTag: heroTag,
        ),
      ),
    );
  }

  Widget _buildCompactNewsItem({
    required Article article,
    required bool isDark,
    required VoidCallback onTap,
    required String heroTag,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Hero(
              tag: heroTag,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 70,
                  height: 70,
                  child: article.urlToImage != null
                      ? CachedNetworkImage(
                          imageUrl: article.urlToImage!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: isDark ? Colors.grey[800] : Colors.grey[300],
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: isDark ? Colors.grey[800] : Colors.grey[300],
                            child: Icon(
                              Icons.image_not_supported,
                              color: isDark ? Colors.grey[600] : Colors.grey[400],
                              size: 24,
                            ),
                          ),
                        )
                      : Container(
                          color: isDark ? Colors.grey[800] : Colors.grey[300],
                          child: Icon(
                            Icons.article,
                            color: isDark ? Colors.grey[600] : Colors.grey[400],
                            size: 24,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.yellow[700]!.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      article.category,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.yellow[700],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  
                  // Title
                  Text(
                    article.title,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  
                  // Time
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(article.publishedAt),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
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

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} hari lalu';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} jam lalu';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} menit lalu';
    } else {
      return 'Baru saja';
    }
  }

  void _testNotification(BuildContext context) {
    NotificationScheduler().sendTestNotification();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              Provider.of<LanguageProvider>(context, listen: false)
                          .locale
                          .languageCode ==
                      'en'
                  ? 'Test notification sent!'
                  : 'Notifikasi test dikirim!',
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings =
        AppStrings(context.watch<LanguageProvider>().locale.languageCode);
    final provider = context.watch<ArticleProvider>();
    final all = provider.articles;
    final recommended = _pickRandom(all, 4);
    final trending = _pickRandom(all, 4);
    final popular = _pickRandom(all, 4);
    final hot = _pickRandom(all, 4);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.yellow[700]!.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.notifications_active,
                size: 20,
                color: Colors.yellow[700],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              strings.isEn ? 'Notifications' : 'Notifikasi',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: isDark ? Colors.grey[800] : Colors.grey[200],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [Colors.grey[850]!, Colors.grey[900]!]
                    : [Colors.blue[700]!, Colors.blue[900]!],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.campaign,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.isEn
                                ? 'Stay Updated'
                                : 'Tetap Update',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            strings.isEn
                                ? 'Get latest news notifications'
                                : 'Dapatkan notifikasi berita terbaru',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _testNotification(context),
                    icon: const Icon(Icons.notifications, size: 18),
                    label: Text(
                      strings.isEn ? 'Test Notification' : 'Test Notifikasi',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: isDark ? Colors.grey[900] : Colors.blue[900],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Recommended Section
          _buildSectionHeader(
            title: strings.isEn
                ? 'Recommended For You'
                : 'Rekomendasi Untuk Anda',
            icon: Icons.star_rounded,
            iconColor: Colors.amber,
            isDark: isDark,
          ),
          ...recommended.asMap().entries.map((entry) {
            final index = entry.key;
            final article = entry.value;
            return _buildCompactNewsItem(
              article: article,
              isDark: isDark,
              onTap: () => _navigateToArticle(context, article),
              heroTag: 'notif-recommended-$index',
            );
          }),

          const SizedBox(height: 24),
          
          // Trending Section
          _buildSectionHeader(
            title: strings.isEn ? 'Trending Now' : 'Sedang Trending',
            icon: Icons.trending_up,
            iconColor: Colors.orange,
            isDark: isDark,
          ),
          ...trending.asMap().entries.map((entry) {
            final index = entry.key;
            final article = entry.value;
            return _buildCompactNewsItem(
              article: article,
              isDark: isDark,
              onTap: () => _navigateToArticle(context, article),
              heroTag: 'notif-trending-$index',
            );
          }),

          const SizedBox(height: 24),
          
          // Hot Today Section
          _buildSectionHeader(
            title: strings.isEn ? 'Hot Today' : 'Hangat Hari Ini',
            icon: Icons.local_fire_department,
            iconColor: Colors.red,
            isDark: isDark,
          ),
          ...hot.asMap().entries.map((entry) {
            final index = entry.key;
            final article = entry.value;
            return _buildCompactNewsItem(
              article: article,
              isDark: isDark,
              onTap: () => _navigateToArticle(context, article),
              heroTag: 'notif-hot-$index',
            );
          }),

          const SizedBox(height: 24),
          
          // Popular Section
          _buildSectionHeader(
            title: strings.isEn
                ? 'Most Popular'
                : 'Paling Populer',
            icon: Icons.whatshot,
            iconColor: Colors.purple,
            isDark: isDark,
          ),
          ...popular.asMap().entries.map((entry) {
            final index = entry.key;
            final article = entry.value;
            return _buildCompactNewsItem(
              article: article,
              isDark: isDark,
              onTap: () => _navigateToArticle(context, article),
              heroTag: 'notif-popular-$index',
            );
          }),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}