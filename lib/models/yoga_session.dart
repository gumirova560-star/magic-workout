class YogaSession {
  int? id;
  String name;              // «Йога для спины»
  String focus;             // 'back' | 'flexibility' | 'relax' | 'glutes' | 'morning'
  int durationMinutes;      // 20 / 25 / 30
  String description;       // что даёт
  bool isCustom;            // true — пользователь создал сам

  YogaSession({
    this.id,
    required this.name,
    required this.focus,
    this.durationMinutes = 25,
    this.description = '',
    this.isCustom = false,
  });

  // ═══ Сериализация ═══
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'focus': focus,
      'durationMinutes': durationMinutes,
      'description': description,
      'isCustom': isCustom ? 1 : 0,
    };
  }

  factory YogaSession.fromMap(Map<String, dynamic> map) {
    return YogaSession(
      id: map['id'],
      name: map['name'] ?? '',
      focus: map['focus'] ?? 'relax',
      durationMinutes: map['durationMinutes'] ?? 25,
      description: map['description'] ?? '',
      isCustom: map['isCustom'] == 1,
    );
  }

  YogaSession copyWith({
    int? id,
    String? name,
    String? focus,
    int? durationMinutes,
    String? description,
    bool? isCustom,
  }) {
    return YogaSession(
      id: id ?? this.id,
      name: name ?? this.name,
      focus: focus ?? this.focus,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      description: description ?? this.description,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  String get focusLabel {
    switch (focus) {
      case 'back':
        return 'Для спины';
      case 'flexibility':
        return 'Для гибкости';
      case 'relax':
        return 'Для расслабления';
      case 'glutes':
        return 'Для ягодиц и бёдер';
      case 'morning':
        return 'Утренняя';
      default:
        return 'Йога';
    }
  }

  String get durationLabel => '$durationMinutes мин';
}

// ═══════════════════════════════════════════════════
//  ШАГ ЙОГА-СЕССИИ
// ═══════════════════════════════════════════════════

class YogaStep {
  int? id;
  int sessionId;            // какой сессии принадлежит
  int stretchId;            // ссылка на Stretch
  int order;                // 1, 2, 3...
  int durationSeconds;      // длительность именно в этой сессии
  bool bothSides;           // на обе стороны?
  String? notes;            // комментарий

  YogaStep({
    this.id,
    required this.sessionId,
    required this.stretchId,
    required this.order,
    this.durationSeconds = 30,
    this.bothSides = true,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sessionId': sessionId,
      'stretchId': stretchId,
      'order': order,
      'durationSeconds': durationSeconds,
      'bothSides': bothSides ? 1 : 0,
      'notes': notes,
    };
  }

  factory YogaStep.fromMap(Map<String, dynamic> map) {
    return YogaStep(
      id: map['id'],
      sessionId: map['sessionId'] ?? 0,
      stretchId: map['stretchId'] ?? 0,
      order: map['order'] ?? 1,
      durationSeconds: map['durationSeconds'] ?? 30,
      bothSides: map['bothSides'] == 1,
      notes: map['notes'],
    );
  }
}