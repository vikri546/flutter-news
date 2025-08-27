import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/achievement.dart';

class AchievementService {
  final SupabaseClient _client;

  AchievementService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<void> logArticleRead(BuildContext context, String articleUrl) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('reading_history').insert({
      'user_id': userId,
      'article_url': articleUrl,
    });
    await _checkAndAwardAchievements(context);
  }

  Future<void> logCommentMade(BuildContext context) async {
    await _checkAndAwardAchievements(context);
  }

  Future<void> _checkAndAwardAchievements(BuildContext context) async {
    final userId = _client.auth.currentUser!.id;
    final achievementsResponse = await _client.from('achievements').select();
    if (achievementsResponse.error != null) {
      throw achievementsResponse.error!;
    }
    final allAchievements = (achievementsResponse.data as List)
        .map((e) => Achievement.fromJson(e))
        .toList();

    final userAchievementsResponse = await _client
        .from('user_achievements')
        .select('achievement_id')
        .eq('user_id', userId);
    if (userAchievementsResponse.error != null) {
      throw userAchievementsResponse.error!;
    }
    final unlockedAchievementIds = (userAchievementsResponse.data as List)
        .map((e) => e['achievement_id'] as String)
        .toSet();

    for (final achievement in allAchievements) {
      if (!unlockedAchievementIds.contains(achievement.id)) {
        bool conditionMet = false;
        if (achievement.conditionType == 'articles_read') {
          final count = await _getReadArticlesCount(userId);
          if (count >= achievement.conditionValue) {
            conditionMet = true;
          }
        } else if (achievement.conditionType == 'comments_made') {
          final count = await _getCommentsMadeCount(userId);
          if (count >= achievement.conditionValue) {
            conditionMet = true;
          }
        }

        if (conditionMet) {
          await _awardAchievement(context, userId, achievement);
        }
      }
    }
  }

  Future<int> _getReadArticlesCount(String userId) async {
    final response = await _client
        .from('reading_history')
        .select('id', const FetchOptions(count: CountOption.exact))
        .eq('user_id', userId);
    if (response.error != null) {
      throw response.error!;
    }
    return response.count;
  }

  Future<int> _getCommentsMadeCount(String userId) async {
    final response = await _client
        .from('comments')
        .select('id', const FetchOptions(count: CountOption.exact))
        .eq('user_id', userId);
    if (response.error != null) {
      throw response.error!;
    }
    return response.count;
  }

  Future<void> _awardAchievement(
      BuildContext context, String userId, Achievement achievement) async {
    await _client.from('user_achievements').insert({
      'user_id': userId,
      'achievement_id': achievement.id,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(achievement.icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Achievement Unlocked!',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(achievement.name),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
