// lib/data/content/sentence_groups_data.dart
// Pre-generated practice sentence groups — 20 words × 360 groups across TOPIK L1–L6.
// Each group has 4 natural Korean sentences incorporating vocabulary from that group.

class PracticeSentence {
  final String korean;
  final String english;
  final List<String> highlights; // Korean vocab words to highlight in the sentence

  const PracticeSentence({
    required this.korean,
    required this.english,
    required this.highlights,
  });
}

class SentenceGroup {
  final String groupId;     // e.g. 'L1G1'
  final int level;          // 1–6
  final int groupIndex;     // 1–60
  final List<String> wordIds;     // 20 word IDs in this group
  final List<PracticeSentence> sentences; // 4 practice sentences

  const SentenceGroup({
    required this.groupId,
    required this.level,
    required this.groupIndex,
    required this.wordIds,
    required this.sentences,
  });
}

// ── Combined list of all sentence groups (populated from level files) ─────────
// Assembled in sentence_groups_registry.dart
