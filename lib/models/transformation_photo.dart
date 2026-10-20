class TransformationPhoto {
  int? id;
  int profileId;
  String imagePath;
  int monthNumber;
  String angle; // 'front' | 'side' | 'back'
  DateTime createdAt;

  TransformationPhoto({
    this.id,
    required this.profileId,
    required this.imagePath,
    required this.monthNumber,
    this.angle = 'front',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'imagePath': imagePath,
      'monthNumber': monthNumber,
      'angle': angle,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TransformationPhoto.fromMap(Map<String, dynamic> map) {
    return TransformationPhoto(
      id: map['id'],
      profileId: map['profileId'] ?? 0,
      imagePath: map['imagePath'] ?? '',
      monthNumber: map['monthNumber'] ?? 1,
      angle: map['angle'] ?? 'front',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }
}