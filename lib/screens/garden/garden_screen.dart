import 'package:flutter/material.dart';
import '../../services/garden_service.dart';
import '../../services/energy_service.dart';

class GardenScreen extends StatefulWidget {
  final int profileId;
  const GardenScreen({super.key, required this.profileId});

  @override
  State<GardenScreen> createState() => _GardenScreenState();
}

class _GardenScreenState extends State<GardenScreen> {
  List<Map<String, dynamic>> _gardenItems = [];
  int _energyBalance = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadGarden();
  }

  Future<void> _loadGarden() async {
    setState(() => _loading = true);
    final items = await GardenService.getGarden(widget.profileId);
    final balance = await EnergyService.getBalance(widget.profileId);
    if (mounted) {
      setState(() {
        _gardenItems = items;
        _energyBalance = balance;
        _loading = false;
      });
    }
  }

  Future<void> _onCellTap(int index) async {
    final item = _gardenItems.firstWhere(
          (e) => e['slotIndex'] == index,
      orElse: () => {},
    );

    if (item.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Здесь уже что-то есть 🌸')),
      );
      return;
    }

    // Проверяем, является ли эта ячейка частью слова
    bool isWordSlot = GardenService.superPattern.any((coord) => (coord[0] * 15 + coord[1]) == index);

    if (isWordSlot) {
      final success = await GardenService.plantNextFlower(profileId: widget.profileId);
      if (success) _loadGarden();
    } else {
      _showDecorDialog(index);
    }
  }

  void _showDecorDialog(int index) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Украсить сад (Баланс: $_energyBalance ⚡️)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Text('🪑', style: TextStyle(fontSize: 32)),
              title: const Text('Скамейка'),
              subtitle: const Text('20 ⚡️'),
              onTap: () async {
                Navigator.pop(ctx);
                final success = await GardenService.placeDecor(profileId: widget.profileId, slotIndex: index, type: 'bench');
                if (success) {
                  _loadGarden();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Недостаточно энергии! Сначала сделай тренировку 💪'), backgroundColor: Colors.red),
                  );
                }
              },
            ),
            ListTile(
              leading: const Text('🏛️', style: TextStyle(fontSize: 32)),
              title: const Text('Фонтан'),
              subtitle: const Text('50 ⚡️'),
              onTap: () async {
                Navigator.pop(ctx);
                final success = await GardenService.placeDecor(profileId: widget.profileId, slotIndex: index, type: 'fountain');
                if (success) {
                  _loadGarden();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Недостаточно энергии! Сначала сделай тренировку 💪'), backgroundColor: Colors.red),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сад Феи'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text('⚡️ $_energyBalance', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber)),
            ),
          )
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          // 👇 НОВЫЙ СОЧНЫЙ ГРАДИЕНТ (Весенняя поляна)
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFA8E6CF), Color(0xFF3EECAC)],
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text(
                'Тапай по траве, чтобы выращивать слово «СУПЕР».\nПустые места можно украсить декором!',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 2.5,
                child: Center(
                  child: SizedBox(
                    width: 15 * 36.0,
                    height: 7 * 36.0,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 15,
                        crossAxisSpacing: 2,
                        mainAxisSpacing: 2,
                      ),
                      itemCount: GardenService.totalGridCells,
                      itemBuilder: (context, index) {
                        final item = _gardenItems.firstWhere(
                              (e) => e['slotIndex'] == index,
                          orElse: () => {},
                        );

                        String emoji = '';
                        if (item.isNotEmpty) {
                          if (item['flowerType'] == 'fountain') emoji = '🏛️';
                          else if (item['flowerType'] == 'bench') emoji = '🪑';
                          else emoji = '🌸';
                        }

                        return GestureDetector(
                          onTap: () => _onCellTap(index),
                          child: Container(
                            decoration: BoxDecoration(
                              // 👇 ВМЕСТО ЗАЛИВКИ ТЕПЕРЬ КРАСИВАЯ ТРАВА
                              color: item.isEmpty ? Colors.green.shade400.withOpacity(0.5) : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: item.isEmpty
                                  ? Border.all(color: Colors.green.shade600.withOpacity(0.3), width: 1)
                                  : null,
                            ),
                            child: Center(
                              child: item.isEmpty
                              // Если пусто — рисуем кустик травы 🌿
                                  ? const Text('🌿', style: TextStyle(fontSize: 22))
                              // Если занято — цветок/декор
                                  : Text(emoji, style: const TextStyle(fontSize: 24)),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}