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

  // 👇 Размеры сетки (20 на 40)
  static const int totalCols = 20;
  static const int totalRows = 40;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _loadGarden();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final screenSize = MediaQuery.of(context).size;
      // Центрируем камеру ровно на центре сада
      const centerX = (totalCols / 2) * 38.0;
      const centerY = (totalRows / 2) * 38.0;
      final dx = (screenSize.width / 2) - centerX;
      final dy = (screenSize.height / 2) - centerY;
      _transformationController.value = Matrix4.identity()..translate(dx, dy);
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

    if (mounted) {
      setState(() {
        _gardenMap = {for (var item in items) item['slotIndex'] as int: item};
        _energyBalance = balance;
      });
    }
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

      final bgPaint = Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          const Offset(0, canvasHeight),
          [const Color(0xFF4A3CB0), const Color(0xFF6C5CE7), const Color(0xFF8C7AE6)],
          [0.0, 0.5, 1.0],
        );
      canvas.drawRect(const Rect.fromLTWH(0, 0, canvasWidth, canvasHeight), bgPaint);

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

      canvas.drawRRect(
        rrect,
        Paint()..style = PaintingStyle.stroke..strokeWidth = 8..color = Colors.white,
      );

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

      if (kIsWeb) {
        final blob = html.Blob([bytes], 'image/png');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url..style.display = 'none'..download = 'my_garden_story.png';
        html.document.body!.children.add(anchor);
        anchor.click();
        html.document.body!.children.remove(anchor);
        html.Url.revokeObjectUrl(url);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сад сохранен в Загрузки! 🌸'), backgroundColor: Colors.green));
        }
        return;
      }

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
    String title = 'Предмет';
    String type = item['flowerType'] ?? '';
    int refund = 0;

    if (type == 'arch') { title = 'Розовая арка'; refund = 100; }
    else if (type == 'pond') { title = 'Магический пруд'; refund = 80; }
    else if (type == 'lamp') { title = 'Волшебный фонарь'; refund = 70; }
    else if (type == 'tree') { title = 'Волшебное дерево'; refund = 60; }
    else if (type == 'fountain') { title = 'Фонтан'; refund = 50; }
    else if (type == 'pavilion') { title = 'Беседка'; refund = 40; }
    else if (type == 'swing') { title = 'Качели'; refund = 30; }
    else if (type == 'bush') { title = 'Цветущий куст'; refund = 25; }
    else if (type == 'bench') { title = 'Скамейка'; refund = 20; }
    else if (type == 'stone') { title = 'Тропинка'; refund = 10; }
    else if (type == 'normal') { title = 'Лотос'; refund = 15; }
    else if (type == 'legendary') { title = 'Золотой цветок'; refund = 30; }
    else { title = 'Растение'; refund = 10; }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
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
                  _loadGarden();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showGardenMenu(int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.all(20),
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

        if (success) {
          _loadGarden();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Недостаточно энергии! 😢'), backgroundColor: Colors.red));
        }
      },
    );
  }

  Widget _getItemImage(String type) {
    Widget buildImage(String fileName) {
      return Image.asset(
        'assets/flowers/$fileName',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.red, size: 30),
      );
    }

    if (type == 'stone') {
      return Image.asset(
        'assets/flowers/stone.png',
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (type == 'arch') {
      return OverflowBox(maxWidth: 130, maxHeight: 130, child: buildImage('arch.png'));
    } else if (type == 'pond') {
      return OverflowBox(maxWidth: 120, maxHeight: 120, child: buildImage('pond.png'));
    } else if (type == 'tree') {
      return OverflowBox(maxWidth: 120, maxHeight: 120, child: buildImage('tree.png'));
    } else if (type == 'lamp') {
      return OverflowBox(maxWidth: 70, maxHeight: 100, child: buildImage('lamp.png'));
    } else if (type == 'pavilion') {
      return OverflowBox(maxWidth: 110, maxHeight: 110, child: buildImage('pavilion.png'));
    } else if (type == 'fountain') {
      return OverflowBox(maxWidth: 100, maxHeight: 100, child: buildImage('fountain.png'));
    } else if (type == 'swing') {
      return OverflowBox(maxWidth: 90, maxHeight: 90, child: buildImage('swing.png'));
    } else if (type == 'bush') {
      return OverflowBox(maxWidth: 80, maxHeight: 80, child: buildImage('bush.png'));
    } else if (type == 'bench') {
      return OverflowBox(maxWidth: 85, maxHeight: 85, child: buildImage('bench.png'));
    } else if (type == 'legendary') {
      return buildImage('flower_gold.png');
    } else if (type == 'wilted') {
      return buildImage('flower_wilted.png');
    } else {
      return buildImage('flower_normal.png');
    }
  }

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
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/flowers/grass_bg.png',
                fit: BoxFit.cover,
                cacheWidth: 1080,
              ),
            ),

            Column(
              children: [
                if (!_isCapturing)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
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
                      width: (totalCols * 38.0),  // 20 * 38 = 760
                      height: (totalRows * 38.0), // 40 * 38 = 1520
                      child: GridView.builder(
                        scrollCacheExtent: const ScrollCacheExtent.pixels(0), physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.all(_isCapturing ? 0 : 8),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: totalCols,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
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
                                _loadGarden();
                              },
                              builder: (context, candidateData, rejectedData) {
                                final isHovering = candidateData.isNotEmpty;
                                return GestureDetector(
                                  onTap: () => _onCellTap(index),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _isCapturing
                                          ? Colors.transparent
                                          : (isHovering ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.06)),
                                      borderRadius: BorderRadius.circular(4),
                                      border: _isCapturing ? null : Border.all(color: Colors.black12, width: 0.5),
                                    ),
                                  ),
                                );
                              },
                            );
                          } else {
                            final imageWidget = _getItemImage(type);

                            double dragSize = 50;
                            if (type == 'arch') {
                              dragSize = 130;
                            } else if (type == 'pond' || type == 'tree') dragSize = 120;
                            else if (type == 'pavilion') dragSize = 110;
                            else if (type == 'fountain' || type == 'lamp') dragSize = 100;
                            else if (type == 'swing') dragSize = 90;
                            else if (type == 'bush' || type == 'bench') dragSize = 85;
                            else if (type == 'normal' || type == 'legendary' || type == 'wilted' || type == 'stone') dragSize = 38;

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
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: type == 'stone' ? BorderRadius.zero : BorderRadius.circular(4),
                                    border: (_isCapturing || type == 'stone') ? null : Border.all(color: Colors.black12, width: 0.5),
                                  ),
                                  child: type == 'stone'
                                      ? imageWidget
                                      : Center(child: imageWidget),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}