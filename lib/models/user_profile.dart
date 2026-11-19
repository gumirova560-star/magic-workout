class UserProfile {
  int? id;
  String name;
  String gender;
  int age;
  double height;
  double weight;
  String level;
  String goal;
  List<String> focusAreas;
  List<String> limitations;
  String equipment;
  int daysPerWeek;
  // 👇 НОВОЕ ПОЛЕ: выбранные дни недели тренировок (1=Пн … 7=Вс).
  // Пустой список = пользователь не выбрал, генератор откатится
  // на равномерную раскладку от сегодня.
  List<int> trainingWeekdays;
  int sessionMinutes;
  String? timeRangeLabel; // 👈 НОВОЕ ПОЛЕ: Красивый текст (например, "60-75 мин")
  DateTime createdAt;
  String? avatarPath;
  String? beforePhotoPath;
  String? beforeSidePath;
  String? beforeBackPath;
  String? bodyType;

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
    List<int>? trainingWeekdays, // 👈 НОВОЕ
    this.sessionMinutes = 45,
    this.timeRangeLabel, // 👈
    DateTime? createdAt,
    this.avatarPath,
    this.beforePhotoPath,
    this.beforeSidePath,
    this.beforeBackPath,
    this.bodyType,
  })  : focusAreas = focusAreas ?? [],
        limitations = limitations ?? [],
        trainingWeekdays = trainingWeekdays ?? [], // 👈 НОВОЕ
        createdAt = createdAt ?? DateTime.now();

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
      // 👈 НОВОЕ: сохраняем как строку "2,5", пустой список → NULL
      'trainingWeekdays': trainingWeekdays.isNotEmpty
          ? trainingWeekdays.join(',')
          : null,
      'sessionMinutes': sessionMinutes,
      'timeRangeLabel': timeRangeLabel, // 👈
      'createdAt': createdAt.toIso8601String(),
      'avatarPath': avatarPath,
      'beforePhotoPath': beforePhotoPath,
      'beforeSidePath': beforeSidePath,
      'beforeBackPath': beforeBackPath,
      'bodyType': bodyType,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    // 👈 НОВОЕ: парсим строку "2,5" обратно в список чисел.
    // toSet() вычищает дубли ("2,2,5" → "2,5"), после чего сортируем.
    final weekdaysStr = map['trainingWeekdays'] as String?;
    final trainingWeekdays = (weekdaysStr == null || weekdaysStr.isEmpty)
        ? <int>[]
        : weekdaysStr
        .split(',')
        .map((s) => int.tryParse(s.trim()) ?? 0)
        .where((w) => w >= 1 && w <= 7)
        .toSet()
        .toList()
      ..sort();

    return UserProfile(
      id: map['id'],
      name: map['name'] ?? '',
      gender: map['gender'] ?? 'female',
      age: map['age'] ?? 30,
      height: (map['height'] as num?)?.toDouble() ?? 165.0,
      weight: (map['weight'] as num?)?.toDouble() ?? 60.0,
      level: map['level'] ?? 'beginner',
      goal: map['goal'] ?? 'tone',
      focusAreas: (map['focusAreas'] as String?)?.split(',').where((s) => s.isNotEmpty).toList() ?? [],
      limitations: (map['limitations'] as String?)?.split(',').where((s) => s.isNotEmpty).toList() ?? [],
      equipment: map['equipment'] ?? 'bodyweight',
      daysPerWeek: map['daysPerWeek'] ?? 3,
      trainingWeekdays: trainingWeekdays, // 👈 НОВОЕ
      sessionMinutes: map['sessionMinutes'] ?? 45,
      timeRangeLabel: map['timeRangeLabel'], // 👈
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
      avatarPath: map['avatarPath'],
      beforePhotoPath: map['beforePhotoPath'],
      beforeSidePath: map['beforeSidePath'],
      beforeBackPath: map['beforeBackPath'],
      bodyType: map['bodyType'],
    );
  }

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
    List<int>? trainingWeekdays, // 👈 НОВОЕ
    int? sessionMinutes,
    String? timeRangeLabel, // 👈
    String? avatarPath,
    String? beforePhotoPath,
    String? beforeSidePath,
    String? beforeBackPath,
    String? bodyType,
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
      trainingWeekdays: trainingWeekdays ?? this.trainingWeekdays, // 👈 НОВОЕ
      sessionMinutes: sessionMinutes ?? this.sessionMinutes,
      timeRangeLabel: timeRangeLabel ?? this.timeRangeLabel, // 👈
      createdAt: createdAt,
      avatarPath: avatarPath ?? this.avatarPath,
      beforePhotoPath: beforePhotoPath ?? this.beforePhotoPath,
      beforeSidePath: beforeSidePath ?? this.beforeSidePath,
      beforeBackPath: beforeBackPath ?? this.beforeBackPath,
      bodyType: bodyType ?? this.bodyType,
    );
  }

  // ─── Лейблы ───

  String get genderLabel => gender == 'male' ? 'Мужской' : 'Женский';

  // 👈 НОВОЕ: человекочитаемое расписание для карточки профиля,
  // например "Вт, Пт". Пустой список → "Не выбрано".
  String get trainingWeekdaysLabel {
    if (trainingWeekdays.isEmpty) return 'Не выбрано';
    const names = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return trainingWeekdays.map((w) => names[w - 1]).join(', ');
  }

  String get goalLabel {
    switch (goal) {
      case 'lose_weight': return 'Похудеть';
      case 'gain_mass': return 'Набрать массу';
      case 'tone': return 'Тонус';
      case 'strength': return 'Сила';
      default: return 'Тонус';
    }
  }
  String get levelLabel {
    switch (level) {
      case 'beginner': return 'Новичок';
      case 'intermediate': return 'Средний';
      case 'advanced': return 'Опытный';
      default: return 'Новичок';
    }
  }
  String get equipmentLabel {
    switch (equipment) {
      case 'gym': return 'Зал';
      case 'dumbbells': return 'Гантели';
      case 'bodyweight': return 'Своё тело';
      case 'mixed': return 'Смешанно';
      default: return 'Своё тело';
    }
  }
  String get bodyTypeLabel {
    switch (bodyType) {
      case 'pear': return 'Груша';
      case 'apple': return 'Яблоко';
      case 'hourglass': return 'Песочные часы';
      case 'rectangle': return 'Прямоугольник';
      case 'inverted_triangle': return 'Перевернутый треугольник';
      default: return 'Не выбран';
    }
  }
}
// ═══ КОНЕЦ ФАЙЛА user_profile.dart ═══
