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
  'Отведение ноги назад в блоке': ExerciseMeta('glutes', ExerciseType.isolation),
  'Отведение ноги в сторону с резинкой': ExerciseMeta('glutes', ExerciseType.isolation),
  'Отведение ноги в кроссовере': ExerciseMeta('glutes', ExerciseType.isolation),
  'Разведение ног в тренажёре': ExerciseMeta('glutes', ExerciseType.isolation),
  'Ягодичный мост на одной ноге': ExerciseMeta('glutes', ExerciseType.isolation),
  'Махи ногой назад (на четвереньках)': ExerciseMeta('glutes', ExerciseType.isolation),
  'Махи ногой в сторону (на четвереньках)': ExerciseMeta('glutes', ExerciseType.isolation),
  'Отведение ноги лежа на боку': ExerciseMeta('glutes', ExerciseType.isolation),
  'Ягодичный мост с резинкой (лёжа)': ExerciseMeta('glutes', ExerciseType.isolation),
  'Ходьба с резинкой (Monster Walk)': ExerciseMeta('glutes', ExerciseType.isolation),
  'Разгибание бедра в тренажёре': ExerciseMeta('glutes', ExerciseType.isolation),
  'Тяга ноги назад с нижнего блока': ExerciseMeta('glutes', ExerciseType.isolation),

  // ═══ НОГИ ═══
  'Приседания со штангой': ExerciseMeta('legs', ExerciseType.base),
  'Приседания с гантелями': ExerciseMeta('legs', ExerciseType.base),
  'Приседания сумо': ExerciseMeta('legs', ExerciseType.base),
  'Выпады вперёд с гантелями': ExerciseMeta('legs', ExerciseType.base),
  'Болгарский выпад': ExerciseMeta('legs', ExerciseType.base),
  'Зашагивания на платформу': ExerciseMeta('legs', ExerciseType.base),
  'Приседания на одной ноге': ExerciseMeta('legs', ExerciseType.base),
  'Боковые выпады': ExerciseMeta('legs', ExerciseType.base),
  'Жим ногами в тренажёре': ExerciseMeta('legs', ExerciseType.base),
  'Румынская тяга со штангой': ExerciseMeta('legs', ExerciseType.base),
  'Румынская тяга на одной ноге': ExerciseMeta('legs', ExerciseType.base),
  'Наклоны со штангой': ExerciseMeta('legs', ExerciseType.base),
  'Выпады назад с гантелями': ExerciseMeta('legs', ExerciseType.base),
  'Подъёмы на носки стоя': ExerciseMeta('legs', ExerciseType.base),
  'Подъёмы на носки сидя': ExerciseMeta('legs', ExerciseType.base),
  'Подъемы на носки в тренажере Смита': ExerciseMeta('legs', ExerciseType.base),
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
  'Молотковые сгибания': ExerciseMeta('arms', ExerciseType.isolation),
  'Концентрированный подъём': ExerciseMeta('arms', ExerciseType.isolation),
  'Разгибание руки из-за головы': ExerciseMeta('arms', ExerciseType.isolation),
  'Разгибание руки в наклоне': ExerciseMeta('arms', ExerciseType.isolation),
  'Разгибание рук на блоке': ExerciseMeta('arms', ExerciseType.isolation),
  'Подъем на бицепс на скамье Скотта': ExerciseMeta('arms', ExerciseType.isolation),
  'Разгибание рук на блоке с канатом': ExerciseMeta('arms', ExerciseType.isolation),
  'Отжимания от скамьи (трицепс)': ExerciseMeta('arms', ExerciseType.isolation),

  // ═══ ПЛЕЧИ ═══
  'Жим гантелей сидя': ExerciseMeta('shoulders', ExerciseType.base),
  'Жим штанги стоя': ExerciseMeta('shoulders', ExerciseType.base),
  'Тяга штанги к подбородку': ExerciseMeta('shoulders', ExerciseType.base),
  'Жим Арнольда': ExerciseMeta('shoulders', ExerciseType.base),
  'Жим гантелей в тренажёре Смита': ExerciseMeta('shoulders', ExerciseType.base),
  'Разведения гантелей в стороны': ExerciseMeta('shoulders', ExerciseType.isolation),
  'Махи гантелями перед собой': ExerciseMeta('shoulders', ExerciseType.isolation),
  'Разведения в наклоне (задняя дельта)': ExerciseMeta('shoulders', ExerciseType.isolation),
  'Махи гантелью в наклоне (задняя дельта)': ExerciseMeta('shoulders', ExerciseType.isolation),
  'Тяга гантелей к подбородку': ExerciseMeta('shoulders', ExerciseType.isolation),
  'Обратные разведения в наклоне на скамье': ExerciseMeta('shoulders', ExerciseType.isolation),
  'Махи гантелями в стороны сидя': ExerciseMeta('shoulders', ExerciseType.isolation),
  'Разведения гантелей на заднюю дельту (лёжа на животе)': ExerciseMeta('shoulders', ExerciseType.isolation),
  'Тяга резинки к лицу': ExerciseMeta('shoulders', ExerciseType.isolation),

  // ═══ СПИНА ═══
  'Шраги с гантелями': ExerciseMeta('back', ExerciseType.base),
  'Шраги со штангой': ExerciseMeta('back', ExerciseType.base),
  'Подтягивания': ExerciseMeta('back', ExerciseType.base),
  'Тяга верхнего блока': ExerciseMeta('back', ExerciseType.base),
  'Тяга штанги в наклоне': ExerciseMeta('back', ExerciseType.base),
  'Тяга нижнего блока к поясу': ExerciseMeta('back', ExerciseType.base),
  'Тяга штанги в наклоне обратным хватом': ExerciseMeta('back', ExerciseType.isolation),
  'Разведения в наклоне на трапеции': ExerciseMeta('back', ExerciseType.isolation),
  'Тяга гантели одной рукой': ExerciseMeta('back', ExerciseType.isolation),
  'Тяга гантели к поясу (в наклоне)': ExerciseMeta('back', ExerciseType.isolation),
  'Тяга резинки к поясу': ExerciseMeta('back', ExerciseType.isolation),
  'Пуловер с гантелью': ExerciseMeta('back', ExerciseType.isolation),
  'Лодочка': ExerciseMeta('back', ExerciseType.isolation),

  // ═══ ГРУДЬ ═══
  'Жим штанги лёжа': ExerciseMeta('chest', ExerciseType.base),
  'Жим гантелей лёжа': ExerciseMeta('chest', ExerciseType.base),
  'Отжимания от пола': ExerciseMeta('chest', ExerciseType.base),
  'Жим штанги на наклонной скамье': ExerciseMeta('chest', ExerciseType.base),
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