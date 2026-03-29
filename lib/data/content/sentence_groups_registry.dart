// lib/data/content/sentence_groups_registry.dart
// Combines all level sentence groups into a single list.

import 'sentence_groups_data.dart';
import 'sentence_groups_l1.dart';
import 'sentence_groups_l2.dart';
import 'sentence_groups_l3.dart';
import 'sentence_groups_l4.dart';
import 'sentence_groups_l5.dart';
import 'sentence_groups_l6.dart';

/// All 360 sentence groups across TOPIK levels 1–6.
/// Level 1: free (groups 1–60)
/// Levels 2–6: premium (groups 1–60 each)
const List<SentenceGroup> kAllSentenceGroups = [
  ...kLevel1Groups,
  ...kLevel2Groups,
  ...kLevel3Groups,
  ...kLevel4Groups,
  ...kLevel5Groups,
  ...kLevel6Groups,
];
