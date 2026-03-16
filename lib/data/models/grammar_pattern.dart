// lib/data/models/grammar_pattern.dart

class GrammarExample {
  final String korean;
  final String english;
  final String highlight;
  const GrammarExample({
    required this.korean,
    required this.english,
    required this.highlight,
  });
}

class GrammarPattern {
  final String id;
  final int level;
  final String title;
  final String titleRomanized;
  final String meaning;
  final String explanation;
  final String structure;
  final List<GrammarExample> examples;
  final String tips;
  final String category;
  const GrammarPattern({
    required this.id,
    required this.level,
    required this.title,
    required this.titleRomanized,
    required this.meaning,
    required this.explanation,
    required this.structure,
    required this.examples,
    required this.tips,
    required this.category,
  });
}
