# ADR-008: WordRepository — Singleton Caching Strategy

**Date:** 2026-04-11 (build48)
**Status:** Accepted
**Deciders:** Klexi dev team

---

## Context

`WordRepository` is a singleton holding all 7,200 vocabulary words loaded at startup. Several methods were recomputing results on every call:

| Method | Pre-build48 | Cost |
|---|---|---|
| `getWordsByLevel(int)` | `_all.where(...).toList()` | O(7200) per call |
| `categories` getter | `_all.map(...).toSet().toList()..sort()` | O(7200) per call |
| `buildRelatedIdsMap()` | Full map rebuild from `relatedWordsMap` | O(n²) per call |

**Hot paths:**
- `LearnScreen` called `getWordsByLevel(lvl).length` for all 6 levels on every build → 43,200 iterations per rebuild.
- `WordNetworkScreen` called `buildRelatedIdsMap()` on every open.

Additionally, `buildRelatedIdsMap()` had a bug: bidirectional entries were appended with `List.add()` without checking for duplicates, potentially creating duplicate relationship edges.

## Decision

Add static caches to `WordRepository`:

```dart
static final Map<int, List<Word>> _levelCache = {};
static List<String>? _categoriesCache;
static Map<String, List<String>>? _relatedIdsCache;
```

**getWordsByLevel():**
```dart
List<Word> getWordsByLevel(int level) =>
    _levelCache[level] ??= _all.where((w) => w.level == level).toList();
```

**categories:**
```dart
List<String> get categories =>
    _categoriesCache ??= (_all.map((w) => w.category).toSet().toList()..sort());
```

**buildRelatedIdsMap() — bug fix + cache:**
```dart
// Use Set<String> for deduplication, convert to List at end
final result = <String, Set<String>>{};
// ... build bidirectional map with Set (no duplicates) ...
_relatedIdsCache = result.map((k, v) => MapEntry(k, v.toList()));
return _relatedIdsCache!;
```

### Why static caches?

`WordRepository` is a singleton (`WordRepository.instance`) and the vocabulary data never changes at runtime. Static fields on the singleton class ensure caches persist for the full app lifetime without needing a separate cache layer.

## Consequences

- **Positive**: `getWordsByLevel()` is O(1) after first call for each level — critical for LearnScreen performance.
- **Positive**: `buildRelatedIdsMap()` computed once per app session (was re-built on every WordNetwork open).
- **Positive**: Duplicate relationship edges eliminated — WordNetwork graph is now accurate.
- **Negative**: Slightly higher memory footprint (cached lists held in memory). At 7,200 words across 6 levels, this is negligible (~300KB).
- **Watch**: If vocabulary data ever becomes dynamic (user-uploaded words, server-synced content), the static caches must be invalidated explicitly.
