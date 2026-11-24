import 'dart:math';
import 'package:flutter/foundation.dart'; // debugPrint живёт здесь
import 'database_helper.dart';
import 'energy_service.dart';


class GardenService {
  static const String currentPattern = 'free_sandbox';

  // 👇 СЕТКА УВЕЛИЧЕНА ДО 20x40 (800 клеток)
  static const int gridColumns = 20;
  static const int gridRows = 40;
  static const int totalGridCells = gridColumns * gridRows;

  // 👇 НОВОЕ: стоимость оживления завядшего цветка
  static const int reviveCost = 30;

  // ═══ ЦЕНЫ И ВОЗВРАТЫ ДЕКОРА ═══
  // Единственный источник цен: меню покупки в саду и возврат при удалении
  // берут значения отсюда. Поменяешь цену — она изменится везде сразу.
  // 'legendary' покупается нельзя (только награда за легендарные упражнения),
  // поэтому его цена и возврат = 0.
  static const Map<String, int> decorCosts = {
    'normal': 15, // лотос
    'stone': 10, // тропинка
    'bench': 20, // скамейка
    'bush': 25, // цветущий куст
    'swing': 30, // качели
    'pavilion': 40, // беседка
    'fountain': 50, // фонтан
    'tree': 60, // волшебное дерево
    'lamp': 70, // волшебный фонарь
    'pond': 80, // магический пруд
    'arch': 100, // розовая арка
    'legendary': 0, // нельзя купить — только награда за легендарные упражнения
    'wilted': 0, // завядший — возврата нет, только оживление за 30 ⚡
  };

  static int refundFor(String type) => decorCosts[type] ?? 10;

  // ═══ СЛОИ: ПОЛ И ОБЪЕКТЫ ═══
  // Типы-покрытия пола (тропинки, плитка): могут лежать ПОД объектами.
  // Объект можно ставить на клетку, где уже есть пол — это легально.
  // На одной клетке максимум: один пол + один объект.
  static const Set<String> floorTypes = {'stone'};

  /// Можно ли поставить предмет [type] в клетку [slotIndex].
  /// Пол: запрещён только если на клетке уже другой пол.
  /// Объект: запрещён, если на клетке уже другой объект (пол — можно).
  static Future<bool> isSlotFreeFor({
    required int profileId,
    required int slotIndex,
    required String type,
  }) async {
    final existing = await getGarden(profileId);
    final bool placingFloor = floorTypes.contains(type);
    for (final item in existing) {
      if (item['slotIndex'] != slotIndex) continue;
      final t = item['flowerType'] as String?;
      if (placingFloor) {
        if (t != null && floorTypes.contains(t)) return false; // пол на пол — нельзя
      } else {
        // объект на объект — нельзя, а тропинка под ним — можно
        if (t == null || !floorTypes.contains(t)) return false;
      }
    }
    return true;
  }

  static Future<List<Map<String, dynamic>>> getGarden(int profileId) async {
    final db = await DatabaseHelper.instance.database;
    return await db.query(
      'garden_flowers',
      where: 'profileId = ?',
      whereArgs: [profileId],
    );
  }

  static Future<bool> plantNextFlower({
    required int profileId,
    String flowerType = 'normal',
  }) async {
    final db = await DatabaseHelper.instance.database;
    final existing = await getGarden(profileId);
    final existingSlots = existing.map((e) => e['slotIndex'] as int).toSet();

    // Ищем свободную клетку от центра (10, 20)
    const centerCol = gridColumns ~/ 2; // 10
    const centerRow = gridRows ~/ 2; // 20

    int? nextSlot;
    for (int r = 0; r < max(gridRows, gridColumns); r++) {
      for (int dy = -r; dy <= r; dy++) {
        for (int dx = -r; dx <= r; dx++) {
          if (dx.abs() != r && dy.abs() != r) continue;
          int col = centerCol + dx;
          int row = centerRow + dy;
          if (col < 0 || col >= gridColumns || row < 0 || row >= gridRows) continue;
          int index = row * gridColumns + col;
          if (!existingSlots.contains(index)) {
            nextSlot = index;
            break;
          }
        }
        if (nextSlot != null) break;
      }
      if (nextSlot != null) break;
    }

    // Если по спирали не нашли, ищем любую свободную
    if (nextSlot == null) {
      for (int i = 0; i < totalGridCells; i++) {
        if (!existingSlots.contains(i)) {
          nextSlot = i;
          break;
        }
      }
    }

    if (nextSlot == null) return false; // Сад переполнен

    await db.insert('garden_flowers', {
      'profileId': profileId,
      'slotIndex': nextSlot,
      'state': 'bloomed',
      'flowerType': flowerType,
      'rotation': 0,
      'createdAt': DateTime.now().toIso8601String(),
    });

    return true;
  }

  /// Посадка лотоса в конкретную клетку за 15 ⚡️.
  /// Возвращает null при успехе или текст причины отказа.
  static Future<String?> buyFlowerAtSlot({
    required int profileId,
    required int slotIndex,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final cost = decorCosts['normal'] ?? 15;

    if (!await isSlotFreeFor(profileId: profileId, slotIndex: slotIndex, type: 'normal')) {
      return 'Клетка занята другим предметом';
    }

    final currentBalance = await EnergyService.getBalance(profileId);
    if (currentBalance < cost) return 'Недостаточно энергии! 😢';

    final success = await EnergyService.addEnergy(
      profileId: profileId,
      delta: -cost,
      reason: 'garden_flower_buy',
      // 👇 Траты повторяемы: не передаём refId, иначе UNIQUE
      // (profileId, reason, refId) в energy_transactions заблокирует
      // вторую покупку лотоса на тот же слот навсегда (после
      // «поставил → убрал → поставил снова»)
      refId: null,
    );

    if (!success) {
      debugPrint('🪴 buyFlowerAtSlot: addEnergy вернул false, slot=$slotIndex, '
          'balance=$currentBalance, cost=$cost');
      return 'Не удалось списать энергию';
    }

    await db.insert('garden_flowers', {
      'profileId': profileId,
      'slotIndex': slotIndex,
      'state': 'bloomed',
      'flowerType': 'normal',
      'rotation': 0,
      'createdAt': DateTime.now().toIso8601String(),
    });
    return null; // успех
  }

  /// Покупка декора за энергию.
  /// Возвращает null при успехе или текст причины отказа.
  static Future<String?> placeDecor({
    required int profileId,
    required int slotIndex,
    required String type,
  }) async {
    // 👇 Защита: золотой цветок и завядший нельзя купить — только награда/оживление
    if (type == 'legendary' || type == 'wilted') {
      return 'Этот предмет нельзя купить';
    }

    // 👇 Проверка клетки с учётом слоёв: пол можно под объект,
    // объект — на клетку с полом, но не на другой объект
    if (!await isSlotFreeFor(profileId: profileId, slotIndex: slotIndex, type: type)) {
      return 'Клетка занята другим предметом';
    }

    final db = await DatabaseHelper.instance.database;

    // 👇 Цена из единого справочника (раньше была if-цепочка)
    final cost = decorCosts[type] ?? 10;

    final currentBalance = await EnergyService.getBalance(profileId);
    if (currentBalance < cost) return 'Недостаточно энергии! 😢';

    final success = await EnergyService.addEnergy(
      profileId: profileId,
      delta: -cost,
      reason: 'garden_decor_$type',
      // 👇 Траты повторяемы: не передаём refId, иначе UNIQUE
      // (profileId, reason, refId) в energy_transactions заблокирует
      // вторую покупку того же декора на тот же слот навсегда
      // (после «поставил → убрал → поставил снова»)
      refId: null,
    );

    if (!success) {
      debugPrint('🪴 placeDecor: addEnergy вернул false, slot=$slotIndex, '
          'type=$type, balance=$currentBalance, cost=$cost');
      return 'Не удалось списать энергию';
    }

    await db.insert('garden_flowers', {
      'profileId': profileId,
      'slotIndex': slotIndex,
      'state': 'bloomed',
      'flowerType': type,
      'rotation': 0,
      'createdAt': DateTime.now().toIso8601String(),
    });
    return null; // успех
  }

  static Future<void> setRotation(int profileId, int slotIndex, int rotation) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'garden_flowers',
      {'rotation': rotation},
      where: 'profileId = ? AND slotIndex = ?',
      whereArgs: [profileId, slotIndex],
    );
  }

  static Future<bool> moveItem(int profileId, int oldSlotIndex, int newSlotIndex) async {
    final db = await DatabaseHelper.instance.database;

    final rows = await db.query(
      'garden_flowers',
      where: 'profileId = ? AND slotIndex = ?',
      whereArgs: [profileId, oldSlotIndex],
    );
    if (rows.isEmpty) return false;
    final type = rows.first['flowerType'] as String? ?? 'normal';

    // 👈 НОВОЕ: завядший цветок не перемещается — только оживляется на месте
    if (type == 'wilted') return false;

    // Целевая клетка должна быть свободна с учётом типа двигаемого предмета,
    // при этом сам предмет на старой клетке проверке не мешает
    final occupied = <int>{};
    for (final item in await getGarden(profileId)) {
      if (item['slotIndex'] == oldSlotIndex) continue; // сам себя не считаем
      final t = item['flowerType'] as String?;
      if (floorTypes.contains(type)) {
        // двигаем пол: мешает только другой пол
        if (t != null && floorTypes.contains(t)) {
          occupied.add(item['slotIndex'] as int);
        }
      } else {
        // двигаем объект: мешает только другой объект, тропинка — нет
        if (t != null && !floorTypes.contains(t)) {
          occupied.add(item['slotIndex'] as int);
        }
      }
    }
    if (occupied.contains(newSlotIndex)) return false;

    // 👇 ФИКС БАГА 7: переносим только свой слой. Если на клетке лежат
    // и объект, и тропинка — тащим тот предмет, что виден сверху
    // (объект). Тропинка остаётся на прежнем месте.
    final bool movingFloor = floorTypes.contains(type);
    String? carryingType;
    if (rows.length > 1) {
      // На клетке две записи: объект + пол. Смотрим тип верхнего
      // (не-пол) предмета — его и тащим, если тащим не пол.
      final other = rows.firstWhere(
            (r) => !floorTypes.contains(r['flowerType'] as String?),
        orElse: () => rows.first,
      );
      carryingType = other['flowerType'] as String?;
      if (movingFloor) carryingType = type;
    }

    if (carryingType != null) {
      await db.update(
        'garden_flowers',
        {'slotIndex': newSlotIndex},
        where: 'profileId = ? AND slotIndex = ? AND flowerType = ?',
        whereArgs: [profileId, oldSlotIndex, carryingType],
      );
    } else {
      // Обычный случай: на клетке одна запись
      await db.update(
        'garden_flowers',
        {'slotIndex': newSlotIndex},
        where: 'profileId = ? AND slotIndex = ? AND flowerType = ?',
        whereArgs: [profileId, oldSlotIndex, type],
      );
    }
    return true;
  }

  static Future<void> removeItem(int profileId, int slotIndex, int refundAmount,
      {String? type}) async {
    final db = await DatabaseHelper.instance.database;

    // 👇 ФИКС БАГА 7: удаляем только указанный слой (type), а не всё на клетке.
    // Убираешь предмет — тропинка под ним остаётся; убираешь тропинку —
    // предмет остаётся. Проверка «завядший» тоже работает по своей строке.
    final rows = await db.query('garden_flowers',
        where: type != null
            ? 'profileId = ? AND slotIndex = ? AND flowerType = ?'
            : 'profileId = ? AND slotIndex = ?',
        whereArgs: type != null
            ? [profileId, slotIndex, type]
            : [profileId, slotIndex],
        limit: 1);
    if (rows.isEmpty) return; // нечего удалять (уже удалено или слой не тот)
    if ((rows.first['flowerType'] as String?) == 'wilted') return;

    if (refundAmount > 0) {
      await EnergyService.addEnergy(
        profileId: profileId,
        delta: refundAmount,
        reason: 'garden_item_removed',
        // 👇 Возвраты повторяемы: с refId UNIQUE заблокировал бы
        // второй возврат с той же клетки после повторной покупки
        refId: null,
      );
    }
    await db.delete(
      'garden_flowers',
      where: type != null
          ? 'profileId = ? AND slotIndex = ? AND flowerType = ?'
          : 'profileId = ? AND slotIndex = ?',
      whereArgs: type != null
          ? [profileId, slotIndex, type]
          : [profileId, slotIndex],
    );
  }

  // 👇 НОВОЕ: оживление завядшего цветка за 30 ⚡.
  // Возвращает null при успехе или текст причины отказа.
  static Future<String?> reviveWiltedFlower({
    required int profileId,
    required int slotIndex,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'garden_flowers',
      where: 'profileId = ? AND slotIndex = ?',
      whereArgs: [profileId, slotIndex],
      limit: 1,
    );
    if (rows.isEmpty) return 'Цветок не найден';
    if ((rows.first['flowerType'] as String?) != 'wilted') {
      return 'Этот цветок не завял';
    }

    final balance = await EnergyService.getBalance(profileId);
    if (balance < reviveCost) return 'Недостаточно энергии! 😢';

    final ok = await EnergyService.addEnergy(
      profileId: profileId,
      delta: -reviveCost,
      reason: 'garden_flower_revive',
      // 👇 Трата повторяемая: цветок может завять снова и снова,
      // refId с UNIQUE заблокировал бы второе оживление навсегда
      refId: null,
    );
    if (!ok) return 'Не удалось списать энергию';

    await db.update(
      'garden_flowers',
      {'flowerType': 'normal', 'state': 'bloomed'},
      where: 'id = ?',
      whereArgs: [rows.first['id']],
    );
    return null;
  }

  static Future<void> clearGarden(int profileId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('garden_flowers', where: 'profileId = ?', whereArgs: [profileId]);
  }

  static Future<void> witherOneFlower(int profileId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('garden_flowers',
        where: 'profileId = ? AND flowerType = ?',
        whereArgs: [profileId, 'normal'],
        limit: 1);
    if (maps.isNotEmpty) {
      await db.update('garden_flowers', {'flowerType': 'wilted'},
          where: 'id = ?', whereArgs: [maps.first['id']]);
    }
  }
}
// ═══ КОНЕЦ ФАЙЛА garden_service.dart ═══
