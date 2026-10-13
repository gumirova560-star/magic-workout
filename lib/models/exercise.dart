class Exercise {
  int? id;
  String name;                    // «Ягодичный мост со штангой»
  List<String> muscleGroups;      // ['glutes', 'hamstrings']
  List<String> equipment;         // ['barbell', 'bench']
  String difficulty;              // 'beginner' | 'intermediate' | 'advanced'
  List<String> contraindications; // ['back', 'knees']
  String description;             // краткое описание
  String technique;               // техника выполнения
  String mistakes;                // частые ошибки
  String tips;                    // советы
  String? imagePath;              // assets/exercises/glute_bridge.jpg
  String? videoUrl;               // опционально
  List<int> alternativeIds;       // id других упражнений
  bool isCustom;                  // true — добавлено пользователем

  Exercise({
    this.id,
    required this.name,
    required this.muscleGroups,
    required this.equipment,
    this.difficulty = 'beginner',
    List<String>? contraindications,
    this.description = '',
    this.technique = '',
    this.mistakes = '',
    this.tips = '',
    this.imagePath,
    this.videoUrl,
    List<int>? alternativeIds,
    this.isCustom = false,
  })  : contraindications = contraindications ?? [],
        alternativeIds = alternativeIds ?? [];

  // ═══ Сериализация для БД ═══
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'muscleGroups': muscleGroups.join(','),
      'equipment': equipment.join(','),
      'difficulty': difficulty,
      'contraindications': contraindications.join(','),
      'description': description,
      'technique': technique,
      'mistakes': mistakes,
      'tips': tips,
      'imagePath': imagePath,
      'videoUrl': videoUrl,
      'alternativeIds': alternativeIds.join(','),
      'isCustom': isCustom ? 1 : 0,
    };
  }

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id'],
      name: map['name'] ?? '',
      muscleGroups: (map['muscleGroups'] as String?)
              ?.split(',')
              .where((s) => s.isNotEmpty)
              .toList() ??
          [],
      equipment: (map['equipment'] as String?)
              ?.split(',')
              .where((s) => s.isNotEmpty)
              .toList() ??
          [],
      difficulty: map['difficulty'] ?? 'beginner',
      contraindications: (map['contraindications'] as String?)
              ?.split(',')
              .where((s) => s.isNotEmpty)
              .toList() ??
          [],
      description: map['description'] ?? '',
      technique: map['technique'] ?? '',
      mistakes: map['mistakes'] ?? '',
      tips: map['tips'] ?? '',
      imagePath: map['imagePath'],
      videoUrl: map['videoUrl'],
      alternativeIds: (map['alternativeIds'] as String?)
              ?.split(',')
              .where((s) => s.isNotEmpty)
              .map((s) => int.tryParse(s) ?? 0)
              .where((i) => i > 0)
              .toList() ??
          [],
      isCustom: map['isCustom'] == 1,
    );
  }

  Exercise copyWith({
    int? id,
    String? name,
    List<String>? muscleGroups,
    List<String>? equipment,
    String? difficulty,
    List<String>? contraindications,
    String? description,
    String? technique,
    String? mistakes,
    String? tips,
    String? imagePath,
    String? videoUrl,
    List<int>? alternativeIds,
    bool? isCustom,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      muscleGroups: muscleGroups ?? this.muscleGroups,
      equipment: equipment ?? this.equipment,
      difficulty: difficulty ?? this.difficulty,
      contraindications: contraindications ?? this.contraindications,
      description: description ?? this.description,
      technique: technique ?? this.technique,
      mistakes: mistakes ?? this.mistakes,
      tips: tips ?? this.tips,
      imagePath: imagePath ?? this.imagePath,
      videoUrl: videoUrl ?? this.videoUrl,
      alternativeIds: alternativeIds ?? this.alternativeIds,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  // ═══ Понятные названия для UI ═══
  String get difficultyLabel {
    switch (difficulty) {
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
}