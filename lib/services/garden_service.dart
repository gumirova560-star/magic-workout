import 'database_helper.dart';
import 'energy_service.dart';

class GardenService {
  static const List<List<int>> superPattern = [
    [1,1],[1,2],[1,3],[2,1],[3,1],[4,1],[5,1],[5,2],[5,3],
    [1,5],[1,6],[2,5],[2,6],[3,5],[3,6],[4,5],[4,6],[5,5],[5,6],[6,5],
    [1,8],[1,9],[2,8],[2,9],[3,8],[3,9],[4,8],[4,9],[5,8],[5,9],[6,8],[6,9],
    [1,11],[1,12],[1,13],[2,11],[3,11],[3,12],[4,11],[5,11],[5,12],[5,13],
    [1,15],[1,16],[2,15],[2,16],[3,15],[3,16],[4,15],[5,15],[6,15]
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

  static Future<bool> placeDecor({required int profileId, required int slotIndex, required String type}) async {
    final db = await DatabaseHelper.instance.database;
    final cost = type == 'fountain' ? 50 : 20;

    // 👇 ПРОВЕРКА: хватает ли энергии? (Никаких кредитов!)
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
}