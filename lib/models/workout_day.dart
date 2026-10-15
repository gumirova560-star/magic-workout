class WorkoutDay {
  int? id;
  int profileId;
  int? templateId;             // если создан из шаблона
  String name;                 // «День ног», «Йога для спины»
  String type;                 // 'strength' | 'yoga' | 'mixed'
  DateTime date;
  String status;               // 'planned' | 'in_progress' | 'completed' | 'skipped'
  int? durationMinutes;        // фактическое время
  String? notes;
  DateTime? startedAt;
  DateTime? completedAt;

  WorkoutDay({
    this.id,
    required this.profileId,
    this.templateId,
    required this.name,
    this.type = 'strength',
    DateTime? date,
    this.status = 'planned',
    this.durationMinutes,
    this.notes,
    this.startedAt,
    this.completedAt,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'templateId': templateId,
      'name': name,
      'type': type,
      'date': date.toIso8601String(),
      'status': status,
      'durationMinutes': durationMinutes,
      'notes': notes,
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory WorkoutDay.fromMap(Map<String, dynamic> map) {
    return WorkoutDay(
      id: map['id'],
      profileId: map['profileId'] ?? 0,
      templateId: map['templateId'],
      name: map['name'] ?? '',
      type: map['type'] ?? 'strength',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      status: map['status'] ?? 'planned',
      durationMinutes: map['durationMinutes'],
      notes: map['notes'],
      startedAt: map['startedAt'] != null
          ? DateTime.parse(map['startedAt'])
          : null,
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'])
          : null,
    );
  }

  WorkoutDay copyWith({
    int? id,
    int? profileId,
    int? templateId,
    String? name,
    String? type,
    DateTime? date,
    String? status,
    int? durationMinutes,
    String? notes,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return WorkoutDay(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      templateId: templateId ?? this.templateId,
      name: name ?? this.name,
      type: type ?? this.type,
      date: date ?? this.date,
      status: status ?? this.status,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      notes: notes ?? this.notes,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'planned':
        return 'Запланирована';
      case 'in_progress':
        return 'В процессе';
      case 'completed':
        return 'Завершена';
      case 'skipped':
        return 'Пропущена';
      default:
        return 'Запланирована';
    }
  }
}

// ═══════════════════════════════════════════════════
//  УПРАЖНЕНИЕ В ДНЕ
// ═══════════════════════════════════════════════════

class WorkoutExercise {
  int? id;
  int workoutDayId;
  String itemType;              // 'exercise' | 'stretch'
  int itemId;                   // id Exercise или Stretch
  int order;

  // ═══ Замена ═══
  int? replacedByItemId;        // id нового упражнения
  String? replacementReason;    // 'no_equipment' | 'too_hard' | 'too_easy' | 'dislike' | 'other'
  bool replacementPermanent;    // заменить навсегда?

  // ═══ Параметры ═══
  int sets;
  String reps;
  int restSeconds;
  int durationSeconds;          // для растяжки
  bool isCoolDown;              // заминка?
  String? notes;

  // ⚠️ НОВОЕ: номер блока (1, 2, 3...)
  int? blockNumber;

  WorkoutExercise({
    this.id,
    required this.workoutDayId,
    required this.itemType,
    required this.itemId,
    required this.order,
    this.replacedByItemId,
    this.replacementReason,
    this.replacementPermanent = false,
    this.sets = 3,
    this.reps = '10-12',
    this.restSeconds = 60,
    this.durationSeconds = 30,
    this.isCoolDown = false,
    this.notes,
    this.blockNumber,             // ⚠️ НОВОЕ
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workoutDayId': workoutDayId,
      'itemType': itemType,
      'itemId': itemId,
      'order': order,
      'replacedByItemId': replacedByItemId,
      'replacementReason': replacementReason,
      'replacementPermanent': replacementPermanent ? 1 : 0,
      'sets': sets,
      'reps': reps,
      'restSeconds': restSeconds,
      'durationSeconds': durationSeconds,
      'isCoolDown': isCoolDown ? 1 : 0,
      'notes': notes,
      'blockNumber': blockNumber,     // ⚠️ НОВОЕ
    };
  }

  factory WorkoutExercise.fromMap(Map<String, dynamic> map) {
    return WorkoutExercise(
      id: map['id'],
      workoutDayId: map['workoutDayId'] ?? 0,
      itemType: map['itemType'] ?? 'exercise',
      itemId: map['itemId'] ?? 0,
      order: map['order'] ?? 1,
      replacedByItemId: map['replacedByItemId'],
      replacementReason: map['replacementReason'],
      replacementPermanent: map['replacementPermanent'] == 1,
      sets: map['sets'] ?? 3,
      reps: map['reps'] ?? '10-12',
      restSeconds: map['restSeconds'] ?? 60,
      durationSeconds: map['durationSeconds'] ?? 30,
      isCoolDown: map['isCoolDown'] == 1,
      notes: map['notes'],
      blockNumber: map['blockNumber'],  // ⚠️ НОВОЕ
    );
  }

  WorkoutExercise copyWith({
    int? id,
    int? workoutDayId,
    String? itemType,
    int? itemId,
    int? order,
    int? replacedByItemId,
    String? replacementReason,
    bool? replacementPermanent,
    int? sets,
    String? reps,
    int? restSeconds,
    int? durationSeconds,
    bool? isCoolDown,
    String? notes,
    int? blockNumber,               // ⚠️ НОВОЕ
  }) {
    return WorkoutExercise(
      id: id ?? this.id,
      workoutDayId: workoutDayId ?? this.workoutDayId,
      itemType: itemType ?? this.itemType,
      itemId: itemId ?? this.itemId,
      order: order ?? this.order,
      replacedByItemId: replacedByItemId ?? this.replacedByItemId,
      replacementReason: replacementReason ?? this.replacementReason,
      replacementPermanent:
          replacementPermanent ?? this.replacementPermanent,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      restSeconds: restSeconds ?? this.restSeconds,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isCoolDown: isCoolDown ?? this.isCoolDown,
      notes: notes ?? this.notes,
      blockNumber: blockNumber ?? this.blockNumber,  // ⚠️ НОВОЕ
    );
  }

  /// Какое упражнение реально выполняется — оригинал или замена
  int get effectiveItemId => replacedByItemId ?? itemId;

  bool get isReplaced => replacedByItemId != null;
}

// ═══════════════════════════════════════════════════
//  ПОДХОД
// ═══════════════════════════════════════════════════

class WorkoutSet {
  int? id;
  int workoutExerciseId;
  int order;                    // 1, 2, 3...
  double? weight;               // кг
  int? reps;                    // выполнено повторений
  bool completed;               // галочка «сделано»
  String? notes;

  WorkoutSet({
    this.id,
    required this.workoutExerciseId,
    required this.order,
    this.weight,
    this.reps,
    this.completed = false,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workoutExerciseId': workoutExerciseId,
      'order': order,
      'weight': weight,
      'reps': reps,
      'completed': completed ? 1 : 0,
      'notes': notes,
    };
  }

  factory WorkoutSet.fromMap(Map<String, dynamic> map) {
    return WorkoutSet(
      id: map['id'],
      workoutExerciseId: map['workoutExerciseId'] ?? 0,
      order: map['order'] ?? 1,
      weight: (map['weight'] as num?)?.toDouble(),
      reps: map['reps'],
      completed: map['completed'] == 1,
      notes: map['notes'],
    );
  }

  WorkoutSet copyWith({
    int? id,
    int? workoutExerciseId,
    int? order,
    double? weight,
    int? reps,
    bool? completed,
    String? notes,
  }) {
    return WorkoutSet(
      id: id ?? this.id,
      workoutExerciseId: workoutExerciseId ?? this.workoutExerciseId,
      order: order ?? this.order,
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      completed: completed ?? this.completed,
      notes: notes ?? this.notes,
    );
  }
}