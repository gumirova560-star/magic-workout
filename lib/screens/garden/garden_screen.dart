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

    bool isWordSlot = GardenService.superPattern.any((coord) => (coord[0] * 15 + coord[1]) == index);

    if (isWordSlot) {
      _showFlowerDialog(index);
    } else {
      _showDecorDialog(index);
    }
  }

  void _showFlowerDialog(int index) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Место для цветка 🌸', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Выполни челлендж дня, чтобы он расцвел здесь бесплатно. Или купи прямо сейчас:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.bolt_rounded, color: Colors.amber),
                label: const Text('Купить за 15 ⚡️'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final success = await GardenService.buyFlowerAtSlot(profileId: widget.profileId, slotIndex: index);
                  if (success) {
                    _loadGarden();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Недостаточно энергии! Сделай тренировку 💪'), backgroundColor: Colors.red),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
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
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Недостаточно энергии! 😢'), backgroundColor: Colors.red));
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
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Недостаточно энергии! 😢'), backgroundColor: Colors.red));
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
          IconButton(
            tooltip: 'Очистить сад',
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Очистить сад?'),
                  content: const Text('Все посаженные цветы и декор будут удалены. Начать заново?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Очистить', style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
              if (confirm == true) {
                await GardenService.clearGarden(widget.profileId);
                _loadGarden();
              }
            },
          ),
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
                'Тапай по светлым клеткам, чтобы выращивать слово «СУПЕР».',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              // 👇 ИСПОЛЬЗУЕМ LayoutBuilder, ЧТОБЫ СЕТКА ВЛЕЗАЛА В ЭКРАН
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Вычисляем ширину ячейки, чтобы 15 колонок ровно влезли в экран
                  // Отнимаем немного места под отступы между клетками (crossAxisSpacing: 2)
                  final double cellWidth = (constraints.maxWidth - (14 * 2)) / 15;
                  final double gridHeight = (cellWidth * 7) + (6 * 2); // 7 строк + отступы

                  return InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 3.0,
                    child: Center(
                      child: SizedBox(
                        width: constraints.maxWidth,
                        height: gridHeight,
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

                            final isWord = GardenService.superPattern.any((c) => (c[0] * 15 + c[1]) == index);

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
                                  color: item.isEmpty
                                      ? (isWord ? Colors.white.withOpacity(0.2) : Colors.green.shade600.withOpacity(0.3))
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                  border: isWord && item.isEmpty
                                      ? Border.all(color: Colors.white54, width: 1)
                                      : Border.all(color: Colors.green.shade600.withOpacity(0.2), width: 1),
                                ),
                                child: Center(
                                  child: item.isEmpty
                                      ? (isWord ? const Icon(Icons.add, color: Colors.white30, size: 12) : null)
                                      : FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}