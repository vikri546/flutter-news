import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/achievement.dart';
import '../providers/achievement_provider.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AchievementProvider()..fetchAchievements(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Achievements'),
        ),
        body: Consumer<AchievementProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.errorMessage != null) {
              return Center(child: Text(provider.errorMessage!));
            }

            return ListView.builder(
              itemCount: provider.achievements.length,
              itemBuilder: (context, index) {
                final achievement = provider.achievements[index];
                final isUnlocked = provider.userAchievements
                    .any((ua) => ua.achievementId == achievement.id);
                return ListTile(
                  leading: Text(
                    achievement.icon,
                    style: const TextStyle(fontSize: 24),
                  ),
                  title: Text(achievement.name),
                  subtitle: Text(achievement.description),
                  trailing: isUnlocked
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.lock_outline),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
