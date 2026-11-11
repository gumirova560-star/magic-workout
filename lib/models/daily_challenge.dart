class DailyChallenge {
  int? id;
  int profileId;
  String date; // 'YYYY-MM-DD'
  String challengeType; // 'cumulative', 'hold', 'timer', 'circuit', 'photo'
  String taskId;
  int currentProgress;
  int targetValue;
  bool isCompleted;
  String? proofImagePath;

  DailyChallenge({
    this.id,
    required this.profileId,
    required this.date,
    required this.challengeType,
    required this.taskId,
    this.currentProgress = 0,
    required this.targetValue,
    this.isCompleted = false,
    this.proofImagePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'date': date,
      'challengeType': challengeType,
      'taskId': taskId,
      'currentProgress': currentProgress,
      'targetValue': targetValue,
      'isCompleted': isCompleted ? 1 : 0,
      'proofImagePath': proofImagePath,
    };
  }

  factory DailyChallenge.fromMap(Map<String, dynamic> map) {
    return DailyChallenge(
      id: map['id'],
      profileId: map['profileId'] ?? 0,
      date: map['date'] ?? '',
      challengeType: map['challengeType'] ?? '',
      taskId: map['taskId'] ?? '',
      currentProgress: map['currentProgress'] ?? 0,
      targetValue: map['targetValue'] ?? 0,
      isCompleted: map['isCompleted'] == 1,
      proofImagePath: map['proofImagePath'],
    );
  }
}