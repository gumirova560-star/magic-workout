class WorkoutTemplate {
  int? id;
  int profileId;
  String name;
  String type;
  int estimatedMinutes;
  String? notes;
  DateTime createdAt;

  WorkoutTemplate({
    this.id,
    required this.profileId,
    required this.name,
    this.type = 'strength',
    this.estimatedMinutes = 45,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'name': name,
      'type': type,
      'estimatedMinutes': estimatedMinutes,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory WorkoutTemplate.fromMap(Map<String, dynamic> map) {
    return WorkoutTemplate(
      id: map['id'],
      profileId: map['profileId'] ?? 0,
      name: map['name'] ?? '',
      type: map['type'] ?? 'strength',
      estimatedMinutes: map['estimatedMinutes'] ?? 45,
      notes: map['notes'],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }

  WorkoutTemplate copyWith({
    int? id,
    int? profileId,
    String? name,
    String? type,
    int? estimatedMinutes,
    String? notes,
  }) {
    return WorkoutTemplate(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      name: name ?? this.name,
      type: type ?? this.type,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      notes: notes ?? this.notes,
      createdAt: this.createdAt,
    );
  }

  String get typeLabel {
    switch (type) {
      case 'strength':
        return 'Силовая';
      case 'yoga':
        return 'Йога';
      case 'mixed':
        return 'Смешанная';
      default:
        return 'Силовая';
    }
  }
}

// ═══════════════════════════════════════════════════
//  ЭЛЕМЕНТ ШАБЛОНА
// ═══════════════════════════════════════════════════

class TemplateItem {
  int? id;
  int templateId;
  String itemType;
  int itemId;
  int order;
  int sets;
  String reps;
  int restSeconds;
  int durationSeconds;
  bool isCoolDown;

  // ═══ Поля замены ═══
  int? replacedByItemId;
  String? replacementReason;
  bool replacementPermanent;

  TemplateItem({
    this.id,
    required this.templateId,
    required this.itemType,
    required this.itemId,
    required this.order,
    this.sets = 3,
    this.reps = '10-12',
    this.restSeconds = 60,
    this.durationSeconds = 30,
    this.isCoolDown = false,
    this.replacedByItemId,
    this.replacementReason,
    this.replacementPermanent = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'templateId': templateId,
      'itemType': itemType,
      'itemId': itemId,
      'order': order,
      'sets': sets,
      'reps': reps,
      'restSeconds': restSeconds,
      'durationSeconds': durationSeconds,
      'isCoolDown': isCoolDown ? 1 : 0,
      'replacedByItemId': replacedByItemId,
      'replacementReason': replacementReason,
      'replacementPermanent': replacementPermanent ? 1 : 0,
    };
  }

  factory TemplateItem.fromMap(Map<String, dynamic> map) {
    return TemplateItem(
      id: map['id'],
      templateId: map['templateId'] ?? 0,
      itemType: map['itemType'] ?? 'exercise',
      itemId: map['itemId'] ?? 0,
      order: map['order'] ?? 1,
      sets: map['sets'] ?? 3,
      reps: map['reps'] ?? '10-12',
      restSeconds: map['restSeconds'] ?? 60,
      durationSeconds: map['durationSeconds'] ?? 30,
      isCoolDown: map['isCoolDown'] == 1,
      replacedByItemId: map['replacedByItemId'],
      replacementReason: map['replacementReason'],
      replacementPermanent: map['replacementPermanent'] == 1,
    );
  }

  TemplateItem copyWith({
    int? id,
    int? templateId,
    String? itemType,
    int? itemId,
    int? order,
    int? sets,
    String? reps,
    int? restSeconds,
    int? durationSeconds,
    bool? isCoolDown,
    int? replacedByItemId,
    String? replacementReason,
    bool? replacementPermanent,
  }) {
    return TemplateItem(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      itemType: itemType ?? this.itemType,
      itemId: itemId ?? this.itemId,
      order: order ?? this.order,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      restSeconds: restSeconds ?? this.restSeconds,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isCoolDown: isCoolDown ?? this.isCoolDown,
      replacedByItemId: replacedByItemId ?? this.replacedByItemId,
      replacementReason: replacementReason ?? this.replacementReason,
      replacementPermanent:
          replacementPermanent ?? this.replacementPermanent,
    );
  }
}