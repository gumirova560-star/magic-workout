import '../models/exercise.dart';

enum ExerciseType { base, isolation }

class ExerciseMeta {
  final String zone;
  final ExerciseType type;
  const ExerciseMeta(this.zone, this.type);
}

const Map<String, ExerciseMeta> kAbsoluteExerciseDictionary = {
  // ═══ ЯГОДИЦЫ ═══
  'Ягодичный мост': ExerciseMeta('glutes', ExerciseType.base),
  'Ягодичный мост со штангой': ExerciseMeta('glutes', ExerciseType.base),
  'Хип-траст': ExerciseMeta('glutes', ExerciseType.base),
  'Реверанс-выпад': ExerciseMeta('glutes', ExerciseType.base),
  'Зашагивания на платформу с гантелями': ExerciseMeta('glutes', ExerciseType.base),
  'Румынская тяга на одной ноге с гантелью': ExerciseMeta('glutes', ExerciseType.base),
  'Обратные выпады с собственным весом': ExerciseMeta('glutes', ExerciseType.base),
  'Отведение ноги в сторону стоя': ExerciseMeta('glutes', ExerciseType.isolation),
  'Отведение ноги назад в блоке': ExerciseMeta('glutes', ExerciseType.isolation),
  'Отведение ноги в сторону с резинкой': ExerciseMeta('glutes', ExerciseType.isolation),
  'Отведение ноги в кроссовере': ExerciseMeta('glutes', ExerciseType.isolation),
  'Отведение ноги в сторону в кроссовере': ExerciseMeta('glutes', ExerciseType.isolation),
  'Разведение ног в тренажёре': ExerciseMeta('glutes', ExerciseType.isolation),
  'Ягодичный мост на одной ноге': ExerciseMeta('glutes', ExerciseType.isolation),
  'Махи ногой назад (на четвереньках)': ExerciseMeta('glutes', ExerciseType.isolation),
  'Махи ногой в сторону (на четвереньках)': ExerciseMeta('glutes', ExerciseType.isolation),
  'Отведение ноги лежа на боку': ExerciseMeta('glutes', ExerciseType.isolation),
  'Ягодичный мост с резинкой (лёжа)': ExerciseMeta('glutes', ExerciseType.isolation),
  'Ходьба с резинкой (Monster Walk)': ExerciseMeta('glutes', ExerciseType.isolation),
  'Разгибание бедра в тренажёре': ExerciseMeta('glutes', ExerciseType.isolation),
  'Тяга ноги назад с нижнего блока': ExerciseMeta('glutes', ExerciseType.isolation),
  'Фрог-памп': ExerciseMeta('glutes', ExerciseType.isolation),

  // ═══ НОГИ ═══
  'Приседания со штангой': ExerciseMeta('legs', ExerciseType.base),
  'Приседания с гантелями': ExerciseMeta('legs', ExerciseType.base),
  'Приседания сумо': ExerciseMeta('legs', ExerciseType.base),
  'Выпады вперёд с гантелями': ExerciseMeta('legs', ExerciseType.base),
  'Болгарский выпад': ExerciseMeta('legs', ExerciseType.base),
  'Зашагивания на платформу': ExerciseMeta('legs', ExerciseType.base),
  'Приседания на одной ноге': ExerciseMeta('legs', ExerciseType.base),
  'Боковые выпады гантелями': ExerciseMeta('legs', ExerciseType.base),
  'Жим ногами в тренажёре': ExerciseMeta('legs', ExerciseType.base),
  'Румынская тяга со штангой': ExerciseMeta('legs', ExerciseType.base),
  'Румынская тяга на одной ноге': ExerciseMeta('legs', ExerciseType.base),
  'Наклоны со штангой': ExerciseMeta('legs', ExerciseType.base),
  'Выпады назад с гантелями': ExerciseMeta('legs', ExerciseType.base),
  'Стульчик у стены': ExerciseMeta('legs', ExerciseType.isolation),
  'Боковые выпады с собственным весом': ExerciseMeta('legs', ExerciseType.base),
  'Приседания сумо с собственным весом': ExerciseMeta('legs', ExerciseType.base),
  'Гакк-приседания': ExerciseMeta('legs', ExerciseType.base),
  'Приседания в тренажере Смита': ExerciseMeta('legs', ExerciseType.base),

  'Подъёмы на носки стоя': ExerciseMeta('legs', ExerciseType.base),
  'Подъёмы на носки сидя': ExerciseMeta('legs', ExerciseType.base),
  'Подъемы на носки в тренажере Смита': ExerciseMeta('legs', ExerciseType.base),
  'Подъемы на носки стоя в тренажере': ExerciseMeta('legs', ExerciseType.isolation),
  'Разгибание ног в тренажёре': ExerciseMeta('legs', ExerciseType.isolation),
  'Сведение ног в тренажёре': ExerciseMeta('legs', ExerciseType.isolation),
  'Сгибание ног в тренажёре': ExerciseMeta('legs', ExerciseType.isolation),
  'Гиперэкстензия': ExerciseMeta('legs', ExerciseType.isolation),
  'Гиперэкстензия с весом': ExerciseMeta('legs', ExerciseType.isolation),
  'Подъёмы на носки на одной ноге': ExerciseMeta('legs', ExerciseType.isolation),
  'Подъёмы на носки с гантелями': ExerciseMeta('legs', ExerciseType.isolation),
  'Жим носками в тренажере': ExerciseMeta('legs', ExerciseType.isolation),
  'Подъемы на носки с гантелью (одна нога)': ExerciseMeta('legs', ExerciseType.isolation),
  'Сбор полотенца пальцами ног': ExerciseMeta('legs', ExerciseType.isolation),
  'Разгибание и сгибание пальцев ног': ExerciseMeta('legs', ExerciseType.isolation),
  'Подъём на носки с акцентом на большой палец': ExerciseMeta('legs', ExerciseType.isolation),
  'Балансировка на одной ноге': ExerciseMeta('legs', ExerciseType.isolation),
  'Ходьба на внешней стороне стопы': ExerciseMeta('legs', ExerciseType.isolation),
  'Мячик под стопой (ролл)': ExerciseMeta('legs', ExerciseType.isolation),
  'Разгибание одной ноги в тренажёре': ExerciseMeta('legs', ExerciseType.isolation),
  'Сгибание одной ноги в тренажёре': ExerciseMeta('legs', ExerciseType.isolation),
  'Подъем на носки с резинкой': ExerciseMeta('legs', ExerciseType.isolation),

  // ═══ ПРЕСС ═══
  'Скручивания': ExerciseMeta('abs', ExerciseType.base),
  'Обратные скручивания': ExerciseMeta('abs', ExerciseType.base),
  'Планка': ExerciseMeta('abs', ExerciseType.base),
  'Боковая планка': ExerciseMeta('abs', ExerciseType.base),
  'Велосипед': ExerciseMeta('abs', ExerciseType.isolation),
  'Подъём ног лёжа': ExerciseMeta('abs', ExerciseType.base),
  'Складной нож': ExerciseMeta('abs', ExerciseType.isolation),
  'Русский твист': ExerciseMeta('abs', ExerciseType.base),
  'Боковые скручивания': ExerciseMeta('abs', ExerciseType.isolation),
  'Наклоны в сторону с гантелью': ExerciseMeta('abs', ExerciseType.isolation),
  'Повороты корпуса с гантелью': ExerciseMeta('abs', ExerciseType.isolation),
  'Подъём ног в висе': ExerciseMeta('abs', ExerciseType.isolation),
  'Подъём ног в висе на турнике (согнутые)': ExerciseMeta('abs', ExerciseType.isolation),
  'Скручивания с резинкой': ExerciseMeta('abs', ExerciseType.isolation),
  'Планка с подъемом руки': ExerciseMeta('abs', ExerciseType.isolation),
  'Обратные скручивания с мячом': ExerciseMeta('abs', ExerciseType.isolation),
  'Боковая планка с подъемом таза': ExerciseMeta('abs', ExerciseType.isolation),
  'Dead Bug': ExerciseMeta('abs', ExerciseType.isolation),
  'Bird Dog': ExerciseMeta('abs', ExerciseType.isolation),
  'Вакуум живота': ExerciseMeta('abs', ExerciseType.isolation),

  // ═══ РУКИ ═══
  'Подъём гантелей на бицепс': ExerciseMeta('arms', ExerciseType.base),
  'Подъём штанги на бицепс': ExerciseMeta('arms', ExerciseType.base),
  'Отжимания узким хватом': ExerciseMeta('arms', ExerciseType.base),
  'Французский жим лёжа': ExerciseMeta('arms', ExerciseType.base),
  'Жим штанги узким хватом': ExerciseMeta('arms', ExerciseType.base),
  'Молотковые сгибания': ExerciseMeta('arms', ExerciseType.isolation),
  'Концентрированный подъём': ExerciseMeta('arms', ExerciseType.isolation),
  'Разгибание руки из-за головы': ExerciseMeta('arms', ExerciseType.isolation),
  'Разгибание руки в наклоне': ExerciseMeta('arms', ExerciseType.isolation),
  'Разгибание рук на блоке': ExerciseMeta('arms', ExerciseType.isolation),
  'Подъем на бицепс на скамье Скотта': ExerciseMeta('arms', ExerciseType.isolation),
  'Разгибание рук на блоке с канатом': ExerciseMeta('arms', ExerciseType.isolation),
  'Отжимания от скамьи (трицепс)': ExerciseMeta('arms', ExerciseType.isolation),
  'Сгибание рук в тренажере (на бицепс)': ExerciseMeta('arms', ExerciseType.isolation),
  'Разгибание рук в тренажере (на трицепс)': ExerciseMeta('arms', ExerciseType.isolation),
  'Подъем на бицепс на нижнем блоке': ExerciseMeta('arms', ExerciseType.isolation),

  // ═══ ПЛЕЧИ ═══
  'Жим гантелей сидя': ExerciseMeta('shoulders', ExerciseType.base),
  'Жим штанги стоя': ExerciseMeta('shoulders', ExerciseType.base),
  'Тяга штанги к подбородку': ExerciseMeta('shoulders', ExerciseType.base),
  'Жим Арнольда': ExerciseMeta('shoulders', ExerciseType.base),
  'Жим гантелей в тренажёре Смита': ExerciseMeta('shoulders', ExerciseType.base),
  'Жим в тренажере на плечи': ExerciseMeta('shoulders', ExerciseType.base),
  'Разведения гантелей в стороны': ExerciseMeta('shoulders', ExerciseType.isolation),
  'Махи гантелями перед собой': ExerciseMeta('shoulders', ExerciseType.isolation),
  'Разведения в наклоне (задняя дельта)': ExerciseMeta('shoulders', ExerciseType.isolation),
  'Махи гантелью в наклоне (задняя дельта)': ExerciseMeta('shoulders', ExerciseType.isolation),
  'Тяга гантелей к подбородку': ExerciseMeta('shoulders', ExerciseType.isolation),
  'Обратные разведения в наклоне на скамье': ExerciseMeta('shoulders', ExerciseType.isolation),
  'Махи гантелями в стороны сидя': ExerciseMeta('shoulders', ExerciseType.isolation),
  'Разведения гантелей на заднюю дельту (лёжа на животе)': ExerciseMeta('shoulders', ExerciseType.isolation),
  'Тяга резинки к лицу': ExerciseMeta('shoulders', ExerciseType.isolation),
  'Обратная бабочка': ExerciseMeta('shoulders', ExerciseType.isolation),
  'Махи в сторону на нижнем блоке': ExerciseMeta('shoulders', ExerciseType.isolation),

  // ═══ СПИНА ═══
  'Шраги с гантелями': ExerciseMeta('back', ExerciseType.base),
  'Шраги со штангой': ExerciseMeta('back', ExerciseType.base),
  'Подтягивания': ExerciseMeta('back', ExerciseType.base),
  'Тяга верхнего блока': ExerciseMeta('back', ExerciseType.base),
  'Тяга штанги в наклоне': ExerciseMeta('back', ExerciseType.base),
  'Тяга нижнего блока к поясу': ExerciseMeta('back', ExerciseType.base),
  'Тяга Т-грифа': ExerciseMeta('back', ExerciseType.base),
  'Тяга штанги в наклоне обратным хватом': ExerciseMeta('back', ExerciseType.isolation),
  'Разведения в наклоне на трапеции': ExerciseMeta('back', ExerciseType.isolation),
  'Тяга гантели одной рукой': ExerciseMeta('back', ExerciseType.isolation),
  'Тяга гантели к поясу (в наклоне)': ExerciseMeta('back', ExerciseType.isolation),
  'Тяга резинки к поясу': ExerciseMeta('back', ExerciseType.isolation),
  'Пуловер с гантелью': ExerciseMeta('back', ExerciseType.isolation),
  'Пулловер на верхнем блоке': ExerciseMeta('back', ExerciseType.isolation),
  'Лодочка': ExerciseMeta('back', ExerciseType.isolation),

  // ═══ ГРУДЬ ═══
  'Жим штанги лёжа': ExerciseMeta('chest', ExerciseType.base),
  'Жим гантелей лёжа': ExerciseMeta('chest', ExerciseType.base),
  'Отжимания от пола': ExerciseMeta('chest', ExerciseType.base),
  'Жим штанги на наклонной скамье': ExerciseMeta('chest', ExerciseType.base),
  'Жим в тренажере (Chest Press)': ExerciseMeta('chest', ExerciseType.base),
  'Отжимания на брусьях (акцент на грудь)': ExerciseMeta('chest', ExerciseType.base),
  'Жим штанги лежа в Смите': ExerciseMeta('chest', ExerciseType.base),
  'Разведения гантелей лёжа': ExerciseMeta('chest', ExerciseType.isolation),
  'Сведение рук в тренажёре': ExerciseMeta('chest', ExerciseType.isolation),
  'Жим гантелей лёжа на наклонной скамье': ExerciseMeta('chest', ExerciseType.isolation),
  'Отжимания от скамьи (обратные)': ExerciseMeta('chest', ExerciseType.isolation),
  'Сведение рук в кроссовере': ExerciseMeta('chest', ExerciseType.isolation),
  'Разведение гантелей лёжа на наклонной скамье': ExerciseMeta('chest', ExerciseType.isolation),
  'Отжимания с широкой постановкой': ExerciseMeta('chest', ExerciseType.isolation),
  'Жим гантелей сидя (для верха груди)': ExerciseMeta('chest', ExerciseType.isolation),
};

ExerciseMeta? _lookupMeta(String name) {
  final lower = name.toLowerCase().trim();
  for (final entry in kAbsoluteExerciseDictionary.entries) {
    if (entry.key.toLowerCase() == lower) return entry.value;
  }
  return null;
}

String getExerciseZone(Exercise ex) {
  final meta = _lookupMeta(ex.name);
  if (meta != null) return meta.zone;

  final g = ex.muscleGroups;
  if (g.contains('glutes')) return 'glutes';
  if (g.contains('quads') || g.contains('hamstrings') || g.contains('calves') || g.contains('feet') || g.contains('adductors')) return 'legs';
  if (g.contains('lower_back')) return 'back';
  if (g.contains('chest')) return 'chest';
  if (g.contains('back') || g.contains('lats') || g.contains('traps')) return 'back';
  if (g.contains('abs') || g.contains('core') || g.contains('obliques')) return 'abs';
  if (g.contains('shoulders') || g.contains('rotator_cuff')) return 'shoulders';
  if (g.contains('biceps') || g.contains('triceps') || g.contains('forearms') || g.contains('arms')) return 'arms';
  if (g.contains('cardio')) return 'cardio';
  return 'other';
}

bool isBaseExercise(Exercise ex) {
  final meta = _lookupMeta(ex.name);
  return meta?.type == ExerciseType.base;
}

String getZoneLabel(String zoneCode) {
  const map = {
    'glutes': 'Ягодицы', 'legs': 'Ноги', 'abs': 'Пресс', 'chest': 'Грудь',
    'back': 'Спина', 'arms': 'Руки', 'shoulders': 'Плечи', 'cardio': 'Кардио', 'other': 'Прочее',
    'quads': 'Квадрицепс', 'hamstrings': 'Бицепс бедра', 'calves': 'Голень', 'feet': 'Стопы',
    'adductors': 'Приводящие', 'lower_back': 'Поясница', 'lats': 'Широчайшие', 'traps': 'Трапеции',
    'biceps': 'Бицепс', 'triceps': 'Трицепс', 'forearms': 'Предплечья', 'core': 'Кор', 'obliques': 'Косые',
    'full_body': 'Всё тело', 'rotator_cuff': 'Манжета плеча',
  };
  return map[zoneCode] ?? zoneCode;
}

// ═══════════════════════════════════════════════════════════════
//  СЕМЕЙСТВА УПРАЖНЕНИЙ (ДЛЯ ЗАЩИТЫ ОТ ДУБЛИКАТОВ)
// ═══════════════════════════════════════════════════════════════
String getExerciseFamily(String name) {
  final lower = name.toLowerCase();

  // Ягодицы: Мосты
  if (lower.contains('ягодичный мост') || lower.contains('хип-траст') || lower.contains('hip thrust') || lower.contains('фрог-памп')) return 'glute_bridge';
  // Ягодицы: Отведения назад
  // 👈 ФИКС 12: «отведение ноги в кроссовере» перенесено в боковые отведения —
  // без «назад» это боковое отведение ноги на блоке, а не разгибание бедра.
  // Иначе кроссовер и «Отведение ноги в сторону с резинкой» считались
  // разными семействами и обе изоляции попадали в один день.
  if (lower.contains('отведение ноги назад') || lower.contains('тяга ноги назад') || lower.contains('махи ногой назад')) return 'hip_extension_back';
  // Ягодицы: Отведения в сторону
  // 👈 ИСПРАВЛЕНО: добавлена Ходьба с резинкой (Monster Walk) — это те же отведения бедра
  // 👈 ФИКС 12: добавлено «отведение ноги в кроссовере»
  if (lower.contains('отведение ноги в сторону') || lower.contains('отведение ноги в кроссовере') || lower.contains('разведение ног') || lower.contains('разгибание бедра') || lower.contains('махи ногой в сторону') || lower.contains('отведение ноги лежа') || lower.contains('ходьба с резинкой')) return 'hip_abduction_side';

  // Новые ягодичные
  if (lower.contains('реверанс')) return 'curtsy_lunge';
  if (lower.contains('зашагивания')) return 'step_up';
  if (lower.contains('румынская тяга на одной ноге')) return 'single_leg_hinge';

  // Ноги: Разгибание
  if (lower.contains('разгибание ног') || lower.contains('разгибание одной ноги')) return 'leg_extension';
  // Ноги: Сгибание
  if (lower.contains('сгибание ног') || lower.contains('сгибание одной ноги')) return 'leg_curl';
  // сведение ног (приводящие) — раньше уходило в «свободное плавание»
  if (lower.contains('сведение ног')) return 'adduction';
  // Голень: Подъёмы на носки
  if (lower.contains('носки') || lower.contains('жим носками')) return 'calf_raise';
  // Ноги: Приседания и Жим ногами (включая новые)
  if (lower.contains('приседания') || lower.contains('жим ногами') || lower.contains('гакк-приседания')) return 'squat';
  // Ноги: Выпады
  if (lower.contains('выпады') || lower.contains('болгарский')) return 'lunge';
  // Ноги: Румынская тяга и наклоны
  if (lower.contains('румынская тяга') || lower.contains('наклоны со штангой')) return 'hinge';

  // Спина: Тяги горизонтальные (включая Т-гриф; исключаем тягу к подбородку — это плечи)
  if ((lower.contains('тяга штанги в наклоне') || lower.contains('тяга гантели') || lower.contains('тяга нижнего блока') || lower.contains('тяга резинки к поясу') || lower.contains('тяга т-грифа')) && !lower.contains('подбородку')) return 'back_row_horizontal';

  // Спина: Тяги вертикальные
  if (lower.contains('подтягивания') || lower.contains('тяга верхнего блока')) return 'back_row_vertical';
  // Спина: Шраги
  if (lower.contains('шраги') || lower.contains('разведения в наклоне на трапеции')) return 'shrug';
  // Спина: Поясница
  if (lower.contains('гиперэкстензия') || lower.contains('лодочка')) return 'lower_back';
  // Спина: Пулловеры
  if (lower.contains('пуловер') || lower.contains('пулловер')) return 'pullover';

  // Грудь: Жимы (включая тренажеры и Смит)
  if (lower.contains('жим штанги') || lower.contains('жим гантелей') || lower.contains('жим в тренажере') || lower.contains('жим в тренажёре')) return 'bench_press';
  // Грудь: Разведения/Сведения

  // ИСПРАВЛЕНО: раньше правило ловило плечевые «Разведения гантелей в стороны»
  // и «на заднюю дельту», а также «Обратную бабочку» — теперь исключены
  if (lower.contains('сведение рук') ||
      (lower.contains('бабочка') && !lower.contains('обратная бабочка')) ||
      ((lower.contains('разведения гантелей') || lower.contains('разведение гантелей')) &&
          !lower.contains('в стороны') && !lower.contains('заднюю дельту'))) return 'chest_fly';
  // Грудь: Отжимания (включая брусья)
  if (lower.contains('отжимания')) return 'pushup';

  // Плечи: Жимы (включая тренажеры)
  if (lower.contains('жим гантелей сидя') || lower.contains('жим штанги стоя') || lower.contains('жим арнольда') || lower.contains('жим гантелей в тренажёре') || lower.contains('жим в тренажере на плечи')) return 'shoulder_press';
  // Плечи: Средняя дельта (включая блоки)
  if (lower.contains('разведения гантелей в стороны') || lower.contains('махи гантелями в стороны сидя') || lower.contains('махи в сторону на нижнем блоке')) return 'shoulder_side';
  // Плечи: Передняя дельта
  if (lower.contains('махи гантелями перед собой')) return 'shoulder_front';
  // Плечи: Задняя дельта (включая обратную бабочку)
  if (lower.contains('разведения в наклоне') || lower.contains('махи гантелью в наклоне') || lower.contains('обратные разведения') || lower.contains('разведения гантелей на заднюю дельту') || lower.contains('тяга резинки к лицу') || lower.contains('обратная бабочка')) return 'shoulder_rear';
  // Плечи: Тяга к подбородку
  if (lower.contains('тяга штанги к подбородку') || lower.contains('тяга гантелей к подбородку')) return 'upright_row';

  // Руки: Бицепс (включая тренажеры и блоки)
  if (lower.contains('подъём гантелей на бицепс') || lower.contains('подъём штанги на бицепс') || lower.contains('молотковые сгибания') || lower.contains('концентрированный подъём') || lower.contains('подъем на бицепс') || lower.contains('сгибание рук в тренажере')) return 'bicep_curl';
  // Руки: Трицепс (включая тренажеры и жим узким хватом)
  if (lower.contains('французский жим') || lower.contains('разгибание руки') || lower.contains('разгибание рук на блоке') || lower.contains('отжимания от скамьи (трицепс)') || lower.contains('отжимания узким хватом') || lower.contains('жим штанги узким хватом') || lower.contains('разгибание рук в тренажере')) return 'tricep_extension';

  // Пресс: Планки
  if (lower.contains('планка')) return 'plank';
  // подъёмы ног — раньше «Подъём ног лёжа» и «Подъём ног в висе»
  // имели разные семейства и могли попасть в один день
  if (lower.contains('подъём ног') || lower.contains('подъем ног')) return 'leg_raise';
  // Пресс: Скручивания (стандартные)
  if (lower.contains('скручивания') && !lower.contains('боковые') && !lower.contains('обратные')) return 'crunch_standard';
  // Пресс: Обратные скручивания
  if (lower.contains('обратные скручивания')) return 'crunch_reverse';
  // Пресс: Косые
  if (lower.contains('боковые скручивания') || lower.contains('наклоны в сторону') || lower.contains('повороты корпуса') || lower.contains('русский твист')) return 'crunch_side';

  // Если ничего не подошло — уникальное семейство (по имени)
  return name.toLowerCase();
}

// ═══ РЕЖИМ ВЕСА ═══
// 0 — поле веса не нужно (статика, кардио, собственный вес),
// 1 — опционально (утяжелители, резинка, гиперэкстензия без веса),
// 2 — обязательно (снаряд или тренажёр).

const Set<String> _timedNames = {
  'Планка', 'Боковая планка', 'Планка с подъемом руки',
  'Боковая планка с подъемом таза',
  'Стульчик у стены', 'Балансировка на одной ноге',
  'Ходьба на внешней стороне стопы', 'Мячик под стопой (ролл)',
  'Сбор полотенца пальцами ног', 'Вакуум живота', 'Лодочка',
};

const Set<String> _optionalWeightNames = {
  'Махи ногой назад (на четвереньках)',
  'Махи ногой в сторону (на четвереньках)',
  'Отведение ноги в сторону стоя',
  'Отведение ноги лежа на боку',
  'Отведение ноги в сторону с резинкой', // 👈 ФИКС 12: резинка — вес опционален
  'Ходьба с резинкой (Monster Walk)',    // 👈 ФИКС 12: то же самое
  'Подъём ног лёжа',
  'Подъём ног в висе',
  'Подъём ног в висе на турнике (согнутые)',
};

const Set<String> _weightEquipment = {
  'barbell', 'dumbbells', 'machine', 'cable',
};

int weightModeFor(Exercise e) {
  final n = e.name.toLowerCase();
  if (_timedNames.contains(e.name)) return 0;
  const cardioWords = [
    'бег', 'дорожк', 'скакалк', 'велотренаж', 'эллипс', 'гребл',
    'степпер', 'кардио', 'берпи', 'скалолаз', 'джеки', 'канат',
    'бой с тенью',
  ];
  if (cardioWords.any(n.contains)) return 0;
  if (_optionalWeightNames.contains(e.name)) return 1;
  if (n.contains('гиперэкстензия') && !n.contains('с весом')) return 1;
  return e.equipment.any(_weightEquipment.contains) ? 2 : 0;
}

// ═══════════════════════════════════════════════════════════
//  ЕДИНАЯ КЛАССИФИКАЦИЯ (миграция v20)
// ═══════════════════════════════════════════════════════════
// Источник истины — данные в базе (exType / family / weightMode),
// их заполняет syncExercises(). Функции ниже сначала читают поле,
// а если оно пустое (своё упражнение или база до синхронизации) —
// работают прежние эвристики по названию.

/// Кардио или нет. Эвристика, общая для syncExercises и фолбэка.
/// Раньше эта логика жила в workout_generator.dart как _isCardio —
/// теперь здесь одна копия на всё приложение.
bool isCardioExercise(Exercise e) {
  final lower = e.name.toLowerCase();
  if (lower.contains('бег') ||
      lower.contains('дорожк') ||
      lower.contains('скакалк') ||
      lower.contains('эллипс') ||
      lower.contains('велотренаж') ||
      lower.contains('велоэргометр') ||
      lower.contains('гребл') ||
      lower.contains('степпер') ||
      lower.contains('кардио')) {
    return true;
  }
  if (lower.contains('скалолаз')) return true;
  if (lower.contains('канат') &&
      (lower.contains('махи') ||
          lower.contains('волны') ||
          lower.contains('бэтл'))) {
    return true;
  }
  const coreGroups = ['abs', 'core', 'obliques'];
  if (e.muscleGroups.any((m) => coreGroups.contains(m))) return false;
  return e.muscleGroups.contains('cardio');
}

/// Тип упражнения: из данных, иначе — эвристика.
/// 'base' | 'isolation' | 'cardio'
String typeOf(Exercise e) {
  if (e.exType != null) return e.exType!;
  if (isCardioExercise(e)) return 'cardio';
  return isBaseExercise(e) ? 'base' : 'isolation';
}

/// Кардио (обёртка над данными): сначала поле exType, потом эвристика.
bool isCardioOf(Exercise e) => typeOf(e) == 'cardio';

/// Семейство: из данных (family), иначе — по названию.
String familyOf(Exercise e) => e.family ?? getExerciseFamily(e.name);

/// Режим веса: из данных (weightMode), иначе — по названию.
int weightModeOf(Exercise e) => e.weightMode ?? weightModeFor(e);

// ═══════════════════════════════════════════════════════════
//  ПРОТИВОПОКАЗАНИЯ (миграция v21, фолбэк v21.2)
// ═══════════════════════════════════════════════════════════
// Коды — ровно те, что выбирает пользователь в профиле
// (profile_edit_screen): back, knees, shoulders, neck.
// Таблица — источник истины для syncExercises() (см. contraindicationsFor),
// а exerciseBlockedByLimitations сверяется с ней как фолбэком,
// пока синхронизация не прошла. 👇 v21.2: раньше фолбэк искал ключ
// по имени упражнения (kContraindications[e.name]) — а ключи здесь
// коды ограничений, так что фолбэк не срабатывал никогда.

const Map<String, List<String>> kContraindications = {
  // Колени: осевая и ударная нагрузка
  'knees': [
    'Приседания со штангой', 'Приседания с гантелями',
    'Приседания сумо', 'Приседания сумо с собственным весом',
    'Гакк-приседания (Hack Squat)', 'Приседания в тренажере Смита',
    'Выпады вперёд с гантелями', 'Выпады назад с гантелями',
    'Реверанс-выпад', 'Болгарский выпад',
    'Боковые выпады с гантелями', 'Боковые выпады с собственным весом',
    'Обратные выпады с собственным весом',
    'Зашагивания на платформу', 'Зашагивания на платформу с гантелями',
    'Стульчик у стены', 'Прыжки на тумбу', 'Скакалка',
    'Прыжки Джеки (Jumping Jacks)', 'Берпи',
    'Скалолаз (Mountain Climbers)',
    'Бег на месте с высоким подниманием колен',
  ],
  // Спина: осевая нагрузка и сгибание с весом.
  // Статика (планки, лодочка, Bird Dog) не блокируется — она спину укрепляет.
  'back': [
    'Приседания со штангой', 'Приседания в тренажере Смита',
    'Гакк-приседания (Hack Squat)', 'Наклоны со штангой',
    'Румынская тяга со штангой', 'Румынская тяга на одной ноге',
    'Румынская тяга на одной ноге с гантелью',
    'Тяга штанги в наклоне', 'Тяга штанги в наклоне обратным хватом',
    'Тяга Т-грифа (T-Bar Row)', 'Тяга гантели одной рукой',
    'Тяга гантели к поясу (в наклоне)', 'Гиперэкстензия с весом',
  ],
  // Плечи: жимы над головой, тяга к подбородку, брусья.
  // Махи и разведения не блокируются — дельты там не под нагрузкой сжатия.
  'shoulders': [
    'Жим гантелей сидя', 'Жим гантелей сидя (для верха груди)',
    'Жим штанги стоя', 'Жим Арнольда',
    'Жим гантелей в тренажёре Смита', 'Жим в тренажере на плечи (Shoulder Press)',
    'Тяга штанги к подбородку', 'Тяга гантелей к подбородку',
    'Отжимания на брусьях (акцент на грудь)',
    'Французский жим лёжа', 'Разгибание руки из-за головы',
    // 👇 правка 7: гребля нагружает передние дельты в каждом гребке,
    // а в muscleGroups плечей у неё нет — зональный фильтр её не видит.
    // Имя в базе ровно «Гребной тренажер» (с «е»).
    'Гребной тренажер',
  ],

  // Шея: прямых нагружателей шеи в каталоге нет — оставляем пустым,
  // ограничение пока ни на что не влияет (честнее фантомного фильтра).
  'neck': [],
};

/// Ограничение → зоны, которые не давать в бонусе «забытой зоны»
/// и в challenge-экранах. Раньше сюда сравнивались коды напрямую
/// с зонами — срабатывал только 'back', knees/neck/shoulders молчали.
const Map<String, List<String>> kLimitationZones = {
  'knees': ['legs', 'glutes'],
  'back': ['back', 'lower_back'],
  'shoulders': ['shoulders'],
  'neck': [],
};

/// 👇 v21.2: коды ограничений, блокирующие данное упражнение
/// (обратный lookup по таблице). Нужен syncExercises() для заполнения
/// поля contraindications в базе.
List<String> contraindicationsFor(String exerciseName) {
  final res = <String>[];
  kContraindications.forEach((code, names) {
    if (names.contains(exerciseName)) res.add(code);
  });
  return res;
}

/// Упражнение заблокировано ограничениями профиля?
/// 👇 v21.2: поле из базы + настоящий фолбэк в таблицу — для каждого
/// кода ограничения проверяем, есть ли имя упражнения в его списке.
/// Точное пересечение, без подстрок.
bool exerciseBlockedByLimitations(Exercise e, List<String> limitations) {
  if (limitations.isEmpty) return false;
  final blocked = limitations.map((l) => l.toLowerCase().trim()).toSet();
  // 1) поле из базы (после синка здесь лежат коды: knees, back...)
  final fieldCodes =
  e.contraindications.map((c) => c.toLowerCase().trim()).toSet();
  if (fieldCodes.any(blocked.contains)) return true;
  // 2) фолбэк в таблицу: имя упражнения в списке заблокированного кода
  for (final lim in blocked) {
    if (kContraindications[lim]?.contains(e.name) ?? false) return true;
  }
  return false;
}

/// Зоны, закрытые ограничениями (для бонуса и challenge-экранов).
List<String> zonesBlockedByLimitations(List<String> limitations) {
  final zones = <String>{};
  for (final lim in limitations) {
    zones.addAll(kLimitationZones[lim.toLowerCase().trim()] ?? const <String>[]);
  }
  return zones.toList();
}

// ═══ ЕДИНАЯ ПРОВЕРКА ДЛЯ ЭКРАНОВ (правка 8) ═══
// Расширение зоны → подзоны. Дубликат приватной _zoneExpand
// из workout_generator — позже генератор можно перевести на неё.
const Map<String, List<String>> kZoneExpand = {
  'legs': ['quads', 'hamstrings', 'legs', 'calves', 'feet'],
  'glutes': ['glutes', 'hamstrings'],
  'abs': ['abs', 'obliques', 'core'],
  'chest': ['chest'],
  'back': ['back', 'lats', 'traps', 'lower_back'],
  'arms': ['arms', 'biceps', 'triceps', 'forearms'],
  'shoulders': ['shoulders', 'traps'],
};

/// Упражнение нарушает ограничения профиля? Объединяет табличную
/// проверку (по имени из kContraindications) и зональную (по
/// muscleGroups). Один источник истины для replace-экрана —
/// генератор фильтрует ровно так же.
bool exerciseViolatesLimitations(Exercise e, List<String> limitations) {
  if (limitations.isEmpty) return false;
  if (exerciseBlockedByLimitations(e, limitations)) return true;
  final blockedZones = zonesBlockedByLimitations(limitations).toSet();
  for (final m in e.muscleGroups) {
    if (blockedZones.contains(m)) return true;
    for (final zone in blockedZones) {
      if ((kZoneExpand[zone] ?? const <String>[]).contains(m)) return true;
    }
  }
  return false;
}
