import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:workout_tracker/services/database_helper.dart';

/// Подставляет пути вместо реального плагина path_provider.
class FakePathProvider extends PathProviderPlatform {
  final String path;
  FakePathProvider(this.path);

  @override
  Future<String?> getTemporaryPath() async => path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}

void main() {
  Directory? tmp;

  setUp(() async {
    // Свежая база для каждого теста: новая временная папка,
    // сброс закешированного соединения, подмена путей.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    tmp = await Directory.systemTemp.createTemp('workout_db_test');
    await databaseFactory.setDatabasesPath(tmp!.path);
    PathProviderPlatform.instance = FakePathProvider(tmp!.path);

    await DatabaseHelper.instance.resetForTest();
  });

  tearDown(() async {
    // Закрываем соединение до удаления папки,
    // иначе Windows не даст удалить файлы базы.
    await DatabaseHelper.instance.resetForTest();
    tmp?.deleteSync(recursive: true);
    tmp = null;
  });

  test('профиль добавляется и читается', () async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('user_profiles', {
      'name': 'Тест',
      'gender': 'female',
      'age': 30,
      'height': 170.0,
      'weight': 65.0,
      'level': 'beginner',
      'goal': 'tone',
      'equipment': 'dumbbells',
      'daysPerWeek': 3,
      'sessionMinutes': 45,
      'createdAt': DateTime.now().toIso8601String(),
    });

    final profiles = await DatabaseHelper.instance.getProfiles();
    expect(profiles.length, 1);
    expect(profiles.first.name, 'Тест');
  });

  test('повторное начисление энергии не проходит', () async {
    final first = await DatabaseHelper.instance.tryAddEnergy(
      profileId: 1, delta: 5, reason: 'workout', refId: 42,
    );
    expect(first, isTrue, reason: 'Первое начисление должно пройти');

    final second = await DatabaseHelper.instance.tryAddEnergy(
      profileId: 1, delta: 5, reason: 'workout', refId: 42,
    );
    expect(second, isFalse,
        reason: 'Повторное начисление с тем же reason/refId должно блокироваться');
  });

  test('энергия сохраняет баланс по профилю', () async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('user_profiles', {
      'name': 'Энергия',
      'gender': 'male',
      'age': 25,
      'height': 180.0,
      'weight': 75.0,
      'level': 'intermediate',
      'goal': 'strength',
      'equipment': 'gym',
      'daysPerWeek': 4,
      'sessionMinutes': 60,
      'createdAt': DateTime.now().toIso8601String(),
      'life_energy': 0,
    });

    final profiles = await DatabaseHelper.instance.getProfiles();
    final id = profiles.firstWhere((p) => p.name == 'Энергия').id!;

    await DatabaseHelper.instance.tryAddEnergy(profileId: id, delta: 10, reason: 'workout');
    await DatabaseHelper.instance.tryAddEnergy(profileId: id, delta: 3, reason: 'challenge');

    final balance = await DatabaseHelper.instance.getEnergyBalance(id);
    expect(balance, 13);
  });
}
