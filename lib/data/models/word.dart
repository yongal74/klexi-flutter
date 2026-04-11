import 'package:hive_flutter/hive_flutter.dart';

part 'word.g.dart';

@HiveType(typeId: 0)
class Word extends HiveObject {
  @HiveField(0) final String id;
  @HiveField(1) final String korean;
  @HiveField(2) final String english;
  @HiveField(3) final int level;           // TOPIK 레벨 1~6
  @HiveField(4) final String partOfSpeech;
  @HiveField(5) final String example;
  @HiveField(6) final String exampleTranslation;
  @HiveField(7) final String pronunciation; // e.g. "sa-rang"
  @HiveField(8) final String category;      // e.g. "Greetings & Manners"
  @HiveField(9) final List<String> relatedIds; // Word Network 연결

  Word({
    required this.id,
    required this.korean,
    required this.english,
    required this.level,
    required this.partOfSpeech,
    required this.example,
    required this.exampleTranslation,
    this.pronunciation = '',
    this.category = '',
    this.relatedIds = const [],
  });

  Word copyWith({
    String? id,
    String? korean,
    String? english,
    int? level,
    String? partOfSpeech,
    String? example,
    String? exampleTranslation,
    String? pronunciation,
    String? category,
    List<String>? relatedIds,
  }) =>
      Word(
        id: id ?? this.id,
        korean: korean ?? this.korean,
        english: english ?? this.english,
        level: level ?? this.level,
        partOfSpeech: partOfSpeech ?? this.partOfSpeech,
        example: example ?? this.example,
        exampleTranslation: exampleTranslation ?? this.exampleTranslation,
        pronunciation: pronunciation ?? this.pronunciation,
        category: category ?? this.category,
        relatedIds: relatedIds ?? this.relatedIds,
      );

  factory Word.fromJson(Map<String, dynamic> json) => Word(
    id: json['id'] as String,
    korean: json['korean'] as String,
    english: json['english'] as String,
    level: (json['level'] as num?)?.toInt() ?? 1,
    partOfSpeech: json['partOfSpeech'] as String,
    example: json['example'] as String,
    exampleTranslation: json['exampleTranslation'] as String,
    pronunciation: json['pronunciation'] as String? ?? '',
    category: json['category'] as String? ?? '',
    relatedIds: List<String>.from(json['relatedIds'] as List? ?? []),
  );
}
