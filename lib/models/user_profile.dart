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
  // 👇 НОВОЕ: инвентарь для домашних тренировок.
  // Заполняется только если equipment == 'home'.
  // Пустой список = тренировки только с собственным весом.
  List<String> homeEquipment;
  int daysPerWeek;
  // 👇 выбранные дни недели тренировок (1=Пн … 7=Вс).
  // Пустой список = генератор откатится на равномерную раскладку от сегодня.
  List<int> trainingWeekdays;
  int sessionMinutes;
  String? timeRangeLabel;
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
    this.equipment = 'gym', // 👈 дефолт «зал» — безопасный для новых профилей
    List<String>? homeEquipment, // 👈 НОВОЕ
    this.daysPerWeek = 3,
    List<int>? trainingWeekdays,
    this.sessionMinutes = 45,
    this.timeRangeLabel,
    DateTime? createdAt,
    this.avatarPath,
    this.beforePhotoPath,
    this.beforeSidePath,
    this.beforeBackPath,
    this.bodyType,
  })  : focusAreas = focusAreas ?? [],
        limitations = limitations ?? [],
        homeEquipment = homeEquipment ?? [], // 👈 НОВОЕ
        trainingWeekdays = trainingWeekdays ?? [],
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
      // 👈 НОВОЕ: пустой список → NULL, чтобы не писать пустую строку
      'homeEquipment': homeEquipment.isNotEmpty
          ? homeEquipment.join(',')
          : null,
      'daysPerWeek': daysPerWeek,
      'trainingWeekdays': trainingWeekdays.isNotEmpty
          ? trainingWeekdays.join(',')
          : null,
      'sessionMinutes': sessionMinutes,
      'timeRangeLabel': timeRangeLabel,
      'createdAt': createdAt.toIso8601String(),
      'avatarPath': avatarPath,
      'beforePhotoPath': beforePhotoPath,
      'beforeSidePath': beforeSidePath,
      'beforeBackPath': beforeBackPath,
      'bodyType': bodyType,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
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

    // 👈 НОВОЕ: парсим инвентарь домашних тренировок
    final homeEqStr = map['homeEquipment'] as String?;
    final homeEquipment = (homeEqStr == null || homeEqStr.isEmpty)
        ? <String>[]
        : homeEqStr
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();

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
      equipment: map['equipment'] ?? 'gym',
      homeEquipment: homeEquipment, // 👈 НОВОЕ
      daysPerWeek: map['daysPerWeek'] ?? 3,
      trainingWeekdays: trainingWeekdays,
      sessionMinutes: map['sessionMinutes'] ?? 45,
      timeRangeLabel: map['timeRangeLabel'],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
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
    List<String>? homeEquipment, // 👈 НОВОЕ
    int? daysPerWeek,
    List<int>? trainingWeekdays,
    int? sessionMinutes,
    String? timeRangeLabel,
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
      homeEquipment: homeEquipment ?? this.homeEquipment, // 👈 НОВОЕ
      daysPerWeek: daysPerWeek ?? this.daysPerWeek,
      trainingWeekdays: trainingWeekdays ?? this.trainingWeekdays,
      sessionMinutes: sessionMinutes ?? this.sessionMinutes,
      timeRangeLabel: timeRangeLabel ?? this.timeRangeLabel,
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

  String get trainingWeekdaysLabel {
    if (trainingWeekdays.isEmpty) return 'Не выбрано';
    const names = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return trainingWeekdays.map((w) => names[w - 1]).join(', ');
  }

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

  // 👈 ОБНОВЛЕНО: добавлен 'home' + поддержка старых значений.
  // Старые профили до миграции ещё могут приходить с bodyweight /
  // dumbbells / mixed — им показываем адекватные подписи.
  String get equipmentLabel {
    switch (equipment) {
      case 'gym':
        return 'Тренажёрный зал';
      case 'home':
        if (homeEquipment.isEmpty) return 'Дом (своё тело)';
        const names = {
          'dumbbells': 'гантели',
          'barbell': 'штанга',
          'resistance_band': 'резинка',
          'ball': 'мяч',
          'jump_rope': 'скакалка',
          'pull_up_bar': 'турник',
          'bench': 'скамья',
          'treadmill': 'дорожка',          // 👈 НОВОЕ
          'elliptical': 'эллипс',          // 👈 НОВОЕ
          'bike': 'велотренажёр',          // 👈 НОВОЕ
          'rower': 'гребной тренажёр',     // 👈 НОВОЕ
        };
        final list = homeEquipment.map((e) => names[e] ?? e).join(', ');
        return 'Дом ($list)';
    // legacy
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

  String get bodyTypeLabel {
    switch (bodyType) {
      case 'pear':
        return 'Груша';
      case 'apple':
        return 'Яблоко';
      case 'hourglass':
        return 'Песочные часы';
      case 'rectangle':
        return 'Прямоугольник';
      case 'inverted_triangle':
        return 'Перевернутый треугольник';
      default:
        return 'Не выбран';
    }
  }
}
// ═══ КОНЕЦ ФАЙЛА user_profile.dart ═══