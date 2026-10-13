class UserProfile {
  int? id;
  String name;                // «Я», «Жена», «Муж»
  String gender;              // 'male' | 'female'
  int age;                    // лет
  double height;              // см
  double weight;              // кг
  String level;               // 'beginner' | 'intermediate' | 'advanced'
  String goal;                // 'lose_weight' | 'gain_mass' | 'tone' | 'strength'
  List<String> focusAreas;    // ['glutes', 'abs', 'arms']
  List<String> limitations;   // ['back', 'knees']
  String equipment;           // 'gym' | 'dumbbells' | 'bodyweight' | 'mixed'
  int daysPerWeek;            // 2-6
  int sessionMinutes;         // 30 | 45 | 60 | 90
  DateTime createdAt;

  UserProfile({
    this.id,
    required this.name,
    required this.gender,
    required this.age,
    required this.height,
    required this.weight,
    this.level = 'beginner',
    this.goal = 'tone',
    List<String>? focusAreas,
    List<String>? limitations,
    this.equipment = 'bodyweight',
    this.daysPerWeek = 3,
    this.sessionMinutes = 45,
    DateTime? createdAt,
  })  : focusAreas = focusAreas ?? [],
        limitations = limitations ?? [],
        createdAt = createdAt ?? DateTime.now();

  // ═══ Сериализация для БД ═══
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'gender': gender,
      'age': age,
      'height': height,
      'weight': weight,
      'level': level,
      'goal': goal,
      'focusAreas': focusAreas.join(','),
      'limitations': limitations.join(','),
      'equipment': equipment,
      'daysPerWeek': daysPerWeek,
      'sessionMinutes': sessionMinutes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'],
      name: map['name'] ?? '',
      gender: map['gender'] ?? 'female',
      age: map['age'] ?? 30,
      height: (map['height'] as num?)?.toDouble() ?? 165.0,
      weight: (map['weight'] as num?)?.toDouble() ?? 60.0,
      level: map['level'] ?? 'beginner',
      goal: map['goal'] ?? 'tone',
      focusAreas: (map['focusAreas'] as String?)
              ?.split(',')
              .where((s) => s.isNotEmpty)
              .toList() ??
          [],
      limitations: (map['limitations'] as String?)
              ?.split(',')
              .where((s) => s.isNotEmpty)
              .toList() ??
          [],
      equipment: map['equipment'] ?? 'bodyweight',
      daysPerWeek: map['daysPerWeek'] ?? 3,
      sessionMinutes: map['sessionMinutes'] ?? 45,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }

  // ═══ Вспомогательные ═══
  UserProfile copyWith({
    int? id,
    String? name,
    String? gender,
    int? age,
    double? height,
    double? weight,
    String? level,
    String? goal,
    List<String>? focusAreas,
    List<String>? limitations,
    String? equipment,
    int? daysPerWeek,
    int? sessionMinutes,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      level: level ?? this.level,
      goal: goal ?? this.goal,
      focusAreas: focusAreas ?? this.focusAreas,
      limitations: limitations ?? this.limitations,
      equipment: equipment ?? this.equipment,
      daysPerWeek: daysPerWeek ?? this.daysPerWeek,
      sessionMinutes: sessionMinutes ?? this.sessionMinutes,
      createdAt: this.createdAt,
    );
  }

  // ═══ Понятные названия для UI ═══
  String get genderLabel => gender == 'male' ? 'Мужской' : 'Женский';

  String get goalLabel {
    switch (goal) {
      case 'lose_weight':
        return 'Похудеть';
      case 'gain_mass':
        return 'Набрать массу';
      case 'tone':
        return 'Тонус';
      case 'strength':
        return 'Сила';
      default:
        return 'Тонус';
    }
  }

  String get levelLabel {
    switch (level) {
      case 'beginner':
        return 'Новичок';
      case 'intermediate':
        return 'Средний';
      case 'advanced':
        return 'Опытный';
      default:
        return 'Новичок';
    }
  }

  String get equipmentLabel {
    switch (equipment) {
      case 'gym':
        return 'Зал';
      case 'dumbbells':
        return 'Гантели';
      case 'bodyweight':
        return 'Своё тело';
      case 'mixed':
        return 'Смешанно';
      default:
        return 'Своё тело';
    }
  }
}