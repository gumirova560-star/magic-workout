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
import '../models/transformation_photo.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  static const int _dbVersion = 6; // ⚠️ УВЕЛИЧЕНО ДО 6
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
        createdAt TEXT NOT NULL,
        avatarPath TEXT,
        beforePhotoPath TEXT,
        beforeSidePath TEXT,
        beforeBackPath TEXT
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
        createdAt TEXT NOT NULL,
        isCustom INTEGER DEFAULT 0
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
        blockNumber INTEGER,
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

    await db.execute('''
      CREATE TABLE transformations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profileId INTEGER NOT NULL,
        imagePath TEXT NOT NULL,
        monthNumber INTEGER NOT NULL,
        angle TEXT DEFAULT 'front',
        createdAt TEXT NOT NULL,
        FOREIGN KEY (profileId) REFERENCES user_profiles (id) ON DELETE CASCADE
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
      await db.execute('ALTER TABLE template_items ADD COLUMN replacedByItemId INTEGER');
      await db.execute('ALTER TABLE template_items ADD COLUMN replacementReason TEXT');
      await db.execute('ALTER TABLE template_items ADD COLUMN replacementPermanent INTEGER DEFAULT 0');
    }

    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE workout_templates ADD COLUMN isCustom INTEGER DEFAULT 0');
      } catch (_) {}
    }

    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE workout_exercises ADD COLUMN blockNumber INTEGER');
      } catch (_) {}
    }

    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE user_profiles ADD COLUMN avatarPath TEXT');
        await db.execute('ALTER TABLE user_profiles ADD COLUMN beforePhotoPath TEXT');
        await db.execute('''
          CREATE TABLE transformations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            profileId INTEGER NOT NULL,
            imagePath TEXT NOT NULL,
            monthNumber INTEGER NOT NULL,
            angle TEXT DEFAULT 'front',
            createdAt TEXT NOT NULL,
            FOREIGN KEY (profileId) REFERENCES user_profiles (id) ON DELETE CASCADE
          )
        ''');
      } catch (_) {}
    }

    // ⚠️ ОБНОВЛЕНИЕ ДО 6-й ВЕРСИИ (Добавляем Бок и Спину для фото "До")
    if (oldVersion < 6) {
      try {
        await db.execute('ALTER TABLE user_profiles ADD COLUMN beforeSidePath TEXT');
        await db.execute('ALTER TABLE user_profiles ADD COLUMN beforeBackPath TEXT');
      } catch (_) {}
    }
  }
  // ═══ ЧАСТЬ 1 ЗАКОНЧЕНА ═══
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
        orderBy: 'createdAt ASC',
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

    Future<List<WorkoutDay>> getWorkoutDaysForMonth({
      required int profileId,
      required int year,
      required int month,
    }) async {
      final db = await database;
      final start = DateTime(year, month, 1);
      final end = DateTime(year, month + 1, 1);
      final maps = await db.query(
        'workout_days',
        where: 'profileId = ? AND date >= ? AND date < ?',
        whereArgs: [
          profileId,
          start.toIso8601String(),
          end.toIso8601String(),
        ],
        orderBy: 'date ASC',
      );
      return maps.map((m) => WorkoutDay.fromMap(m)).toList();
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

    Future<int> updateWorkoutExerciseBlock({
      required int id,
      int? blockNumber,
    }) async {
      final db = await database;
      return await db.update(
        'workout_exercises',
        {'blockNumber': blockNumber},
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    Future<int> clearBlocksForWorkoutDay(int workoutDayId) async {
      final db = await database;
      return await db.update(
        'workout_exercises',
        {'blockNumber': null},
        where: 'workoutDayId = ?',
        whereArgs: [workoutDayId],
      );
    }

    Future<int> updateWorkoutSet(WorkoutSet set) async {
      final db = await database;
      return await db.update(
        'workout_sets',
        set.toMap(),
        where: 'id = ?',
        whereArgs: [set.id],
      );
    }

    Future<int> deleteWorkoutSet(int id) async {
      final db = await database;
      return await db.delete(
        'workout_sets',
        where: 'id = ?',
        whereArgs: [id],
      );
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
    //  АНАЛИЗ НЕДЕЛИ
    // ═══════════════════════════════════════════════════════════

    Future<List<WorkoutDay>> getWorkoutDaysBetween({
      required int profileId,
      required DateTime from,
      required DateTime to,
    }) async {
      final db = await database;
      final maps = await db.query(
        'workout_days',
        where: 'profileId = ? AND date >= ? AND date < ?',
        whereArgs: [
          profileId,
          from.toIso8601String(),
          to.toIso8601String(),
        ],
        orderBy: 'date DESC',
      );
      return maps.map((m) => WorkoutDay.fromMap(m)).toList();
    }

    Future<Set<String>> getCompletedNamesInWindow({
      required int profileId,
      required DateTime from,
      required DateTime to,
    }) async {
      final db = await database;
      final maps = await db.query(
        'workout_days',
        columns: ['name'],
        where: 'profileId = ? AND status = ? AND date >= ? AND date < ?',
        whereArgs: [
          profileId,
          'completed',
          from.toIso8601String(),
          to.toIso8601String(),
        ],
      );
      return maps.map((m) => m['name'] as String).toSet();
    }

    // ═══════════════════════════════════════════════════════════
    //  ПОЛЬЗОВАТЕЛЬСКИЕ ШАБЛОНЫ (isCustom = 1)
    // ═══════════════════════════════════════════════════════════

    Future<List<WorkoutTemplate>> getCustomTemplates(int profileId) async {
      final db = await database;
      final maps = await db.query(
        'workout_templates',
        where: 'profileId = ? AND isCustom = 1',
        whereArgs: [profileId],
        orderBy: 'createdAt DESC',
      );
      return maps.map((m) => WorkoutTemplate.fromMap(m)).toList();
    }

    Future<List<WorkoutTemplate>> getAutoTemplates(int profileId) async {
      final db = await database;
      final maps = await db.query(
        'workout_templates',
        where: 'profileId = ? AND isCustom = 0',
        whereArgs: [profileId],
        orderBy: 'createdAt ASC',
      );
      return maps.map((m) => WorkoutTemplate.fromMap(m)).toList();
    }

    // ═══════════════════════════════════════════════════════════
    //  СОЗДАНИЕ ШАБЛОНА ИЗ ЗАВЕРШЁННОЙ ТРЕНИРОВКИ
    // ═══════════════════════════════════════════════════════════

    Future<int> createTemplateFromWorkoutDay({
      required int profileId,
      required int workoutDayId,
      required String templateName,
      required String type,
      required int estimatedMinutes,
    }) async {
      final db = await database;

      final templateId = await db.insert('workout_templates', {
        'profileId': profileId,
        'name': templateName,
        'type': type,
        'estimatedMinutes': estimatedMinutes,
        'notes': null,
        'createdAt': DateTime.now().toIso8601String(),
        'isCustom': 1,
      });

      final workoutExs = await getWorkoutExercises(workoutDayId);

      for (final we in workoutExs) {
        final sets = await getWorkoutSets(we.id!);

        String repsStr = we.reps;
        if (sets.isNotEmpty) {
          final r = sets.first.reps;
          if (r != null) repsStr = '$r';
        }

        await db.insert('template_items', {
          'templateId': templateId,
          'itemType': we.itemType,
          'itemId': we.itemId,
          'order': we.order,
          'sets': we.sets,
          'reps': repsStr,
          'restSeconds': we.restSeconds,
          'durationSeconds': we.durationSeconds,
          'isCoolDown': we.isCoolDown ? 1 : 0,
          'replacedByItemId': we.replacedByItemId,
          'replacementReason': we.replacementReason,
          'replacementPermanent': we.replacementPermanent ? 1 : 0,
        });
      }

      return templateId;
    }

    Future<int> deletePlannedWorkoutDays(int profileId) async {
      final db = await database;
      return await db.delete(
        'workout_days',
        where: 'profileId = ? AND status = ?',
        whereArgs: [profileId, 'planned'],
      );
    }

    // ═══════════════════════════════════════════════════════════
    //  ИСТОРИЯ ПО УПРАЖНЕНИЮ (для прогрессии)
    // ═══════════════════════════════════════════════════════════

    Future<WorkoutSet?> getLastCompletedSetForExercise({
      required int profileId,
      required int exerciseId,
      int daysLimit = 60,
    }) async {
      final db = await database;

      final from = DateTime.now()
          .subtract(Duration(days: daysLimit))
          .toIso8601String();

      final result = await db.rawQuery('''
        SELECT ws.*
        FROM workout_sets ws
        JOIN workout_exercises we ON we.id = ws.workoutExerciseId
        JOIN workout_days wd ON wd.id = we.workoutDayId
        WHERE wd.profileId = ?
          AND wd.status = 'completed'
          AND wd.date >= ?
          AND (we.replacedByItemId = ? OR we.itemId = ?)
          AND we.itemType = 'exercise'
          AND we.isCoolDown = 0
          AND ws.completed = 1
          AND ws.weight IS NOT NULL
        ORDER BY wd.date DESC, ws."order" ASC
        LIMIT 1
      ''', [profileId, from, exerciseId, exerciseId]);

      if (result.isEmpty) return null;
      return WorkoutSet.fromMap(result.first);
    }

    Future<Set<int>> getRecentExerciseIds({
      required int profileId,
      int daysLimit = 14,
    }) async {
      final db = await database;

      final from = DateTime.now()
          .subtract(Duration(days: daysLimit))
          .toIso8601String();

      final maps = await db.rawQuery('''
        SELECT DISTINCT
          COALESCE(we.replacedByItemId, we.itemId) AS exId
        FROM workout_exercises we
        JOIN workout_days wd ON wd.id = we.workoutDayId
        WHERE wd.profileId = ?
          AND wd.date >= ?
          AND we.itemType = 'exercise'
          AND we.isCoolDown = 0
      ''', [profileId, from]);

      return maps
          .map((m) => m['exId'] as int?)
          .whereType<int>()
          .toSet();
    }

    Future<List<WorkoutSet>> getLastWorkoutExerciseSets({
      required int profileId,
      required int exerciseId,
      int daysLimit = 60,
    }) async {
      final db = await database;

      final from = DateTime.now()
          .subtract(Duration(days: daysLimit))
          .toIso8601String();

      final weResult = await db.rawQuery('''
        SELECT we.id
        FROM workout_exercises we
        JOIN workout_days wd ON wd.id = we.workoutDayId
        WHERE wd.profileId = ?
          AND wd.status = 'completed'
          AND wd.date >= ?
          AND (we.replacedByItemId = ? OR we.itemId = ?)
          AND we.itemType = 'exercise'
          AND we.isCoolDown = 0
        ORDER BY wd.date DESC, wd.id DESC
        LIMIT 1
      ''', [profileId, from, exerciseId, exerciseId]);

      if (weResult.isEmpty) return [];

      final weId = weResult.first['id'] as int?;
      if (weId == null) return [];

      final sets = await getWorkoutSets(weId);
      return sets;
    }

    // ═══════════════════════════════════════════════════════════
    //  ФОТО ТРАНСФОРМАЦИИ
    // ═══════════════════════════════════════════════════════════

    Future<int> addTransformationPhoto(TransformationPhoto photo) async {
      final db = await database;
      return await db.insert('transformations', photo.toMap());
    }

    Future<List<TransformationPhoto>> getTransformationPhotos(int profileId) async {
      final db = await database;
      final maps = await db.query(
        'transformations',
        where: 'profileId = ?',
        whereArgs: [profileId],
        orderBy: 'monthNumber ASC',
      );
      return maps.map((m) => TransformationPhoto.fromMap(m)).toList();
    }

    Future<int> deleteTransformationPhoto(int id) async {
      final db = await database;
      return await db.delete(
        'transformations',
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    // ═══════════════════════════════════════════════════════════
    //  ЗАКРЫТИЕ
    // ═══════════════════════════════════════════════════════════

    Future<void> close() async {
      final db = await instance.database;
      await db.close();
    }
  }
  // ═══ ФАЙЛ database_helper.dart ЗАВЕРШЁН ═══