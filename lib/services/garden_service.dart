import 'dart:math';
import 'database_helper.dart';
import 'energy_service.dart';

class GardenService {
  static const String currentPattern = 'free_sandbox';

  // 👇 СЕТКА УВЕЛИЧЕНА ДО 20x40 (800 клеток)
  static const int gridColumns = 20;
  static const int gridRows = 40;
  static const int totalGridCells = gridColumns * gridRows;

  // ═══ ЦЕНЫ И ВОЗВРАТЫ ДЕКОРА ═══
  // Единственный источник цен: меню покупки в саду и возврат при удалении
  // берут значения отсюда. Поменяешь цену — она изменится везде сразу.
  // 'legendary' покупается нельзя (только награда за легендарные упражнения),
  // поэтому его цена и возврат = 0.
  static const Map<String, int> decorCosts = {
    'normal': 15,    // лотос
    'stone': 10,     // тропинка
    'bench': 20,     // скамейка
    'bush': 25,      // цветущий куст
    'swing': 30,     // качели
    'pavilion': 40,  // беседка
    'fountain': 50,  // фонтан
    'tree': 60,      // волшебное дерево
    'lamp': 70,      // волшебный фонарь
    'pond': 80,      // магический пруд
    'arch': 100,     // розовая арка
    'legendary': 0,  // нельзя купить — только награда за легендарные упражнения
    'wilted': 0,     // завядший — возврата нет
  };

  static int refundFor(String type) => decorCosts[type] ?? 10;

  static Future<List<Map<String, dynamic>>> getGarden(int profileId) async {
    final db = await DatabaseHelper.instance.database;
    return await db.query(
      'garden_flowers',
      where: 'profileId = ?',
      whereArgs: [profileId],
    );
  }

  static Future<bool> plantNextFlower({required int profileId, String flowerType = 'normal'}) async {
    final db = await DatabaseHelper.instance.database;
    final existing = await getGarden(profileId);
    final existingSlots = existing.map((e) => e['slotIndex'] as int).toSet();

    // Ищем свободную клетку от центра (10, 20)
    const centerCol = gridColumns ~/ 2; // 10
    const centerRow = gridRows ~/ 2;    // 20

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

  static Future<bool> buyFlowerAtSlot({required int profileId, required int slotIndex}) async {
    final db = await DatabaseHelper.instance.database;
    final cost = decorCosts['normal'] ?? 15;

    final currentBalance = await EnergyService.getBalance(profileId);
    if (currentBalance < cost) return false;

    final success = await EnergyService.addEnergy(
      profileId: profileId,
      delta: -cost,
      reason: 'garden_flower_buy',
      refId: slotIndex,
    );

    if (success) {
      await db.insert('garden_flowers', {
        'profileId': profileId,
        'slotIndex': slotIndex,
        'state': 'bloomed',
        'flowerType': 'normal',
        'rotation': 0,
        'createdAt': DateTime.now().toIso8601String(),
      });
      return true;
    }
    return false;
  }

  static Future<bool> placeDecor({required int profileId, required int slotIndex, required String type}) async {
    // 👇 Защита: золотой цветок нельзя купить — он только награда
    if (type == 'legendary' || type == 'wilted') return false;

    final db = await DatabaseHelper.instance.database;

    // 👇 Цена из единого справочника (раньше была if-цепочка)
    final cost = decorCosts[type] ?? 10;

    final currentBalance = await EnergyService.getBalance(profileId);
    if (currentBalance < cost) return false;

    final success = await EnergyService.addEnergy(
      profileId: profileId,
      delta: -cost,
      reason: 'garden_decor_$type',
      refId: slotIndex,
    );

    if (success) {
      await db.insert('garden_flowers', {
        'profileId': profileId,
        'slotIndex': slotIndex,
        'state': 'bloomed',
        'flowerType': type,
        'rotation': 0,
        'createdAt': DateTime.now().toIso8601String(),
      });
      return true;
    }
    return false;
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

  static Future<void> moveItem(int profileId, int oldSlotIndex, int newSlotIndex) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'garden_flowers',
      {'slotIndex': newSlotIndex},
      where: 'profileId = ? AND slotIndex = ?',
      whereArgs: [profileId, oldSlotIndex],
    );
  }

  static Future<void> removeItem(int profileId, int slotIndex, int refundAmount) async {
    final db = await DatabaseHelper.instance.database;
    if (refundAmount > 0) {
      await EnergyService.addEnergy(
        profileId: profileId,
        delta: refundAmount,
        reason: 'garden_item_removed',
        refId: slotIndex,
      );
    }
    await db.delete(
      'garden_flowers',
      where: 'profileId = ? AND slotIndex = ?',
      whereArgs: [profileId, slotIndex],
    );
  }

  static Future<void> clearGarden(int profileId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('garden_flowers', where: 'profileId = ?', whereArgs: [profileId]);
  }

  static Future<void> witherOneFlower(int profileId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('garden_flowers', where: 'profileId = ? AND flowerType = ?', whereArgs: [profileId, 'normal'], limit: 1);
    if (maps.isNotEmpty) {
      await db.update('garden_flowers', {'flowerType': 'wilted'}, where: 'id = ?', whereArgs: [maps.first['id']]);
    }
  }
}
// ═══ КОНЕЦ ФАЙЛА garden_service.dart ═══
