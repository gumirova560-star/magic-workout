import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/user_profile.dart';
import '../../models/transformation_photo.dart';
import '../../services/database_helper.dart';

class TransformationScreen extends StatefulWidget {
  final UserProfile profile;

  const TransformationScreen({super.key, required this.profile});

  @override
  State<TransformationScreen> createState() => _TransformationScreenState();
}

class _TransformationScreenState extends State<TransformationScreen> {
  final ImagePicker _picker = ImagePicker();
  List<TransformationPhoto> _photos = [];
  late UserProfile _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    final freshProfile = await DatabaseHelper.instance.getProfileById(_profile.id!);
    final photos = await DatabaseHelper.instance.getTransformationPhotos(_profile.id!);

    setState(() {
      if (freshProfile != null) _profile = freshProfile;
      _photos = photos;
      _loading = false;
    });
  }

  Future<void> _pickImage({
    required String type, // 'before' | 'after'
    int month = 1,
    String angle = 'front',
  }) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    final base64String = base64Encode(bytes);

    if (type == 'before') {
      // Обновляем профиль (сохраняем фото "До")
      UserProfile updated = _profile;
      if (angle == 'front') updated = _profile.copyWith(beforePhotoPath: base64String);
      if (angle == 'side') updated = _profile.copyWith(beforeSidePath: base64String);
      if (angle == 'back') updated = _profile.copyWith(beforeBackPath: base64String);

      await DatabaseHelper.instance.updateProfile(updated);
      _profile = updated;
    } else {
      // Добавляем фото "После"
      final existing = _photos.where((p) => p.monthNumber == month && p.angle == angle).toList();
      for (var p in existing) {
        if (p.id != null) await DatabaseHelper.instance.deleteTransformationPhoto(p.id!);
      }

      final newPhoto = TransformationPhoto(
        profileId: _profile.id!,
        imagePath: base64String,
        monthNumber: month,
        angle: angle,
        createdAt: DateTime.now(),
      );
      await DatabaseHelper.instance.addTransformationPhoto(newPhoto);
    }

    _loadPhotos();
  }

  void _showFullScreenImage(String base64String, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(title, style: const TextStyle(color: Colors.white)),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.memory(base64Decode(base64String), fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Map<int, List<TransformationPhoto>> photosByMonth = {};
    for (var p in _photos) {
      photosByMonth.putIfAbsent(p.monthNumber, () => []).add(p);
    }
    final sortedMonths = photosByMonth.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('Моя трансформация')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Твой прогресс', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Делай фото с трёх ракурсов.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 24),

                // ⚠️ Блок "До" с 3 ракурсами
                Text('Начало пути (До)', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildBeforeSlot(theme, 'front', 'Спереди', _profile.beforePhotoPath),
                    const SizedBox(width: 8),
                    _buildBeforeSlot(theme, 'side', 'Сбоку', _profile.beforeSidePath),
                    const SizedBox(width: 8),
                    _buildBeforeSlot(theme, 'back', 'Сзади', _profile.beforeBackPath),
                  ],
                ),

                const SizedBox(height: 32),
                Text('История по месяцам', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 16),

                ...sortedMonths.map((month) {
                  return _buildMonthCard(theme, month, photosByMonth[month]!);
                }),

                if (sortedMonths.isEmpty || sortedMonths.last < 12)
                  _buildAddMonthButton(context, sortedMonths.isEmpty ? 1 : sortedMonths.last + 1),
              ],
            ),
    );
  }

  Widget _buildBeforeSlot(ThemeData theme, String angle, String label, String? base64) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (base64 != null && base64.isNotEmpty) {
            _showFullScreenImage(base64, 'Фото «До» · $label');
          } else {
            _pickImage(type: 'before', angle: angle);
          }
        },
        child: AspectRatio(
          aspectRatio: 0.75,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3), width: 1.5),
              image: base64 != null && base64.isNotEmpty
                  ? DecorationImage(
                      image: MemoryImage(base64Decode(base64)),
                      fit: BoxFit.contain,
                    )
                  : null,
            ),
            child: base64 == null || base64.isEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded, color: theme.colorScheme.primary),
                      const SizedBox(height: 4),
                      Text(label, style: TextStyle(fontSize: 10, color: theme.colorScheme.primary)),
                    ],
                  )
                : Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(10.5)),
                      ),
                      child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthCard(ThemeData theme, int month, List<TransformationPhoto> photos) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Месяц $month', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildAfterSlot(theme, month, 'front', 'Спереди', photos),
                const SizedBox(width: 8),
                _buildAfterSlot(theme, month, 'side', 'Сбоку', photos),
                const SizedBox(width: 8),
                _buildAfterSlot(theme, month, 'back', 'Сзади', photos),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAfterSlot(ThemeData theme, int month, String angle, String label, List<TransformationPhoto> photos) {
    final photo = photos.where((p) => p.angle == angle).firstOrNull;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (photo != null) {
            _showFullScreenImage(photo.imagePath, 'Месяц $month · $label');
          } else {
            _pickImage(type: 'after', month: month, angle: angle);
          }
        },
        child: AspectRatio(
          aspectRatio: 0.75,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: photo != null ? theme.colorScheme.primary.withOpacity(0.5) : theme.colorScheme.onSurface.withOpacity(0.1),
                width: 1.5,
              ),
              image: photo != null
                  ? DecorationImage(
                      image: MemoryImage(base64Decode(photo.imagePath)),
                      fit: BoxFit.contain,
                    )
                  : null,
            ),
            child: photo == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded, color: theme.colorScheme.primary.withOpacity(0.5)),
                      const SizedBox(height: 4),
                      Text(label, style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withOpacity(0.5))),
                    ],
                  )
                : Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(10.5)),
                      ),
                      child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddMonthButton(BuildContext context, int nextMonth) {
    return OutlinedButton.icon(
      onPressed: () => _pickImage(type: 'after', month: nextMonth, angle: 'front'),
      icon: const Icon(Icons.calendar_month_rounded),
      label: Text('Добавить месяц $nextMonth'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}