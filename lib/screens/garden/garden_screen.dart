import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;

import '../../data/fairy_mood.dart';
import '../../services/garden_service.dart';
import '../../services/energy_service.dart';

class GardenScreen extends StatefulWidget {
  final int profileId;
  const GardenScreen({super.key, required this.profileId});

  @override
  State<GardenScreen> createState() => _GardenScreenState();
}

class _GardenScreenState extends State<GardenScreen> {
Map<int, Map<String, dynamic>> _gardenMap = {};
int _energyBalance = 0;

late TransformationController _transformationController;
final GlobalKey _gardenKey = GlobalKey();

bool _isCapturing = false;

// Размер клетки (логических пикселей)
static const double cellSize = 38.0;

// Размеры сетки (20 на 40)
static const int totalCols = 20;
static const int totalRows = 40;

// 👇 Сила подсветки клеток. Подбери на глаз: 0.05 — почти невидима,
// 0.10 — отчётливая подсказка.
static const double _gridLineAlpha = 0.08;

@override
void initState() {
super.initState();
_transformationController = TransformationController();
_loadGarden();

WidgetsBinding.instance.addPostFrameCallback((_) {
if (!mounted) return;
final screenSize = MediaQuery.of(context).size;
// Центрируем камеру ровно на центре сада
const centerX = (totalCols / 2) * cellSize;
const centerY = (totalRows / 2) * cellSize;
final dx = (screenSize.width / 2) - centerX;
final dy = (screenSize.height / 2) - centerY;
_transformationController.value = Matrix4.translationValues(dx, dy, 0.0);
});
}

@override
void dispose() {
_transformationController.dispose();
super.dispose();
}

Future<void> _loadGarden() async {
final items = await GardenService.getGarden(widget.profileId);
final balance = await EnergyService.getBalance(widget.profileId);

if (!mounted) return; // страховка на случай закрытия экрана
setState(() {
_gardenMap = {for (var item in items) item['slotIndex'] as int: item};
_energyBalance = balance;
});
}

Future<void> _shareGarden() async {
try {
setState(() => _isCapturing = true);
await Future.delayed(const Duration(milliseconds: 100));

final boundary = _gardenKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
if (boundary == null) {
setState(() => _isCapturing = false);
return;
}

final gardenImage = await boundary.toImage(pixelRatio: 2.0);

setState(() => _isCapturing = false);

final iconBytes = await rootBundle.load('assets/icon/icon.png');
final iconCodec = await ui.instantiateImageCodec(iconBytes.buffer.asUint8List());
final iconImage = (await iconCodec.getNextFrame()).image;

final fairyBytes = await rootBundle.load(FairyMood.wink.asset);
final fairyCodec = await ui.instantiateImageCodec(fairyBytes.buffer.asUint8List());
final fairyImage = (await fairyCodec.getNextFrame()).image;

const double canvasWidth = 1080.0;
const double canvasHeight = 1920.0;

final recorder = ui.PictureRecorder();
final canvas = Canvas(recorder);

// 1. Фиолетовый градиентный фон
final bgPaint = Paint()
..shader = ui.Gradient.linear(
const Offset(0, 0),
const Offset(0, canvasHeight),
[const Color(0xFF4A3CB0), const Color(0xFF6C5CE7), const Color(0xFF8C7AE6)],
[0.0, 0.5, 1.0],
);
canvas.drawRect(const Rect.fromLTWH(0, 0, canvasWidth, canvasHeight), bgPaint);

// 2. Вписываем сад по центру
double drawWidth = 960.0;
double drawHeight = 1200.0;
double targetRatio = drawWidth / drawHeight;
double drawX = (canvasWidth - drawWidth) / 2;
double drawY = (canvasHeight - drawHeight) / 2;

double srcRatio = gardenImage.width / gardenImage.height;
Rect srcRect;
if (srcRatio > targetRatio) {
double newWidth = gardenImage.height * targetRatio;
double left = (gardenImage.width - newWidth) / 2;
srcRect = Rect.fromLTWH(left, 0, newWidth, gardenImage.height.toDouble());
} else {
double newHeight = gardenImage.width / targetRatio;
double top = (gardenImage.height - newHeight) / 2;
srcRect = Rect.fromLTWH(0, top, gardenImage.width.toDouble(), newHeight);
}
Rect dstRect = Rect.fromLTWH(drawX, drawY, drawWidth, drawHeight);

canvas.drawRRect(
RRect.fromRectAndRadius(Rect.fromLTWH(drawX, drawY + 10, drawWidth, drawHeight), const Radius.circular(40)),
Paint()..color = Colors.black.withValues(alpha: 0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
);

canvas.save();
RRect rrect = RRect.fromRectAndRadius(dstRect, const Radius.circular(40));
canvas.clipRRect(rrect);
canvas.drawImageRect(gardenImage, srcRect, dstRect, Paint()..filterQuality = FilterQuality.high);
canvas.restore();

// Белая рамка
canvas.drawRRect(
rrect,
Paint()..style = PaintingStyle.stroke..strokeWidth = 8..color = Colors.white,
);

// 3. Иконка и Фея сверху
double iconSize = 120;
canvas.drawImageRect(
iconImage,
Rect.fromLTWH(0, 0, iconImage.width.toDouble(), iconImage.height.toDouble()),
Rect.fromLTWH(80, 80, iconSize, iconSize),
Paint()..filterQuality = FilterQuality.high,
);

canvas.drawImageRect(
fairyImage,
Rect.fromLTWH(0, 0, fairyImage.width.toDouble(), fairyImage.height.toDouble()),
Rect.fromLTWH(canvasWidth - 80 - iconSize, 80, iconSize, iconSize),
Paint()..filterQuality = FilterQuality.high,
);

// 4. Текст сверху
final titlePainter = TextPainter(
text: const TextSpan(text: 'Magic Workout', style: TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
textDirection: TextDirection.ltr,
)..layout();
titlePainter.paint(canvas, Offset((canvasWidth - titlePainter.width) / 2, 100));

final subtitlePainter = TextPainter(
text: const TextSpan(text: '🌸 Мой Сад Феи 🌸', style: TextStyle(color: Colors.white70, fontSize: 40, fontWeight: FontWeight.w500)),
textDirection: TextDirection.ltr,
)..layout();
subtitlePainter.paint(canvas, Offset((canvasWidth - subtitlePainter.width) / 2, 180));

// 5. Текст снизу
final footerText1 = TextPainter(
text: const TextSpan(text: 'Вырасти свой собственный сад!', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w500)),
textDirection: TextDirection.ltr,
)..layout();
footerText1.paint(canvas, Offset((canvasWidth - footerText1.width) / 2, canvasHeight - 220));

final footerText2 = TextPainter(
text: const TextSpan(text: 'your-app-link.com', style: TextStyle(color: Color(0xFFFDCB6E), fontSize: 48, fontWeight: FontWeight.bold)),
textDirection: TextDirection.ltr,
)..layout();
footerText2.paint(canvas, Offset((canvasWidth - footerText2.width) / 2, canvasHeight - 150));

final picture = recorder.endRecording();
final finalImage = await picture.toImage(canvasWidth.toInt(), canvasHeight.toInt());
final byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
if (byteData == null) return;

final bytes = byteData.buffer.asUint8List();

// Сохранение для веба
if (kIsWeb) {
final body = html.document.body; // страховка от null
if (body != null) {
final blob = html.Blob([bytes], 'image/png');
final url = html.Url.createObjectUrlFromBlob(blob);
final anchor = html.document.createElement('a') as html.AnchorElement
..href = url..style.display = 'none'..download = 'my_garden_story.png';
body.children.add(anchor);
anchor.click();
body.children.remove(anchor);
html.Url.revokeObjectUrl(url);

if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сад сохранен в Загрузки! 🌸'), backgroundColor: Colors.green));
}
}
return;
}

// Сохранение для мобилок
final xFile = XFile.fromData(bytes, name: 'my_garden_story.png', mimeType: 'image/png');
await Share.shareXFiles([xFile], text: 'Смотри, какой сад я вырастила! 🌸✨');
} catch (e) {
if (mounted) {
setState(() => _isCapturing = false);
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось сохранить: $e'), backgroundColor: Colors.red));
}
}
}

Future<void> _onCellTap(int index) async {
final item = _gardenMap[index];
if (item != null) {
_showItemMenu(index, item);
return;
}
_showGardenMenu(index);
}

void _showItemMenu(int index, Map<String, dynamic> item) {
final String type = item['flowerType'] ?? '';
final String title = _itemTitle(type);
final int refund = GardenService.refundFor(type); // цена из единого справочника

showModalBottomSheet(
context: context,
shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
builder: (ctx) {
// 👉 ИЗМЕНЕНО: обернули в Material, чтобы ListTile рисовал фон
// и ripple на нём, а не на ближайшем предке под DecoratedBox
return Material(
color: Colors.white,
borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
child: Padding(
padding: const EdgeInsets.all(20),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
const SizedBox(height: 20),
const Text(
'Зажми этот предмет пальцем и перетащи на свободную клетку, чтобы переместить его.',
textAlign: TextAlign.center,
style: TextStyle(fontSize: 14, color: Colors.grey),
),
const SizedBox(height: 20),
ListTile(
leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
title: Text('Убрать (вернуть $refund ⚡️)'),
onTap: () async {
Navigator.pop(ctx);
setState(() => _gardenMap.remove(index));
await GardenService.removeItem(widget.profileId, index, refund);
if (!mounted) return; // страховка после await
_loadGarden();
},
),
],
),
),
);
},
);
}
  // Названия предметов в одном месте
  static const Map<String, String> _itemTitles = {
    'arch': 'Розовая арка',
    'pond': 'Магический пруд',
    'lamp': 'Волшебный фонарь',
    'tree': 'Волшебное дерево',
    'fountain': 'Фонтан',
    'pavilion': 'Беседка',
    'swing': 'Качели',
    'bush': 'Цветущий куст',
    'bench': 'Скамейка',
    'stone': 'Тропинка',
    'normal': 'Лотос',
  };

  String _itemTitle(String type) => _itemTitles[type] ?? 'Растение';

  void _showGardenMenu(int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        // 👉 ИЗМЕНЕНО: цвет уехал из Container в Material — ListTile теперь
        // рисует фон и ripple на этом Material, ассерт исчезает.
        // Скругление держит clipBehavior на контейнере.
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Material(
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text('Создай свой сад (Баланс: $_energyBalance ⚡️)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        _buildBuyTile(ctx, index, 'Посадить лотос', '15', 'flower_normal.png', 'normal'),
                        const Divider(height: 1),
                        _buildBuyTile(ctx, index, 'Тропинка', '10', 'stone.png', 'stone'),
                        _buildBuyTile(ctx, index, 'Скамейка', '20', 'bench.png', 'bench'),
                        _buildBuyTile(ctx, index, 'Цветущий куст', '25', 'bush.png', 'bush'),
                        _buildBuyTile(ctx, index, 'Качели', '30', 'swing.png', 'swing'),
                        _buildBuyTile(ctx, index, 'Беседка', '40', 'pavilion.png', 'pavilion'),
                        _buildBuyTile(ctx, index, 'Фонтан', '50', 'fountain.png', 'fountain'),
                        _buildBuyTile(ctx, index, 'Волшебное дерево', '60', 'tree.png', 'tree'),
                        _buildBuyTile(ctx, index, 'Волшебный фонарь', '70', 'lamp.png', 'lamp'),
                        _buildBuyTile(ctx, index, 'Магический пруд', '80', 'pond.png', 'pond'),
                        _buildBuyTile(ctx, index, 'Розовая арка', '100', 'arch.png', 'arch'),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBuyTile(BuildContext ctx, int index, String title, String price, String image, String type) {
    return ListTile(
      leading: Image.asset(
        'assets/flowers/$image',
        width: 40,
        height: 40,
        cacheWidth: 80,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.red, size: 40),
      ),
      title: Text(title),
      subtitle: Text('$price ⚡️'),
      onTap: () async {
        Navigator.pop(ctx);
        bool success = false;
        if (type == 'normal') {
          success = await GardenService.buyFlowerAtSlot(profileId: widget.profileId, slotIndex: index);
        } else {
          success = await GardenService.placeDecor(profileId: widget.profileId, slotIndex: index, type: type);
        }

        if (!mounted) return; // страховка после await
        if (success) {
          _loadGarden();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Недостаточно энергии! 😢'), backgroundColor: Colors.red));
        }
      },
    );
  }

  // Таблица визуалов: image — файл ассета, overflow — размер OverflowBox
  // (null = обычный Center), drag — размер feedback при перетаскивании.
  static const Map<String, ({String image, double? overflow, double drag})> _itemVisuals = {
    'normal':    (image: 'flower_normal.png', overflow: null, drag: 38),
    'legendary': (image: 'flower_gold.png',   overflow: null, drag: 38),
    'wilted':    (image: 'flower_wilted.png', overflow: null, drag: 38),
    'stone':     (image: 'stone.png',         overflow: null, drag: 38),
    'bush':      (image: 'bush.png',         overflow: 80,   drag: 80),
    'bench':     (image: 'bench.png',         overflow: 85,   drag: 85),
    'swing':     (image: 'swing.png',         overflow: 90,   drag: 90),
    'fountain':  (image: 'fountain.png',      overflow: 100,  drag: 100),
    'lamp':      (image: 'lamp.png',          overflow: null, drag: 100), // overflow 70x100 — особый случай
    'pavilion':  (image: 'pavilion.png',      overflow: 110,  drag: 110),
    'tree':      (image: 'tree.png',          overflow: 120,  drag: 120),
    'pond':      (image: 'pond.png',          overflow: 120,  drag: 120),
    'arch':      (image: 'arch.png',          overflow: 130,  drag: 130),
  };

  Widget _getItemImage(String type) {
    Widget buildImage(String fileName) {
      return Image.asset(
        'assets/flowers/$fileName',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.red, size: 30),
      );
    }

    // Тропинка заполняет всю клетку
    if (type == 'stone') {
      return Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/flowers/stone.png'),
            fit: BoxFit.fill,
          ),
        ),
      );
    }

    final visuals = _itemVisuals[type];
    if (visuals == null) return buildImage('flower_normal.png');

    if (visuals.overflow != null) {
      if (type == 'lamp') {
        // особый случай: 70x100
        return OverflowBox(maxWidth: 70, maxHeight: 100, child: buildImage(visuals.image));
      }
      return OverflowBox(maxWidth: visuals.overflow!, maxHeight: visuals.overflow!, child: buildImage(visuals.image));
    }
    return buildImage(visuals.image);
  }

  double _dragSizeFor(String type) => _itemVisuals[type]?.drag ?? 38;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сад Феи', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6C5CE7),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Поделиться садом',
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            onPressed: _shareGarden,
          ),
          IconButton(
            tooltip: 'Очистить сад',
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white),
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
                if (!mounted) return; // страховка после await
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
      body: RepaintBoundary(
        key: _gardenKey,
        child: Column(
          children: [
            // Текст остается статичным сверху, чтобы не улетал при прокрутке
            if (!_isCapturing)
              Container(
                width: double.infinity,
                color: const Color(0xFF6C5CE7),
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: const Text(
                  'Нажимай на свободные клетки и создавай свой сад',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [Shadow(color: Color(0xFF1E5631), blurRadius: 4, offset: Offset(0, 2))],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            Expanded(
              child: InteractiveViewer(
                transformationController: _transformationController,
                constrained: false,
                minScale: 0.1,
                maxScale: 4.0,
                boundaryMargin: const EdgeInsets.all(2000),
                child: SizedBox(
                  width: totalCols * cellSize,  // 20 * 38 = 760
                  height: totalRows * cellSize, // 40 * 38 = 1520
                  // Stack, чтобы трава зумилась вместе с сеткой
                  child: Stack(
                    children: [
                      // 👇 ИЗМЕНЕНО: трава тайлится своим натуральным размером
                      // вместо растяжения на весь сад (была гигантская)
                      Positioned.fill(
                        child: ClipRect(
                          child: Transform.scale(
                            // Масштаб травы: меньше 1 — трава мельче.
                            // Подбери на глаз: 0.5–0.8. Не забудь согласовать
                            // width/height контейнера (делятся на scale).
                            scale: 0.6,
                            child: Container(
                              width: (totalCols * cellSize) / 0.6,
                              height: (totalRows * cellSize) / 0.6,
                              decoration: const BoxDecoration(
                                image: DecorationImage(
                                  image: AssetImage('assets/flowers/grass_bg.png'),
                                  repeat: ImageRepeat.repeat,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Сетка поверх травы
                      // 👇 ИЗМЕНЕНО: без отступов и без зазоров — клетки
                      // встают вплотную, размер клетки ровно cellSize
                      GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        cacheExtent: 0,
                        padding: EdgeInsets.zero,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: totalCols,
                        ),
                        itemCount: totalCols * totalRows,
                        itemBuilder: (context, index) {
                          final item = _gardenMap[index];
                          final type = item?['flowerType'] ?? '';

                          if (item == null) {
                            return DragTarget<int>(
                              onWillAcceptWithDetails: (details) => details.data != index,
                              onAcceptWithDetails: (details) async {
                                await GardenService.moveItem(widget.profileId, details.data, index);
                                if (!mounted) return; // страховка после await
                                _loadGarden();
                              },
                              builder: (context, candidateData, rejectedData) {
                                final isHovering = candidateData.isNotEmpty;
                                return GestureDetector(
                                  onTap: () => _onCellTap(index),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isHovering
                                          ? Colors.white.withValues(alpha: 0.5)
                                          : Colors.transparent,
                                      // 👇 Еле заметная разлиновка вместо рамок.
                                      // В режиме захвата не рисуем — на скриншотах
                                      // сада сетки не будет.
                                      border: _isCapturing
                                          ? null
                                          : Border.all(
                                        color: Colors.white.withValues(alpha: _gridLineAlpha),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          } else {
                            final imageWidget = _getItemImage(type);
                            final dragSize = _dragSizeFor(type);

                            return LongPressDraggable<int>(
                              data: index,
                              feedback: Material(
                                color: Colors.transparent,
                                child: SizedBox(
                                  width: dragSize,
                                  height: dragSize,
                                  child: FittedBox(child: imageWidget),
                                ),
                              ),
                              childWhenDragging: Opacity(opacity: 0.3, child: imageWidget),
                              child: GestureDetector(
                                onTap: () => _onCellTap(index),
                                child: type == 'stone'
                                // Тропинка — DecorationImage с BoxFit.fill,
                                // заполняет клетку целиком без костылей
                                    ? imageWidget
                                    : Center(child: imageWidget),
                              ),
                            );
                          }
                        },
                      ),
                    ],
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
// ═══ КОНЕЦ ФАЙЛА garden_screen.dart ═══
