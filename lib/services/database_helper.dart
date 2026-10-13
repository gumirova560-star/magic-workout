import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../models/user_profile.dart';
import '../models/exercise.dart';
import '../models/stretch.dart';
import '../models/yoga_session.dart';
import '../models/workout_template.dart';
import '../models/workout_day.dart';
import '../models/replacement_log.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  static const int _dbVersion = 2;
  static const String _dbName = 'workout_tracker.db';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(_dbName);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      return await databaseFactory.openDatabase(
        filePath,
        options: OpenDatabaseOptions(
          version: _dbVersion,
          onCreate: _createDB,
          onUpgrade: _upgradeDB,
        ),
      );
    }

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      final dir = await getApplicationDocumentsDirectory();
      final path = join(dir.path, filePath);
      return await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: _dbVersion,
          onCreate: _createDB,
          onUpgrade: _upgradeDB,
        ),
      );
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  СОЗДАНИЕ ТАБЛИЦ
  // ═══════════════════════════════════════════════════════════

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE user_profiles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        gender TEXT NOT NULL,
        age INTEGER NOT NULL,
        height REAL NOT NULL,
        weight REAL NOT NULL,
        level TEXT NOT NULL,
        goal TEXT NOT NULL,
        focusAreas TEXT,
        limitations TEXT,
        equipment TEXT NOT NULL,
        daysPerWeek INTEGER NOT NULL,
        sessionMinutes INTEGER NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        muscleGroups TEXT,
        equipment TEXT,
        difficulty TEXT NOT NULL,
        contraindications TEXT,
        description TEXT,
        technique TEXT,
        mistakes TEXT,
        tips TEXT,
        imagePath TEXT,
        videoUrl TEXT,
        alternativeIds TEXT,
        isCustom INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE stretches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        muscleGroup TEXT NOT NULL,
        durationSeconds INTEGER NOT NULL,
        bothSides INTEGER DEFAULT 1,
        description TEXT,
        technique TEXT,
        benefits TEXT,
        imagePath TEXT,
        videoUrl TEXT,
        isCustom INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE yoga_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        focus TEXT NOT NULL,
        durationMinutes INTEGER NOT NULL,
        description TEXT,
        isCustom INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE yoga_steps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sessionId INTEGER NOT NULL,
        stretchId INTEGER NOT NULL,
        "order" INTEGER NOT NULL,
        durationSeconds INTEGER NOT NULL,
        bothSides INTEGER DEFAULT 1,
        notes TEXT,
        FOREIGN KEY (sessionId) REFERENCES yoga_sessions (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profileId INTEGER NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        estimatedMinutes INTEGER NOT NULL,
        notes TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE template_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        templateId INTEGER NOT NULL,
        itemType TEXT NOT NULL,
        itemId INTEGER NOT NULL,
        "order" INTEGER NOT NULL,
        sets INTEGER DEFAULT 3,
        reps TEXT,
        restSeconds INTEGER DEFAULT 60,
        durationSeconds INTEGER DEFAULT 30,
        isCoolDown INTEGER DEFAULT 0,
        replacedByItemId INTEGER,
        replacementReason TEXT,
        replacementPermanent INTEGER DEFAULT 0,
        FOREIGN KEY (templateId) REFERENCES workout_templates (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_days (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profileId INTEGER NOT NULL,
        templateId INTEGER,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        date TEXT NOT NULL,
        status TEXT NOT NULL,
        durationMinutes INTEGER,
        notes TEXT,
        startedAt TEXT,
        completedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workoutDayId INTEGER NOT NULL,
        itemType TEXT NOT NULL,
        itemId INTEGER NOT NULL,
        "order" INTEGER NOT NULL,
        replacedByItemId INTEGER,
        replacementReason TEXT,
        replacementPermanent INTEGER DEFAULT 0,
        sets INTEGER DEFAULT 3,
        reps TEXT,
        restSeconds INTEGER DEFAULT 60,
        durationSeconds INTEGER DEFAULT 30,
        isCoolDown INTEGER DEFAULT 0,
        notes TEXT,
        FOREIGN KEY (workoutDayId) REFERENCES workout_days (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_sets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workoutExerciseId INTEGER NOT NULL,
        "order" INTEGER NOT NULL,
        weight REAL,
        reps INTEGER,
        completed INTEGER DEFAULT 0,
        notes TEXT,
        FOREIGN KEY (workoutExerciseId) REFERENCES workout_exercises (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE replacement_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profileId INTEGER NOT NULL,
        workoutDayId INTEGER NOT NULL,
        itemType TEXT NOT NULL,
        originalItemId INTEGER NOT NULL,
        newItemId INTEGER NOT NULL,
        reason TEXT NOT NULL,
        notes TEXT,
        permanent INTEGER DEFAULT 0,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_workout_days_profile ON workout_days (profileId, date)');
    await db.execute(
        'CREATE INDEX idx_workout_exercises_day ON workout_exercises (workoutDayId)');
    await db.execute(
        'CREATE INDEX idx_workout_sets_exercise ON workout_sets (workoutExerciseId)');
    await db.execute(
        'CREATE INDEX idx_replacement_profile ON replacement_logs (profileId)');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE template_items ADD COLUMN replacedByItemId INTEGER');
      await db.execute(
          'ALTER TABLE template_items ADD COLUMN replacementReason TEXT');
      await db.execute(
          'ALTER TABLE template_items ADD COLUMN replacementPermanent INTEGER DEFAULT 0');
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  ПРОФИЛИ
  // ═══════════════════════════════════════════════════════════

  Future<int> addProfile(UserProfile profile) async {
    final db = await database;
    return await db.insert('user_profiles', profile.toMap());
  }

  Future<List<UserProfile>> getProfiles() async {
    final db = await database;
    final maps = await db.query('user_profiles', orderBy: 'createdAt ASC');
    return maps.map((m) => UserProfile.fromMap(m)).toList();
  }

  Future<UserProfile?> getProfileById(int id) async {
    final db = await database;
    final maps = await db.query(
      'user_profiles',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return UserProfile.fromMap(maps.first);
  }

  Future<int> updateProfile(UserProfile profile) async {
    final db = await database;
    return await db.update(
      'user_profiles',
      profile.toMap(),
      where: 'id = ?',
      whereArgs: [profile.id],
    );
  }

  Future<int> deleteProfile(int id) async {
    final db = await database;
    return await db.delete(
      'user_profiles',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  УПРАЖНЕНИЯ
  // ═══════════════════════════════════════════════════════════

  Future<int> addExercise(Exercise exercise) async {
    final db = await database;
    return await db.insert('exercises', exercise.toMap());
  }

  Future<List<Exercise>> getExercises() async {
    final db = await database;
    final maps = await db.query('exercises', orderBy: 'name ASC');
    return maps.map((m) => Exercise.fromMap(m)).toList();
  }

  Future<Exercise?> getExerciseById(int id) async {
    final db = await database;
    final maps = await db.query(
      'exercises',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Exercise.fromMap(maps.first);
  }

  Future<int> countExercises() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM exercises');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ═══════════════════════════════════════════════════════════
  //  РАСТЯЖКИ
  // ═══════════════════════════════════════════════════════════

  Future<int> addStretch(Stretch stretch) async {
    final db = await database;
    return await db.insert('stretches', stretch.toMap());
  }

  Future<List<Stretch>> getStretches() async {
    final db = await database;
    final maps = await db.query('stretches', orderBy: 'name ASC');
    return maps.map((m) => Stretch.fromMap(m)).toList();
  }

  Future<Stretch?> getStretchById(int id) async {
    final db = await database;
    final maps = await db.query(
      'stretches',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Stretch.fromMap(maps.first);
  }

  Future<Stretch?> getStretchByName(String name) async {
    final db = await database;
    final maps = await db.query(
      'stretches',
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Stretch.fromMap(maps.first);
  }

  // ═══════════════════════════════════════════════════════════
  //  ЙОГА
  // ═══════════════════════════════════════════════════════════

  Future<int> addYogaSession(YogaSession session) async {
    final db = await database;
    return await db.insert('yoga_sessions', session.toMap());
  }

  Future<List<YogaSession>> getYogaSessions() async {
    final db = await database;
    final maps = await db.query('yoga_sessions', orderBy: 'name ASC');
    return maps.map((m) => YogaSession.fromMap(m)).toList();
  }

  Future<int> addYogaStep(YogaStep step) async {
    final db = await database;
    return await db.insert('yoga_steps', step.toMap());
  }

  Future<List<YogaStep>> getYogaSteps(int sessionId) async {
    final db = await database;
    final maps = await db.query(
      'yoga_steps',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
      orderBy: '"order" ASC',
    );
    return maps.map((m) => YogaStep.fromMap(m)).toList();
  }

  // ═══════════════════════════════════════════════════════════
  //  ШАБЛОНЫ
  // ═══════════════════════════════════════════════════════════

  Future<int> saveTemplate(WorkoutTemplate template) async {
    final db = await database;
    if (template.id == null) {
      return await db.insert('workout_templates', template.toMap());
    } else {
      await db.update(
        'workout_templates',
        template.toMap(),
        where: 'id = ?',
        whereArgs: [template.id],
      );
      return template.id!;
    }
  }

  Future<List<WorkoutTemplate>> getTemplates(int profileId) async {
    final db = await database;
    final maps = await db.query(
      'workout_templates',
      where: 'profileId = ?',
      whereArgs: [profileId],
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => WorkoutTemplate.fromMap(m)).toList();
  }

  Future<WorkoutTemplate?> getTemplateById(int id) async {
    final db = await database;
    final maps = await db.query(
      'workout_templates',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return WorkoutTemplate.fromMap(maps.first);
  }

  Future<int> deleteTemplate(int id) async {
    final db = await database;
    return await db.delete(
      'workout_templates',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> addTemplateItem(TemplateItem item) async {
    final db = await database;
    return await db.insert('template_items', item.toMap());
  }

  Future<List<TemplateItem>> getTemplateItems(int templateId) async {
    final db = await database;
    final maps = await db.query(
      'template_items',
      where: 'templateId = ?',
      whereArgs: [templateId],
      orderBy: '"order" ASC',
    );
    return maps.map((m) => TemplateItem.fromMap(m)).toList();
  }

  // ═══════════════════════════════════════════════════════════
  //  ДНИ ТРЕНИРОВОК
  // ═══════════════════════════════════════════════════════════

  Future<int> createWorkoutDay(WorkoutDay day) async {
    final db = await database;
    return await db.insert('workout_days', day.toMap());
  }

  Future<List<WorkoutDay>> getWorkoutDays({
    required int profileId,
    int limit = 100,
  }) async {
    final db = await database;
    final maps = await db.query(
      'workout_days',
      where: 'profileId = ?',
      whereArgs: [profileId],
      orderBy: 'date DESC',
      limit: limit,
    );
    return maps.map((m) => WorkoutDay.fromMap(m)).toList();
  }

  Future<WorkoutDay?> getWorkoutDayById(int id) async {
    final db = await database;
    final maps = await db.query(
      'workout_days',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return WorkoutDay.fromMap(maps.first);
  }

  Future<int> updateWorkoutDay(WorkoutDay day) async {
    final db = await database;
    return await db.update(
      'workout_days',
      day.toMap(),
      where: 'id = ?',
      whereArgs: [day.id],
    );
  }

  Future<int> deleteWorkoutDay(int id) async {
    final db = await database;
    return await db.delete(
      'workout_days',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  УПРАЖНЕНИЯ В ТРЕНИРОВКЕ
  // ═══════════════════════════════════════════════════════════

  Future<int> addWorkoutExercise(WorkoutExercise exercise) async {
    final db = await database;
    return await db.insert('workout_exercises', exercise.toMap());
  }

  Future<List<WorkoutExercise>> getWorkoutExercises(int workoutDayId) async {
    final db = await database;
    final maps = await db.query(
      'workout_exercises',
      where: 'workoutDayId = ?',
      whereArgs: [workoutDayId],
      orderBy: '"order" ASC',
    );
    return maps.map((m) => WorkoutExercise.fromMap(m)).toList();
  }

  // ═══════════════════════════════════════════════════════════
  //  ПОДХОДЫ
  // ═══════════════════════════════════════════════════════════

  Future<int> addWorkoutSet(WorkoutSet set) async {
    final db = await database;
    return await db.insert('workout_sets', set.toMap());
  }

  Future<List<WorkoutSet>> getWorkoutSets(int workoutExerciseId) async {
    final db = await database;
    final maps = await db.query(
      'workout_sets',
      where: 'workoutExerciseId = ?',
      whereArgs: [workoutExerciseId],
      orderBy: '"order" ASC',
    );
    return maps.map((m) => WorkoutSet.fromMap(m)).toList();
  }

  // ═══════════════════════════════════════════════════════════
  //  ПРОВЕРКА ПУСТОЙ БАЗЫ
  // ═══════════════════════════════════════════════════════════

  Future<bool> isDatabaseEmpty() async {
    final exercisesCount = await countExercises();
    return exercisesCount == 0;
  }

  // ═══════════════════════════════════════════════════════════
  //  ПРОГРЕСС ВЕСА (для графика)
  // ═══════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getWeightProgress({
    required int profileId,
    required int exerciseId,
    int limit = 30,
  }) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT
        wd.date AS date,
        MAX(ws.weight) AS maxWeight,
        SUM(ws.reps) AS totalReps
      FROM workout_sets ws
      JOIN workout_exercises we ON we.id = ws.workoutExerciseId
      JOIN workout_days wd ON wd.id = we.workoutDayId
      WHERE wd.profileId = ?
        AND we.itemId = ?
        AND ws.completed = 1
      GROUP BY wd.date
      ORDER BY wd.date DESC
      LIMIT ?
    ''', [profileId, exerciseId, limit]);

    return result;
  }

  // ═══════════════════════════════════════════════════════════
  //  ЗАКРЫТИЕ
  // ═══════════════════════════════════════════════════════════

  Future<void> close() async {
    final db = await instance.database;
    await db.close();
  }
}