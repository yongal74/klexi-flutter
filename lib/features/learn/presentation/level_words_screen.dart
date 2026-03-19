// lib/features/learn/presentation/level_words_screen.dart
// Browse all words for a specific TOPIK level + start a level session

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/purchase_service.dart';
import '../../../core/utils/tts_service.dart';
import '../../../data/models/word.dart';
import '../../../data/repositories/word_repository.dart';

class LevelWordsScreen extends ConsumerStatefulWidget {
  final int level;
  const LevelWordsScreen({super.key, required this.level});

  @override
  ConsumerState<LevelWordsScreen> createState() => _LevelWordsScreenState();
}

class _LevelWordsScreenState extends ConsumerState<LevelWordsScreen> {
  List<Word> _words = [];
  List<Word> _filtered = [];
  final _searchCtrl = TextEditingController();
  String _sortBy = 'default'; // 'default' | 'alpha' | 'pos'

  static const _levelNames = {
    1: 'Beginner',
    2: 'Elementary',
    3: 'Intermediate',
    4: 'Upper-Intermediate',
    5: 'Advanced',
    6: 'Master',
  };

  static const _levelDesc = {
    1: 'Basic greetings, numbers, everyday essentials',
    2: 'Simple conversations, common vocabulary',
    3: 'Everyday topics, news, social situations',
    4: 'Complex topics, formal language, workplace',
    5: 'Academic & professional Korean',
    6: 'Near-native fluency, nuanced expression',
  };

  @override
  void initState() {
    super.initState();
    final repo = ref.read(wordRepositoryProvider);
    _words = repo.getWordsByLevel(widget.level);
    _filtered = List.from(_words);
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.from(_words)
          : _words
              .where((w) =>
                  w.korean.contains(q) ||
                  w.english.toLowerCase().contains(q) ||
                  w.pronunciation.toLowerCase().contains(q))
              .toList();
      _applySort();
    });
  }

  void _applySort() {
    if (_sortBy == 'alpha') {
      _filtered.sort((a, b) => a.korean.compareTo(b.korean));
    } else if (_sortBy == 'pos') {
      _filtered.sort((a, b) => a.partOfSpeech.compareTo(b.partOfSpeech));
    }
  }

  void _setSort(String sort) {
    setState(() {
      _sortBy = sort;
      _applySort();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Gate level 2+ behind premium
    final isPremium = ref.watch(isPremiumProvider);
    if (widget.level > 1 && !isPremium) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: Text('TOPIK ${widget.level}'),
          backgroundColor: AppColors.topikColor(widget.level),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                      child: Icon(Icons.lock_rounded,
                          color: Colors.white, size: 32)),
                ),
                const SizedBox(height: 20),
                Text('TOPIK ${widget.level} — Pro Only',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 10),
                Text(
                    'Upgrade to Klexi Pro to access Level ${widget.level} '
                    'and all 7,200 TOPIK words.',
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textSecondary,
                        height: 1.5),
                    textAlign: TextAlign.center),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.push(AppRoutes.premium),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Upgrade to Pro',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final color = AppColors.topikColor(widget.level);
    final levelName = _levelNames[widget.level] ?? 'Level ${widget.level}';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ───────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 160,
            backgroundColor: color,
            foregroundColor: Colors.white,
            title: Text('TOPIK ${widget.level} — $levelName',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            flexibleSpace: FlexibleSpaceBar(
              // title 없음 — SliverAppBar.title이 collapsed 시 표시
              collapseMode: CollapseMode.pin,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color.withOpacity(0.85), color],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('TOPIK ${widget.level}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ),
                          const SizedBox(width: 10),
                          Text(levelName,
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ]),
                        const SizedBox(height: 4),
                        Text(
                          '${_words.length} words  •  ${_levelDesc[widget.level] ?? ''}',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.8)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () => context.push(
                    '${AppRoutes.sentenceCard}?level=${widget.level}'),
                icon: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 18),
                label: const Text('Practice',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          ),

          // ── Search + Sort bar ─────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search Korean or English…',
                      hintStyle: const TextStyle(
                          fontSize: 14, color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.search,
                          size: 20, color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.surfaceAlt,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusPill),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: _setSort,
                  icon: const Icon(Icons.sort,
                      color: AppColors.textSecondary),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'default', child: Text('Default order')),
                    PopupMenuItem(value: 'alpha', child: Text('A → Z (Korean)')),
                    PopupMenuItem(value: 'pos', child: Text('Part of speech')),
                  ],
                ),
              ]),
            ),
          ),

          // ── Word count ────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                _searchCtrl.text.isEmpty
                    ? '${_words.length} words'
                    : '${_filtered.length} of ${_words.length} words',
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ),

          // ── Word list ─────────────────────────────────────
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                if (i >= _filtered.length) return null;
                return _WordRow(
                  word: _filtered[i],
                  levelColor: color,
                  onTap: () => context.push(
                      '${AppRoutes.wordCard}?id=${_filtered[i].id}'),
                  onSpeak: () => ref
                      .read(ttsServiceProvider)
                      .speak(_filtered[i].korean),
                );
              },
              childCount: _filtered.length,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),

      // ── FAB — Start Practice ──────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.push('${AppRoutes.sentenceCard}?level=${widget.level}'),
        backgroundColor: color,
        icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
        label: const Text('Practice This Level',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _WordRow extends StatelessWidget {
  final Word word;
  final Color levelColor;
  final VoidCallback onTap;
  final VoidCallback onSpeak;

  const _WordRow({
    required this.word,
    required this.levelColor,
    required this.onTap,
    required this.onSpeak,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
              bottom: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: Row(children: [
          // Korean + pronunciation
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(word.korean,
                    style: const TextStyle(
                        fontFamily: 'NotoSansKR',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                if (word.pronunciation.isNotEmpty)
                  Text('[${word.pronunciation}]',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          // English meaning
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(word.english,
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary)),
                if (word.partOfSpeech.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: levelColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(word.partOfSpeech,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: levelColor)),
                  ),
              ],
            ),
          ),
          // TTS button
          IconButton(
            icon: Icon(Icons.volume_up_outlined,
                size: 20, color: levelColor.withOpacity(0.7)),
            onPressed: onSpeak,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ]),
      ),
    );
  }
}
