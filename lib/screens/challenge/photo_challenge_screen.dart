import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/daily_challenge.dart';
import '../../data/challenge_data.dart';
import '../../services/challenge_service.dart';
import '../../services/database_helper.dart';

class PhotoChallengeScreen extends StatefulWidget {
  final int profileId;
  final DailyChallenge challenge;

  const PhotoChallengeScreen({super.key, required this.profileId, required this.challenge});

  @override
  State<PhotoChallengeScreen> createState() => _PhotoChallengeScreenState();
}

class _PhotoChallengeScreenState extends State<PhotoChallengeScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isCompleted = false;
  bool _isUploading = false;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _isCompleted = widget.challenge.isCompleted;
    _imagePath = widget.challenge.proofImagePath;
  }

  Future<void> _pickImage() async {
    if (_isUploading) return;

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70, // Сжимаем, чтобы не занимало много места
      );
      if (image == null) return;

      setState(() => _isUploading = true);

      // Сохраняем путь к картинке в БД и отмечаем как выполненное
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'daily_challenges',
        {
          'currentProgress': widget.challenge.targetValue,
          'isCompleted': 1,
          'proofImagePath': image.path,
        },
        where: 'id = ?',
        whereArgs: [widget.challenge.id],
      );

      // Начисляем энергию
      final config = kDailyChallenges.firstWhere((c) => c.id == widget.challenge.taskId);
      final granted = await ChallengeService.tryAwardReward(
        profileId: widget.profileId,
        challengeId: widget.challenge.id!,
        energyAmount: config.energyReward,
      );

      if (!mounted) return;
      setState(() {
        _isCompleted = true;
        _imagePath = image.path;
        _isUploading = false;
      });

      _showCompletionDialog(granted, config.energyReward);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showCompletionDialog(bool granted, int reward) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('🎉 Отлично!', textAlign: TextAlign.center),
        content: Text(
          granted
              ? 'Скриншот загружен!\nТы заработал $reward ⚡️ Жизненной Энергии.'
              : 'Скриншот загружен! (Награда уже была получена ранее)',
          textAlign: TextAlign.center,
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Забрать награду'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = kDailyChallenges.firstWhere((c) => c.id == widget.challenge.taskId);

    return Scaffold(
      appBar: AppBar(title: Text(config.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Spacer(),
              // Иконка шагов
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('🚶‍♀️', style: TextStyle(fontSize: 60)),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Прогулка на ${widget.challenge.targetValue} шагов',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Пройди необходимое количество шагов, сделай скриншот с шагомера и прикрепи его сюда.',
                style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Превью картинки (если есть)
              if (_imagePath != null && !kIsWeb) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    File(_imagePath!),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),
              ] else if (_imagePath != null && kIsWeb) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Expanded(child: Text('Скриншот успешно прикреплён!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              const Spacer(),

              // Кнопка
              if (!_isCompleted)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : _pickImage,
                    icon: _isUploading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.upload_file_rounded),
                    label: Text(_isUploading ? 'Загрузка...' : 'Прикрепить скриншот'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00B894).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, color: Color(0xFF00B894)),
                      SizedBox(width: 8),
                      Text('Выполнено', style: TextStyle(color: Color(0xFF00B894), fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}