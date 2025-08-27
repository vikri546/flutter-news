class Achievement {
  final String id;
  final String name;
  final String description;
  final String icon;
  final String conditionType;
  final int conditionValue;

  Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.conditionType,
    required this.conditionValue,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      icon: json['icon'],
      conditionType: json['condition_type'],
      conditionValue: json['condition_value'],
    );
  }
}

class UserAchievement {
  final String id;
  final String userId;
  final String achievementId;
  final DateTime unlockedAt;

  UserAchievement({
    required this.id,
    required this.userId,
    required this.achievementId,
    required this.unlockedAt,
  });

  factory UserAchievement.fromJson(Map<String, dynamic> json) {
    return UserAchievement(
      id: json['id'],
      userId: json['user_id'],
      achievementId: json['achievement_id'],
      unlockedAt: DateTime.parse(json['unlocked_at']),
    );
  }
}
