import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:workout_tracker/main.dart';

/// Подставляет пути вместо реального плагина path_provider.
/// В тестовой среде плагинов нет, поэтому отвечаем временной папкой.
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
  setUpAll(() async {
    // Рабочая SQLite для тестовой среды (вместо телефонной)
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Временная папка под тестовую базу — изолировано от реальных данных
    final tmp = await Directory.systemTemp.createTemp('workout_test_db');
    await databaseFactory.setDatabasesPath(tmp.path);

    // Мокаем path_provider: все пути ведут во временную папку
    PathProviderPlatform.instance = FakePathProvider(tmp.path);

    // В тестах нет интернета — шрифты берём из ассетов проекта
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('приложение запускается и уходит из состояния загрузки',
          (tester) async {
        // Тестовый экран по умолчанию 800x600 — не как у телефона.
        // Задаём реалистичные размеры, чтобы вёрстка не переполнялась.
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.reset);

        // Онбординг пройден, база пустая -> должен открыться экран создания профиля
        SharedPreferences.setMockInitialValues({'fairy_onboarding_done': true});

        await tester.pumpWidget(const MyApp());
        await tester.pump();

        // runAsync разрешает реальным асинхронным операциям (открытие файла базы,
        // чтение настроек) завершиться. Кадры внутри runAsync не отрисовываются,
        // поэтому проверку экрана делаем строго после него.
        await tester.runAsync(() async {
          await Future.delayed(const Duration(seconds: 5));
        });

        // Прокручиваем кадры, не дожидаясь остановки анимаций:
        // в приложении есть зацикленные анимации, pumpAndSettle на них зависает.
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(seconds: 1));

        // Даём сработать отложенным таймерам: скрытие пузыря феи (4 с)
        // и служебный таймер sqflite (10 с), который ставится при каждом
        // запросе к базе и сам не отменяется.
        await tester.pump(const Duration(seconds: 16));

        // Смотрим, какой экран на дереве сейчас
        final onLoading =
            find.byKey(const ValueKey('loading')).evaluate().isNotEmpty;
        final onOnboarding =
            find.byKey(const ValueKey('onboarding')).evaluate().isNotEmpty;
        final onProfileEdit =
            find.byKey(const ValueKey('profile_edit')).evaluate().isNotEmpty;
        final onMain =
            find.byKey(const ValueKey('main_screen')).evaluate().isNotEmpty;

        debugPrint('>>> ТЕСТ: loading=$onLoading, onboarding=$onOnboarding, '
            'profile_edit=$onProfileEdit, main_screen=$onMain');

        expect(
          find.byKey(const ValueKey('profile_edit')),
          findsOneWidget,
          reason: 'База пустая и онбординг пройден — '
              'должен открыться экран создания профиля',
        );

        // Разбираем дерево: у виджетов сработает dispose()
        // и они отменят свои таймеры.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 100));
      });

  testWidgets('без пройденного онбординга показывается онбординг',
          (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.reset);

        // Онбординг НЕ пройден -> должен открыться именно онбординг,
        // несмотря на пустую базу
        SharedPreferences.setMockInitialValues({'fairy_onboarding_done': false});

        await tester.pumpWidget(const MyApp());
        await tester.pump();

        await tester.runAsync(() async {
          await Future.delayed(const Duration(seconds: 5));
        });

        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(seconds: 1));

        // Даём сработать отложенным таймерам: скрытие пузыря феи (4 с)
        // и служебный таймер sqflite (10 с), который ставится при каждом
        // запросе к базе и сам не отменяется.
        await tester.pump(const Duration(seconds: 16));

        final onLoading =
            find.byKey(const ValueKey('loading')).evaluate().isNotEmpty;
        final onOnboarding =
            find.byKey(const ValueKey('onboarding')).evaluate().isNotEmpty;

        debugPrint('>>> ТЕСТ-2: loading=$onLoading, onboarding=$onOnboarding');

        expect(
          find.byKey(const ValueKey('onboarding')),
          findsOneWidget,
          reason: 'Онбординг не пройден — должен открыться онбординг, '
              'а не экран профиля',
        );

        // Разбираем дерево: у виджетов сработает dispose()
        // и они отменят свои таймеры.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 100));
      });
}
