import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/achievement.dart';

class AchievementProvider with ChangeNotifier {
  List<Achievement> _achievements = [];
  List<UserAchievement> _userAchievements = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Achievement> get achievements => _achievements;
  List<UserAchievement> get userAchievements => _userAchievements;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchAchievements() async {
    _isLoading = true;
    notifyListeners();

    try {
      final achievementsResponse =
          await Supabase.instance.client.from('achievements').select();
      if (achievementsResponse.error != null) {
        throw achievementsResponse.error!;
      }
      _achievements = (achievementsResponse.data as List)
          .map((e) => Achievement.fromJson(e))
          .toList();

      final userAchievementsResponse = await Supabase.instance.client
          .from('user_achievements')
          .select()
          .eq('user_id', Supabase.instance.client.auth.currentUser!.id);
      if (userAchievementsResponse.error != null) {
        throw userAchievementsResponse.error!;
      }
      _userAchievements = (userAchievementsResponse.data as List)
          .map((e) => UserAchievement.fromJson(e))
          .toList();
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }
}
