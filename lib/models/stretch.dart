class Stretch {
  int? id;
  String name;              // «Поза голубя» / «Растяжка ягодиц»
  String category;          // 'classic' | 'yoga'
  String muscleGroup;       // 'glutes', 'back', 'hips', 'hamstrings'
  int durationSeconds;      // 30 / 45 / 60
  bool bothSides;           // true — на обе стороны
  String description;       // что даёт
  String technique;         // как делать
  String benefits;          // польза
  String? imagePath;        // assets/stretches/pigeon_pose.jpg
  String? videoUrl;         // опционально
  bool isCustom;            // true — добавлено пользователем

  Stretch({
    this.id,
    required this.name,
    this.category = 'classic',
    required this.muscleGroup,
    this.durationSeconds = 30,
    this.bothSides = true,
    this.description = '',
    this.technique = '',
    this.benefits = '',
    this.imagePath,
    this.videoUrl,
    this.isCustom = false,
  });

  // ═══ Сериализация для БД ═══
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'muscleGroup': muscleGroup,
      'durationSeconds': durationSeconds,
      'bothSides': bothSides ? 1 : 0,
      'description': description,
      'technique': technique,
      'benefits': benefits,
      'imagePath': imagePath,
      'videoUrl': videoUrl,
      'isCustom': isCustom ? 1 : 0,
    };
  }

  factory Stretch.fromMap(Map<String, dynamic> map) {
    return Stretch(
      id: map['id'],
      name: map['name'] ?? '',
      category: map['category'] ?? 'classic',
      muscleGroup: map['muscleGroup'] ?? '',
      durationSeconds: map['durationSeconds'] ?? 30,
      bothSides: map['bothSides'] == 1,
      description: map['description'] ?? '',
      technique: map['technique'] ?? '',
      benefits: map['benefits'] ?? '',
      imagePath: map['imagePath'],
      videoUrl: map['videoUrl'],
      isCustom: map['isCustom'] == 1,
    );
  }

  Stretch copyWith({
    int? id,
    String? name,
    String? category,
    String? muscleGroup,
    int? durationSeconds,
    bool? bothSides,
    String? description,
    String? technique,
    String? benefits,
    String? imagePath,
    String? videoUrl,
    bool? isCustom,
  }) {
    return Stretch(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      bothSides: bothSides ?? this.bothSides,
      description: description ?? this.description,
      technique: technique ?? this.technique,
      benefits: benefits ?? this.benefits,
      imagePath: imagePath ?? this.imagePath,
      videoUrl: videoUrl ?? this.videoUrl,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  // ═══ Понятные названия для UI ═══
  String get categoryLabel {
    switch (category) {
      case 'yoga':
        return 'Йога';
      case 'classic':
      default:
        return 'Растяжка';
    }
  }

  String get durationLabel {
    if (durationSeconds < 60) {
      return '$durationSeconds сек';
    }
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    if (seconds == 0) {
      return '$minutes мин';
    }
    return '$minutes мин $seconds сек';
  }
}