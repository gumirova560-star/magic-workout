import 'package:flutter/material.dart';
import '../../models/exercise.dart';

class ExercisePickerScreen extends StatefulWidget {
  final List<Exercise> allExercises;
  final List<int> initialSelectedIds;
  final int maxSelection;

  const ExercisePickerScreen({
    super.key,
    required this.allExercises,
    required this.initialSelectedIds,
    required this.maxSelection,
  });

  @override
  State<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends State<ExercisePickerScreen> {
  late Set<int> _selectedIds;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.initialSelectedIds.toSet();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        if (_selectedIds.length < widget.maxSelection) {
          _selectedIds.add(id);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Можно выбрать максимум ${widget.maxSelection} упражнения')),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Фильтруем упражнения по поисковому запросу
    final filtered = widget.allExercises.where((e) {
      if (_searchQuery.isEmpty) return true;
      return e.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Каталог упражнений'),
      ),
      body: Column(
        children: [
          // 👇 Строка поиска
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Поиск упражнения...',
                hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4)),
                prefixIcon: Icon(Icons.search_rounded, color: theme.colorScheme.primary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
                    : null,
                filled: true,
                fillColor: theme.colorScheme.primary.withOpacity(0.05),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none
                ),
              ),
            ),
          ),

          // 👇 Список упражнений
          Expanded(
            child: filtered.isEmpty
                ? Center(
              child: Text(
                  'Ничего не найдено',
                  style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5))
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final ex = filtered[index];
                final isSelected = _selectedIds.contains(ex.id);

                // Получаем читаемые названия групп мышц
                final muscleText = ex.muscleGroups.map((m) => _getZoneLabel(m)).join(', ');

                return CheckboxListTile(
                  title: Text(
                      ex.name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                      )
                  ),
                  subtitle: Text(muscleText, style: const TextStyle(fontSize: 12)),
                  value: isSelected,
                  onChanged: (_) => _toggleSelection(ex.id!),
                  activeColor: const Color(0xFFFFB800),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                );
              },
            ),
          ),

          // 👇 Кнопка «Готово» внизу
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _selectedIds.toList()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    'Готово (выбрано ${_selectedIds.length} из ${widget.maxSelection})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getZoneLabel(String zone) {
    switch (zone) {
      case 'glutes': return 'Ягодицы';
      case 'legs': return 'Ноги';
      case 'abs': return 'Пресс';
      case 'back': return 'Спина';
      case 'chest': return 'Грудь';
      case 'shoulders': return 'Плечи';
      case 'arms': return 'Руки';
      case 'cardio': return 'Кардио';
      default: return zone;
    }
  }
}