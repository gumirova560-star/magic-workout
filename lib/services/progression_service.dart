import '../models/workout_day.dart';

class ProgressionService {
  static String getRecommendation({
    required String exerciseName,
    required List<WorkoutSet> lastSets,
    required int currentReps,
    required double currentWeight,
    required String goal,
    required int targetReps,
  }) {
    // 1. История прошлых тренировок — берём ПОСЛЕДНИЙ подход
    if (lastSets.isNotEmpty) {
      final lastSet = lastSets.last;
      final lastWeight = lastSet.weight ?? 0;
      final lastReps = lastSet.reps ?? 0;

      if (lastWeight == 0) {
        if (lastReps >= targetReps) {
          return 'В прошлый раз ты сделал $lastReps повт. Отличный результат, продолжай в том же духе!';
        }
        return 'В прошлый раз ты сделал $lastReps повт. Твоя цель: $targetReps.';
      }

      switch (goal) {
        case 'strength':
          if (lastReps >= targetReps && lastReps < 8) {
            return 'Ты сделал $lastReps повт. по ${lastWeight}кг. Отличная работа! Попробуй добавить 2.5 кг.';
          } else if (lastReps >= 8) {
            return 'Ты сделал $lastReps повт. по ${lastWeight}кг. Пора добавить 5 кг!';
          }
          return 'Сфокусируйся на технике и силе. Вес: $lastWeight кг.';
        case 'gain_mass':
        case 'tone':
        case 'lose_weight':
        default:
          if (lastReps >= 12) {
            return 'В прошлый раз ты сделал $lastReps повт. по ${lastWeight}кг. Отличный результат!';
          } else if (lastReps < 8) {
            return 'Ты сделал $lastReps повт. Вес тяжеловат. Оставь $lastWeight кг или добавь 1 повторение.';
          }
          return 'Отличная работа: $lastReps повт. по ${lastWeight}кг.';
      }
    }

    // 2. Истории нет, но есть текущий результат
    if (currentReps > 0) {
      if (currentReps < targetReps) {
        return 'Ты сделал $currentReps из $targetReps. На следующем подходе попробуй сделать еще ${targetReps - currentReps} повторений.';
      } else if (currentWeight == 0) {
        return 'Ты сделал $currentReps повт. Отлично! Продолжай в том же духе.';
      } else {
        return 'Ты сделал $currentReps повт. по ${currentWeight.toStringAsFixed(1)}кг. План выполнен!';
      }
    }

    // 3. Первое выполнение
    return 'Это первое выполнение упражнения. Начни с комфортного веса, чтобы отработать технику.';
  }
}