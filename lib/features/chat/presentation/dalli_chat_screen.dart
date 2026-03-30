import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/constants/app_spacing.dart';
import '../../home/presentation/home_screen.dart' show userTopikLevelProvider;

// ── Mode ─────────────────────────────────────────────────
enum DalliMode { freeChat, wordReview, rolePlay, grammarCoach }

extension DalliModeLabel on DalliMode {
  String get label {
    switch (this) {
      case DalliMode.freeChat:     return 'Free Chat';
      case DalliMode.wordReview:   return 'Word Review';
      case DalliMode.rolePlay:     return 'Role Play';
      case DalliMode.grammarCoach: return 'Grammar Coach';
    }
  }
  String get icon {
    switch (this) {
      case DalliMode.freeChat:     return '💬';
      case DalliMode.wordReview:   return '📚';
      case DalliMode.rolePlay:     return '🎭';
      case DalliMode.grammarCoach: return '✏️';
    }
  }
}

// ── Message model ─────────────────────────────────────────
class ChatMessage {
  final String text;
  final bool isUser;
  final List<String> wordPills;
  final DateTime time;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.wordPills = const [],
    DateTime? time,
  }) : time = time ?? DateTime.now();
}

// ── Providers ─────────────────────────────────────────────
final chatMessagesProvider = StateProvider<List<ChatMessage>>((ref) => [
  ChatMessage(
    text: "안녕하세요! I'm Dalli 👋\nWhat would you like to practice today?",
    isUser: false,
    wordPills: ['안녕하세요', '연습'],
  ),
]);
final dalliModeProvider = StateProvider<DalliMode>((ref) => DalliMode.freeChat);
final dalliTypingProvider = StateProvider<bool>((ref) => false);

class DalliChatScreen extends ConsumerStatefulWidget {
  const DalliChatScreen({super.key});
  @override
  ConsumerState<DalliChatScreen> createState() => _DalliChatScreenState();
}

class _DalliChatScreenState extends ConsumerState<DalliChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  // 이전 메시지들 (API 호출용)
  final List<Map<String, String>> _history = [];

  void _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();

    final msgs = ref.read(chatMessagesProvider.notifier);
    msgs.update((s) => [...s, ChatMessage(text: text, isUser: true)]);
    _history.add({'role': 'user', 'content': text});
    _scrollDown();

    ref.read(dalliTypingProvider.notifier).state = true;

    if (!AppConfig.isBackendConfigured) {
      // 개발 모드: 즉각 응답
      await Future.delayed(const Duration(milliseconds: 800));
      ref.read(dalliTypingProvider.notifier).state = false;
      final reply = ChatMessage(
        text: 'Backend URL not configured. Edit AppConfig.backendUrl.',
        isUser: false,
      );
      msgs.update((s) => [...s, reply]);
      _scrollDown();
      return;
    }

    try {
      // SSE 스트리밍 호출
      final userLevel = ref.read(userTopikLevelProvider);
      final mode = ref.read(dalliModeProvider);
      final uri = Uri.parse('${AppConfig.backendUrl}/api/ai-chat');
      final request = http.Request('POST', uri)
        ..headers['Content-Type'] = 'application/json'
        ..body = json.encode({
          'messages': _history.length > 8 ? _history.sublist(_history.length - 8) : _history,
          'userLevel': userLevel,
          'mode': mode.name,
        });

      final response = await http.Client().send(request);

      String accumulated = '';
      ref.read(dalliTypingProvider.notifier).state = false;

      // 스트리밍 응답 파싱 (SSE 형식: "data: {...}\n\n")
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        for (final line in chunk.split('\n')) {
          if (!line.startsWith('data: ')) continue;
          final payload = line.substring(6).trim();
          if (payload.isEmpty) continue;
          try {
            final parsed = json.decode(payload) as Map<String, dynamic>;
            if (parsed['done'] == true) break;
            final content = parsed['content'] as String? ?? '';
            accumulated += content;

            // 실시간으로 마지막 메시지 업데이트
            final current = ref.read(chatMessagesProvider);
            if (current.isNotEmpty && !current.last.isUser) {
              msgs.update((s) => [
                ...s.sublist(0, s.length - 1),
                ChatMessage(text: accumulated, isUser: false),
              ]);
            } else {
              msgs.update((s) => [...s, ChatMessage(text: accumulated, isUser: false)]);
            }
            _scrollDown();
          } catch (_) {}
        }
      }

      if (accumulated.isNotEmpty) {
        _history.add({'role': 'assistant', 'content': accumulated});
      }
    } catch (e) {
      ref.read(dalliTypingProvider.notifier).state = false;
      msgs.update((s) => [...s, ChatMessage(
        text: 'Connection error. Check your internet connection.',
        isUser: false,
      )]);
      _scrollDown();
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider);
    final mode = ref.watch(dalliModeProvider);
    final typing = ref.watch(dalliTypingProvider);
    final lastMsg = messages.isNotEmpty && !messages.last.isUser ? messages.last : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0E1A),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────
            _Header(mode: mode, onModeChange: (m) {
              ref.read(dalliModeProvider.notifier).state = m;
            }),

            // ── History bubbles ──────────────────────────
            if (messages.length > 1)
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: messages.length - 1,
                  itemBuilder: (_, i) => _HistoryBubble(messages[i]),
                ),
              ),

            const Divider(color: Colors.white12, height: 1),

            // ── Focus zone: large Q&A ────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.x2l),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (typing) ...[
                      const _TypingIndicator(),
                    ] else if (lastMsg != null) ...[
                      // Dalli's current message — large
                      Text(
                        lastMsg.text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'NotoSansKR',
                          fontSize: 22,
                          height: 1.7,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (lastMsg.wordPills.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: lastMsg.wordPills.map((p) => _WordPill(p)).toList(),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),

            // ── Input area ───────────────────────────────
            _InputBar(
              controller: _ctrl,
              focusNode: _focus,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final DalliMode mode;
  final ValueChanged<DalliMode> onModeChange;
  const _Header({required this.mode, required this.onModeChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 20),
              ),
              const SizedBox(width: 12),
              // Dalli avatar
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('D', style: TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Dalli', style: TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  Text('AI Korean Tutor', style: TextStyle(
                    color: Colors.white.withOpacity(0.5), fontSize: 12)),
                ],
              ),
              const Spacer(),
              _OnlineDot(),
            ],
          ),
          const SizedBox(height: 12),
          // Mode selector
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: DalliMode.values.map((m) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onModeChange(m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: m == mode
                          ? AppColors.primary
                          : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    ),
                    child: Text('${m.icon} ${m.label}', style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: m == mode ? Colors.white : Colors.white60,
                    )),
                  ),
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnlineDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 8, height: 8,
      decoration: const BoxDecoration(
        color: AppColors.success, shape: BoxShape.circle),
    ),
    const SizedBox(width: 4),
    const Text('Online', style: TextStyle(color: AppColors.success, fontSize: 12)),
  ]);
}

// ── History bubble ────────────────────────────────────────
class _HistoryBubble extends StatelessWidget {
  final ChatMessage msg;
  const _HistoryBubble(this.msg);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      constraints: const BoxConstraints(maxWidth: 200),
      decoration: BoxDecoration(
        color: msg.isUser
            ? AppColors.primary.withOpacity(0.9)
            : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        msg.text.replaceAll('\n', ' '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'NotoSansKR',
          fontSize: 12,
          color: msg.isUser ? Colors.white : Colors.white70,
        ),
      ),
    );
  }
}

// ── Word pill ─────────────────────────────────────────────
class _WordPill extends StatelessWidget {
  final String text;
  const _WordPill(this.text);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.2),
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      border: Border.all(color: AppColors.primary.withOpacity(0.4)),
    ),
    child: Text(text, style: const TextStyle(
      fontFamily: 'NotoSansKR',
      fontSize: 15, fontWeight: FontWeight.w600,
      color: Colors.white)),
  );
}

// ── Typing indicator ─────────────────────────────────────
class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('Dalli is typing…',
          style: TextStyle(color: Colors.white60, fontSize: 16)),
      ),
    ],
  );
}

// ── Input bar ─────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1B2E),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Type a message…',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                  fillColor: Colors.transparent,
                  filled: true,
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
