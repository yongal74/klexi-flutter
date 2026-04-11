// lib/data/content/grammar/grammar_patterns.dart
// Re-export convenience: exposes grammarPatterns list
export 'package:klexi_flutter/data/content/grammar/grammar_data.dart'
    show kGrammarData;

import 'package:klexi_flutter/data/models/grammar_pattern.dart';
import 'grammar_data.dart';

/// Public alias used by screens and tests.
List<GrammarPattern> get grammarPatterns => kGrammarData;
