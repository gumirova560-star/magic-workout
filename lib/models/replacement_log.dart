class ReplacementLog {
  int? id;
  int profileId;              // чей профиль
  int workoutDayId;           // в какой тренировке
  String itemType;            // 'exercise' | 'stretch'
  int originalItemId;         // что меняли
  int newItemId;              // на что поменяли
  String reason;              // 'no_equipment' | 'too_hard' | 'too_easy' | 'dislike' | 'other'
  String? notes;              // комментарий
  bool permanent;             // замена навсегда?
  DateTime createdAt;

  ReplacementLog({
    this.id,
    required this.profileId,
    required this.workoutDayId,
    required this.itemType,
    required this.originalItemId,
    required this.newItemId,
    required this.reason,
    this.notes,
    this.permanent = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'workoutDayId': workoutDayId,
      'itemType': itemType,
      'originalItemId': originalItemId,
      'newItemId': newItemId,
      'reason': reason,
      'notes': notes,
      'permanent': permanent ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ReplacementLog.fromMap(Map<String, dynamic> map) {
    return ReplacementLog(
      id: map['id'],
      profileId: map['profileId'] ?? 0,
      workoutDayId: map['workoutDayId'] ?? 0,
      itemType: map['itemType'] ?? 'exercise',
      originalItemId: map['originalItemId'] ?? 0,
      newItemId: map['newItemId'] ?? 0,
      reason: map['reason'] ?? 'other',
      notes: map['notes'],
      permanent: map['permanent'] == 1,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }

  ReplacementLog copyWith({
    int? id,
    int? profileId,
    int? workoutDayId,
    String? itemType,
    int? originalItemId,
    int? newItemId,
    String? reason,
    String? notes,
    bool? permanent,
  }) {
    return ReplacementLog(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      workoutDayId: workoutDayId ?? this.workoutDayId,
      itemType: itemType ?? this.itemType,
      originalItemId: originalItemId ?? this.originalItemId,
      newItemId: newItemId ?? this.newItemId,
      reason: reason ?? this.reason,
      notes: notes ?? this.notes,
      permanent: permanent ?? this.permanent,
      createdAt: this.createdAt,
    );
  }

  String get reasonLabel {
    switch (reason) {
      case 'no_equipment':
        return 'Нет оборудования';
      case 'too_hard':
        return 'Слишком тяжело';
      case 'too_easy':
        return 'Слишком легко';
      case 'dislike':
        return 'Не нравится';
      case 'other':
      default:
        return 'Другое';
    }
  }
}