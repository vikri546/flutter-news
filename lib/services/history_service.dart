import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/article.dart';

class HistoryService {
  static const String _historyKey = 'article_history';
  static const int _maxHistoryItems = 50;
  static const int _historyExpirationHours = 24;

  // Add article to history
  Future<void> addToHistory(Article article) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_historyKey) ?? '[]';
      final List<dynamic> historyList = json.decode(historyJson);

      // Remove if already exists (to update read time)
      historyList.removeWhere((item) => item['id'] == article.id);

      // Calculate read time
      final int readTime = _calculateReadTime(article.description ?? '');

      // Add to beginning of list (convert Article to Map)
      historyList.insert(0, {
        'id': article.id,
        'title': article.title,
        'description': article.description,
        'url': article.url,
        'urlToImage': article.urlToImage,
        'publishedAt': article.publishedAt.toIso8601String(),
        'content': article.content,
        'category': article.category,
        'author': article.author,
        'source': {
          'id': article.source.id,
          'name': article.source.name,
        },
        'readAt': DateTime.now().toIso8601String(),
        'readTime': readTime,
      });

      // Keep only last _maxHistoryItems items
      if (historyList.length > _maxHistoryItems) {
        historyList.removeRange(_maxHistoryItems, historyList.length);
      }

      // Save back to SharedPreferences
      await prefs.setString(_historyKey, json.encode(historyList));
      debugPrint('Article added to history: ${article.title}');
    } catch (e) {
      debugPrint('Error adding to history: $e');
    }
  }

  // Get all history (automatically filters expired items)
  Future<List<Map<String, dynamic>>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_historyKey) ?? '[]';
      final List<dynamic> historyList = json.decode(historyJson);

      // Filter articles that are still within 24 hours
      final now = DateTime.now();
      final validHistory = historyList.where((item) {
        try {
          final readAt = DateTime.parse(item['readAt']);
          final difference = now.difference(readAt);
          return difference.inHours < _historyExpirationHours;
        } catch (e) {
          return false; // Skip invalid items
        }
      }).toList();

      // Save back the filtered history
      await prefs.setString(_historyKey, json.encode(validHistory));

      return List<Map<String, dynamic>>.from(validHistory);
    } catch (e) {
      debugPrint('Error getting history: $e');
      return [];
    }
  }

  // Clear all history
  Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_historyKey, '[]');
      debugPrint('History cleared');
    } catch (e) {
      debugPrint('Error clearing history: $e');
    }
  }

  // Remove specific article from history
  Future<void> removeFromHistory(String articleId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_historyKey) ?? '[]';
      final List<dynamic> historyList = json.decode(historyJson);

      // Remove the article
      historyList.removeWhere((item) => item['id'] == articleId);

      // Save back
      await prefs.setString(_historyKey, json.encode(historyList));
      debugPrint('Article removed from history: $articleId');
    } catch (e) {
      debugPrint('Error removing from history: $e');
    }
  }

  // Clean expired history items (call this periodically)
  Future<void> cleanExpiredHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_historyKey) ?? '[]';
      final List<dynamic> historyList = json.decode(historyJson);

      final now = DateTime.now();
      final validHistory = historyList.where((item) {
        try {
          final readAt = DateTime.parse(item['readAt']);
          final difference = now.difference(readAt);
          return difference.inHours < _historyExpirationHours;
        } catch (e) {
          return false;
        }
      }).toList();

      await prefs.setString(_historyKey, json.encode(validHistory));
      debugPrint('Expired history cleaned. Remaining items: ${validHistory.length}');
    } catch (e) {
      debugPrint('Error cleaning expired history: $e');
    }
  }

  // Check if article is in history
  Future<bool> isInHistory(String articleId) async {
    try {
      final history = await getHistory();
      return history.any((item) => item['id'] == articleId);
    } catch (e) {
      return false;
    }
  }

  // Get history count
  Future<int> getHistoryCount() async {
    try {
      final history = await getHistory();
      return history.length;
    } catch (e) {
      return 0;
    }
  }

  // Calculate read time based on text length
  int _calculateReadTime(String text) {
    // Average reading speed: 200 words per minute
    final wordCount = text.split(RegExp(r'\s+')).length;
    return (wordCount / 200).ceil().clamp(1, 99);
  }
}