import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/user_profile.dart';
import '../../services/database_helper.dart';
import '../main_screen.dart'; // ⚠️ ИМПОРТ ДЛЯ ПЕРЕХОДА

class ProfileEditScreen extends StatefulWidget {
  final UserProfile? profile;

  const ProfileEditScreen({super.key, this.profile});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  // Контроллеры для гибридных полей
  late TextEditingController _ageController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;

  String _gender = 'female';
  int _age = 30;
  double _height = 170;
  double _weight = 65;
  String _level = 'beginner';
  String _goal = 'tone';
  String _equipment = 'dumbbells';
  int _daysPerWeek = 3;
  int _sessionMinutes = 45;

  final Set<String> _focusAreas = {};
  final Set<String> _limitations = {};

  static const int _maxFocusAreas = 3;

  @override
  void initState() {
    super.initState();
    if (widget.profile != null) {
      final p = widget.profile!;
      _nameController.text = p.name;
      _gender = p.gender;
      _age = p.age;
      _height = p.height;
      _weight = p.weight;
      _level = p.level;
      _goal = p.goal;
      _equipment = p.equipment;
      _daysPerWeek = p.daysPerWeek;
      _sessionMinutes = p.sessionMinutes;
      _focusAreas.addAll(p.focusAreas.take(_maxFocusAreas));
      _limitations.addAll(p.limitations);
    }

    _ageController = TextEditingController(text: _age.toString());
    _heightController = TextEditingController(text: _height.toInt().toString());
    _weightController = TextEditingController(text: _weight.toStringAsFixed(_weight % 1 == 0 ? 0 : 1));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final profile = UserProfile(
      id: widget.profile?.id,
      name: _nameController.text.trim(),
      gender: _gender,
      age: _age,
      height: _height,
      weight: _weight,
      level: _level,
      goal: _goal,
      focusAreas: _focusAreas.take(_maxFocusAreas).toList(),
      limitations: _limitations.toList(),
      equipment: _equipment,
      daysPerWeek: _daysPerWeek,
      sessionMinutes: _sessionMinutes,
      createdAt: widget.profile?.createdAt,
    );

    try {
      if (widget.profile == null) {
        await DatabaseHelper.instance.addProfile(profile);
      } else {
        await DatabaseHelper.instance.updateProfile(profile);
      }

      if (!mounted) return;

      // ⚠️ ЕСЛИ ЭТО СОЗДАНИЕ (или если пришли из онбординга) — перекидываем на MainScreen
      if (widget.profile == null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
        );
      } else {
        // Если это редактирование из Настроек — просто возвращаемся назад
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.profile != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Редактировать' : 'Создать профиль')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Имя профиля', hintText: 'Я, Жена, Муж...', prefixIcon: Icon(Icons.person_rounded)),
              validator: (v) => v?.isEmpty ?? true ? 'Введите имя' : null,
            ),
            const SizedBox(height: 24),

            _sectionTitle('Пол'),
            Row(
              children: [
                Expanded(child: _choiceButton(label: 'Женский', icon: Icons.female_rounded, isSelected: _gender == 'female', onTap: () => setState(() => _gender = 'female'))),
                const SizedBox(width: 12),
                Expanded(child: _choiceButton(label: 'Мужской', icon: Icons.male_rounded, isSelected: _gender == 'male', onTap: () => setState(() => _gender = 'male'))),
              ],
            ),
            const SizedBox(height: 24),

            _sectionTitle('Параметры'),

            // ⚠️ Гибридные поля: Ползунок + Текстовое поле
            _buildHybridSlider(
              label: 'Возраст',
              controller: _ageController,
              value: _age.toDouble(),
              min: 14,
              max: 90,
              divisions: 76,
              unit: 'лет',
              onChanged: (v) {
                setState(() => _age = v.toInt());
                _ageController.text = _age.toString();
              },
              onTextChanged: (text) {
                final parsed = int.tryParse(text);
                if (parsed != null && parsed >= 14 && parsed <= 90) {
                  setState(() => _age = parsed);
                }
              },
            ),
            _buildHybridSlider(
              label: 'Рост',
              controller: _heightController,
              value: _height,
              min: 130,
              max: 220,
              divisions: 90,
              unit: 'см',
              onChanged: (v) {
                setState(() => _height = v);
                _heightController.text = _height.toInt().toString();
              },
              onTextChanged: (text) {
                final parsed = double.tryParse(text);
                if (parsed != null && parsed >= 130 && parsed <= 220) {
                  setState(() => _height = parsed);
                }
              },
            ),
            _buildHybridSlider(
              label: 'Вес',
              controller: _weightController,
              value: _weight,
              min: 35,
              max: 200,
              divisions: 165,
              unit: 'кг',
              onChanged: (v) {
                setState(() => _weight = v);
                _weightController.text = _weight.toStringAsFixed(_weight % 1 == 0 ? 0 : 1);
              },
              onTextChanged: (text) {
                final parsed = double.tryParse(text);
                if (parsed != null && parsed >= 35 && parsed <= 200) {
                  setState(() => _weight = parsed);
                }
              },
            ),
            const SizedBox(height: 24),

            _sectionTitle('Уровень подготовки'),
            ..._buildOptions(
              options: [
                ('beginner', 'Новичок', Icons.looks_one_rounded),
                ('intermediate', 'Средний', Icons.looks_two_rounded),
                ('advanced', 'Продвинутый', Icons.looks_3_rounded),
              ],
              selected: _level,
              onSelected: (v) => setState(() => _level = v),
            ),
            const SizedBox(height: 24),

            _sectionTitle('Цель'),
            ..._buildOptions(
              options: [
                ('lose_weight', 'Похудеть', Icons.trending_down_rounded),
                ('gain_mass', 'Набрать массу', Icons.trending_up_rounded),
                ('tone', 'Тонус', Icons.favorite_rounded),
                ('strength', 'Сила', Icons.bolt_rounded),
              ],
              selected: _goal,
              onSelected: (v) => setState(() => _goal = v),
            ),
            const SizedBox(height: 24),

            _sectionTitle('Ограничения / травмы'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('back', 'Спина', _limitations),
                _chip('knees', 'Колени', _limitations),
                _chip('shoulders', 'Плечи', _limitations),
                _chip('neck', 'Шея', _limitations),
              ],
            ),
            const SizedBox(height: 24),

            _sectionTitle('Инвентарь'),
            ..._buildOptions(
              options: [
                ('gym', 'Зал', Icons.fitness_center_rounded),
                ('dumbbells', 'Гантели', Icons.sports_gymnastics_rounded),
                ('bodyweight', 'Своё тело', Icons.accessibility_new_rounded),
                ('mixed', 'Смешанно', Icons.shuffle_rounded),
              ],
              selected: _equipment,
              onSelected: (v) => setState(() => _equipment = v),
            ),
            const SizedBox(height: 24),

            _sectionTitle('Дней в неделю'),
            _buildSlider(
              label: 'Тренировок',
              value: _daysPerWeek.toDouble(),
              min: 2,
              max: 6,
              divisions: 4,
              unit: 'дн',
              onChanged: (v) => setState(() => _daysPerWeek = v.toInt()),
            ),
            const SizedBox(height: 24),

            _sectionTitle('Время тренировки'),
            _buildSlider(
              label: 'Длительность',
              value: _sessionMinutes.toDouble(),
              min: 30,
              max: 90,
              divisions: 4,
              unit: 'мин',
              onChanged: (v) => setState(() => _sessionMinutes = v.toInt()),
            ),
            const SizedBox(height: 32),

            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded),
              label: Text(isEdit ? 'Сохранить' : 'Создать профиль'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    );
  }

  Widget _choiceButton({required String label, required IconData icon, required bool isSelected, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary.withOpacity(0.15) : theme.colorScheme.surface,
          border: Border.all(color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.15), width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.6)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface)),
          ],
        ),
      ),
    );
  }

  Widget _buildHybridSlider({
    required String label,
    required TextEditingController controller,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String unit,
    required ValueChanged<double> onChanged,
    required ValueChanged<String> onTextChanged,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: theme.textTheme.bodyLarge),
              SizedBox(
                width: 80,
                height: 36,
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: onTextChanged,
                ),
              ),
              Text(unit, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
            ],
          ),
          Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildSlider({required String label, required double value, required double min, required double max, required int divisions, required String unit, required ValueChanged<double> onChanged}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label, style: theme.textTheme.bodyLarge),
            Text('${value.toInt()} $unit', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
          ]),
          Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged),
        ],
      ),
    );
  }

  List<Widget> _buildOptions({required List<(String, String, IconData)> options, required String selected, required ValueChanged<String> onSelected}) {
    return options.map((opt) {
      final (value, label, icon) = opt;
      final isSelected = selected == value;
      final theme = Theme.of(context);

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          onTap: () => onSelected(value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? theme.colorScheme.primary.withOpacity(0.12) : theme.colorScheme.surface,
              border: Border.all(color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.1), width: isSelected ? 2 : 1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(icon, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.6)),
                const SizedBox(width: 12),
                Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface)),
                const Spacer(),
                if (isSelected) Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _chip(String value, String label, Set<String> collection) {
    final isSelected = collection.contains(value);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (v) => setState(() {
        if (v) { collection.add(value); } else { collection.remove(value); }
      }),
    );
  }
}
// ═══ ФАЙЛ profile_edit_screen.dart ЗАВЕРШЁН ═══