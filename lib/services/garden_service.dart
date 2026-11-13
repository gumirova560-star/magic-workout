import 'database_helper.dart';
import 'energy_service.dart';

class GardenService {
  static const List<List<int>> superPattern = [
    // Буква С
    [1,1],[1,2], [2,1], [3,1],[3,2], [4,2], [5,1],[5,2],
    // Буква У
    [1,4],[1,5], [2,4],[2,5], [3,4],[3,5], [4,4],[4,5], [5,4],[5,5], [6,4],
    // Буква П
    [1,7],[1,8], [2,7],[2,8], [3,7],[3,8], [4,7],[4,8], [5,7],[5,8],
    // Буква Е
    [1,10],[1,11], [2,10], [3,10],[3,11], [4,10], [5,10],[5,11],
    // Буква Р
    [1,13],[1,14], [2,13],[2,14], [3,13],[3,14], [4,13], [5,13]
  ];

  static const String currentPattern = 'fairy_super';
  static const int totalGridCells = 15 * 7;

  static Future<List<Map<String, dynamic>>> getGarden(int profileId) async {
    final db = await DatabaseHelper.instance.database;
    return await db.query(
      'garden_flowers',
      where: 'profileId = ?',
      whereArgs: [profileId],
    );
  }

  static Future<bool> plantNextFlower({required int profileId}) async {
    final db = await DatabaseHelper.instance.database;
    final existing = await getGarden(profileId);
    final existingSlots = existing.map((e) => e['slotIndex'] as int).toSet();

    int? nextSlot;
    for (final coord in superPattern) {
      int index = coord[0] * 15 + coord[1];
      if (!existingSlots.contains(index)) {
        nextSlot = index;
        break;
      }
    }

    if (nextSlot == null) return false;

    await db.insert('garden_flowers', {
      'profileId': profileId,
      'slotIndex': nextSlot,
      'state': 'bloomed',
      'flowerType': 'normal',
      'createdAt': DateTime.now().toIso8601String(),
    });

    return true;
  }

  static Future<bool> buyFlowerAtSlot({required int profileId, required int slotIndex}) async {
    final db = await DatabaseHelper.instance.database;
    const cost = 15;

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
        'createdAt': DateTime.now().toIso8601String(),
      });
      return true;
    }
    return false;
  }

  static Future<bool> placeDecor({required int profileId, required int slotIndex, required String type}) async {
    final db = await DatabaseHelper.instance.database;
    final cost = type == 'fountain' ? 50 : 20;

    final currentBalance = await EnergyService.getBalance(profileId);
    if (currentBalance < cost) {
      return false;
    }

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
        'createdAt': DateTime.now().toIso8601String(),
      });
      return true;
    }
    return false;
  }

  static Future<void> clearGarden(int profileId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('garden_flowers', where: 'profileId = ?', whereArgs: [profileId]);
  }
}