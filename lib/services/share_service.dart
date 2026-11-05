import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../widgets/share_card.dart';

// 👇 Импорты для веба (работают только в браузере)
import 'dart:html' as html;

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
  }) async {
    final GlobalKey repaintKey = GlobalKey();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Поделиться результатом', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Так будет выглядеть твоя карточка:', style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 16),
              FittedBox(
                fit: BoxFit.contain,
                child: RepaintBoundary(
                  key: repaintKey,
                  child: ShareCard(
                    mode: mode,
                    userName: userName,
                    title: title,
                    minutes: minutes,
                    exercisesCount: exercisesCount,
                    workoutsCount: workoutsCount,
                    streakWeeks: streakWeeks,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _captureAndShare(repaintKey);
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
    );
  }

  static Future<void> _captureAndShare(GlobalKey key) async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final Uint8List bytes = byteData.buffer.asUint8List();

      if (kIsWeb) {
        // Скачиваем файл в "Загрузки" на ПК
        final blob = html.Blob([bytes], 'image/png');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..style.display = 'none'
          ..download = 'magic_workout_result.png';

        html.document.body?.children.add(anchor);
        anchor.click();
        html.document.body?.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
      } else {
        // На телефоне открываем системное окно "Поделиться"
        final xFile = XFile.fromData(bytes, mimeType: 'image/png', name: 'magic_workout_result.png');
        await Share.shareXFiles([xFile], text: 'Смотри, каких результатов я достигла в Magic Workout! 🧚‍♀️🔥');
      }
    } catch (e) {
      debugPrint('Ошибка при шэринге: $e');
    }
  }
}