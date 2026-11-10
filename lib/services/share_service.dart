import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/share_card.dart';

class ShareService {
  static Future<void> shareWorkoutCard({
    required BuildContext context,
    required ShareCardMode mode,
    required String userName,
    required String title,
    required int minutes,
    required int exercisesCount,
    required int workoutsCount,
    required int streakWeeks,
    String? challengeStat, // 👈 Добавлено
  }) async {
    final GlobalKey boundaryKey = GlobalKey();

    // Показываем диалог с превью
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              key: boundaryKey,
              child: ShareCard(
                mode: mode,
                userName: userName,
                title: title,
                minutes: minutes,
                exercisesCount: exercisesCount,
                workoutsCount: workoutsCount,
                streakWeeks: streakWeeks,
                challengeStat: challengeStat, // 👈 Передаем
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final shareResult = await _captureAndShare(boundaryKey);
                      if (ctx.mounted && shareResult != null) {
                        Navigator.pop(ctx);
                      }
                    },
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Опубликовать'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<String?> _captureAndShare(GlobalKey key) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/share_card_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles([XFile(file.path)], text: 'Мой прогресс в Magic Workout! 💪');
      return file.path;
    } catch (e) {
      debugPrint('Ошибка при создании карточки: $e');
      return null;
    }
  }
}