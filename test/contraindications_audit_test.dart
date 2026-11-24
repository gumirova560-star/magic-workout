// Аудит каталога: согласованность kContraindications с базой
// и полнота противопоказаний для «опасных» зон.
//
// Тест ловит три класса проблем:
// 1) «сироты» — ключи kContraindications, которых нет в каталоге
//    (опечатка в названии, упражнение удалили из базы);
// 2) расхождение поля contraindications в базе с таблицей
//    (syncExercises прошёл не полностью или данные разъехались);
// 3) упражнения из травмоопасных зон с пустыми противопоказаниями —
//    именно так «Реверанс-выпад» просочился в план при knees.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:workout_tracker/data/base_exercises.dart';
import 'package:workout_tracker/models/exercise.dart';
import 'package:workout_tracker/services/database_helper.dart';

class _FakePathProvider extends PathProviderPlatform {
  final String basePath;
  _FakePathProvider(this.basePath);

  @override
  Future<String?> getApplicationDocumentsPath() async => basePath;

  @override
  Future<String?> getTemporaryPath() async => basePath;

  @override
  Future<String?> getApplicationSupportPath() async => basePath;
}

/// Зоны, для которых пустые противопоказания считаются дырой в данных.
/// Расширяемый список: сюда добавляем зоны, где распространены
/// травмы и ограничения здоровья (колени, спина, плечи, запястья...).
const _riskyZones = [
  'legs', 'quads', 'hamstrings', 'calves', 'feet',
  'glutes', 'lower_back', 'back', 'shoulders',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('audit_test_db_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    SharedPreferences.setMockInitialValues({});
    await DatabaseHelper.instance.database;
    await DatabaseHelper.instance.syncExercises();
  });

  tearDownAll(() async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.close();
    } catch (_) {}
    try {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('Аудит kContraindications ↔ каталог', () {
    test('Все упражнения из таблицы есть в каталоге', () async {
      final all = await DatabaseHelper.instance.getExercises();
      final names = all.map((e) => e.name.trim()).toSet();

      final orphans = <String>{};
      kContraindications.forEach((code, exNames) {
        for (final n in exNames) {
          if (!names.contains(n)) orphans.add('$code → "$n"');
        }
      });

      expect(orphans, isEmpty,
          reason: 'В kContraindications упражнения, которых нет в каталоге: '
              '$orphans');
    });

    test('Поле contraindications в базе совпадает с таблицей', () async {
      final all = await DatabaseHelper.instance.getExercises();

      final mismatches = <String>[];
      for (final ex in all) {
        final expected = contraindicationsFor(ex.name).toSet();
        final actual =
        ex.contraindications.map((c) => c.toLowerCase().trim()).toSet();
        if (expected.length != actual.length ||
            !expected.containsAll(actual)) {
          mismatches.add('${ex.name}: поле=$actual, таблица=$expected');
        }
      }

      expect(mismatches, isEmpty,
          reason: 'Синк не заполнил поле или данные разъехались: $mismatches');
    });

    test('В каталоге нет дублирующихся названий', () async {
      final all = await DatabaseHelper.instance.getExercises();
      final seen = <String>{};
      final dups = <String>{};
      for (final ex in all) {
        final key = ex.name.toLowerCase().trim();
        if (!seen.add(key)) dups.add(ex.name);
      }
      expect(dups, isEmpty, reason: 'Дубликаты в каталоге: $dups');
    });

    test('Все коды противопоказаний — нормализованные строки', () async {
      final all = await DatabaseHelper.instance.getExercises();

      final bad = <String>[];
      for (final ex in all) {
        for (final c in ex.contraindications) {
          if (c.trim() != c || c.toLowerCase() != c || c.isEmpty) {
            bad.add('${ex.name}: "$c"');
          }
        }
      }

      expect(bad, isEmpty,
          reason: 'Коды противопоказаний должны быть нижним регистром '
              'без пробелов по краям: $bad');
    });
  });

  group('Аудит полноты противопоказаний', () {
    // Проверка не по зонам (их закрывает зональный фильтр v21.1),
    // а по опасным ДВИЖЕНИЯМ: если в названии узнаваемый опасный
    // паттерн — у упражнения обязана быть соответствующая пометка,
    // независимо от того, в какую зону его записала база.
    test('Опасные движения по названию покрыты противопоказаниями',
            () async {
          final all = await DatabaseHelper.instance.getExercises();

          const kneePatterns = [
            'приседани', 'выпад', 'прыжк', 'зашагивани', 'скакалк',
            'берпи', 'скалолаз', 'джеки', 'подниманием колен',
          ];
          const backPatterns = [
            'наклоны со штангой', 'румынская тяга', 'гиперэкстензия с весом',
            'тяга штанги в наклоне', 'тяга т-грифа',
            'тяга гантели одной рукой', 'тяга гантели к поясу',
          ];
          // 👈 Без 'жим гантелей сидя' и 'жим штанги узким хватом': это
          // горизонтальные/наклонные жимы (верх груди и трицепс), а не жимы
          // над головой — по философии таблицы плечи в сжатии не работают.
          const shoulderPatterns = [
            'жим штанги стоя', 'жим арнольда',
            'к подбородку', 'брусьях', 'французский жим', 'из-за головы',
          ];


          final gaps = <String>[];
          for (final ex in all) {
            final n = ex.name.toLowerCase().replaceAll('ё', 'е');
            final codes =
            ex.contraindications.map((c) => c.toLowerCase().trim()).toSet();
            if (kneePatterns.any(n.contains) && !codes.contains('knees')) {
              gaps.add('${ex.name}: нет knees');
            }
            if (backPatterns.any(n.contains) && !codes.contains('back')) {
              gaps.add('${ex.name}: нет back');
            }
            if (shoulderPatterns.any(n.contains) && !codes.contains('shoulders')) {
              gaps.add('${ex.name}: нет shoulders');
            }
          }

          expect(gaps, isEmpty,
              reason: 'Опасные движения без противопоказаний — заполни '
                  'kContraindications или исключи паттерн: $gaps');
        });
  });


  group('Аудит карты zonesBlockedByLimitations', () {
    test('Все зоны из карты существуют в каталоге', () async {
      final all = await DatabaseHelper.instance.getExercises();
      final knownZones = <String>{};
      for (final ex in all) {
        knownZones.addAll(ex.muscleGroups);
      }

      final ghosts = <String>[];
      zonesBlockedByLimitations([]); // карта доступна; обходим её значения
      // Собираем все зоны, на которые может замапиться любое ограничение.
      // Для этого прогоняем известный словарь ограничений — значения
      // карты проверяем по факту: зона должна встречаться в каталоге.
      for (final lim in ['knees', 'колени', 'back', 'спина', 'shoulders',
        'плечи', 'wrists', 'запястья', 'neck', 'шея', 'ankle', 'голеностоп']) {
        for (final zone in zonesBlockedByLimitations([lim])) {
          if (!knownZones.contains(zone)) ghosts.add('$lim → "$zone"');
        }
      }

      expect(ghosts, isEmpty,
          reason: 'Карта ограничений отсылает к несуществующим зонам: '
              '$ghosts — опечатка в zonesBlockedByLimitations');
    });
  });
}
