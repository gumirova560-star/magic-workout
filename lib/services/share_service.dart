import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import '../widgets/share_card.dart';

import 'web_downloader_stub.dart' if (dart.library.html) 'web_downloader.dart' as web_downloader;

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
    bool isWeekInProgress = false,
    int plannedDays = 3,
    String? challengeStat,
    String? challengeMainStat,
    String? challengeSubStat,
    String? challengeTimeStat,
  }) async {
    final GlobalKey boundaryKey = GlobalKey();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: RepaintBoundary(
                  key: boundaryKey,
                  child: ShareCard(
                    mode: mode,
                    userName: userName,
                    title: title,
                    minutes: minutes,
                    exercisesCount: exercisesCount,
                    workoutsCount: workoutsCount,
                    streakWeeks: streakWeeks,
                    isWeekInProgress: isWeekInProgress,
                    plannedDays: plannedDays,
                    challengeStat: challengeStat,
                    challengeMainStat: challengeMainStat,
                    challengeSubStat: challengeSubStat,
                    challengeTimeStat: challengeTimeStat,
                  ),
                ),
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
                    icon: Icon(kIsWeb ? Icons.download_rounded : Icons.share_rounded, size: 18),
                    label: Text(kIsWeb ? 'Скачать' : 'Опубликовать'),
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

      final bytes = byteData.buffer.asUint8List();
      final fileName = 'magic_workout_${DateTime.now().millisecondsSinceEpoch}.png';

      bool isMobile = false;
      if (kIsWeb) {
        if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android) {
          isMobile = true;
        }
      }

      if (kIsWeb && !isMobile) {
        // Для ПК в браузере — скачиваем
        await web_downloader.downloadFile(bytes, fileName);
        return 'success';
      } else {
        // Для телефонов и мобильных браузеров — открываем шторку
        final xFile = XFile.fromData(
            bytes,
            mimeType: 'image/png',
            name: fileName
        );
        // 👇 ПРАВИЛЬНЫЙ СИНТАКСИС ДЛЯ ВЕРСИИ 10.1.1
        await Share.shareXFiles([xFile], text: 'Мой прогресс в Magic Workout! 💪');
        return 'success';
      }
    } catch (e) {
      debugPrint('Ошибка при создании карточки: $e');
      return null;
    }
  }
}