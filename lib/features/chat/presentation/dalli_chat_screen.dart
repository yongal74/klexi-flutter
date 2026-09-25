import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/providers/user_level_provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_strings.dart';

// ── Mode ─────────────────────────────────────────────────
enum DalliMode { freeChat, wordReview, rolePlay, grammarCoach }

extension DalliModeLabel on DalliMode {
  String get label {
    switch (this) {
      case DalliMode.freeChat:
        return 'Free Chat';
      case DalliMode.wordReview:
        return 'Word Review';
      case DalliMode.rolePlay:
        return 'Role Play';
      case DalliMode.grammarCoach:
        return 'Grammar Coach';
    }
  }

  String get icon {
    switch (this) {
      case DalliMode.freeChat:
        return '💬';
      case DalliMode.wordReview:
        return '📚';
      case DalliMode.rolePlay:
        return '🎭';
      case DalliMode.grammarCoach:
        return '✏️';
    }
  }
}

// ── Message model ─────────────────────────────────────────
class ChatMessage {
  final String text;
  final bool isUser;
  final List<String> wordPills;
  final DateTime time;

  /// 연결 오류 등 안내 말풍선. 저장하지 않는다 — 저장하면 다음 실행 때
  /// 묵은 "Connection error" 가 Dalli 의 첫 말처럼 보인다.
  final bool isError;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.wordPills = const [],
    this.isError = false,
    DateTime? time,
  }) : time = time ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        'wordPills': wordPills,
        'time': time.millisecondsSinceEpoch,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        text: json['text'] as String,
        isUser: json['isUser'] as bool,
        wordPills: (json['wordPills'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        time: DateTime.fromMillisecondsSinceEpoch(json['time'] as int),
      );
}

// ── 채팅 히스토리 영속화 키 ────────────────────────────────
const _kChatHistoryKey = 'dalli_chat_history';
const _kMaxPersistedMessages = 50;

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

  // 전송 중 여부 — 중복 요청 방지
  bool _sending = false;

  // SSE 타임아웃 상수
  static const _kSseTimeout = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ── 히스토리 복원 ──────────────────────────────────────
  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kChatHistoryKey);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      if (list.isNotEmpty && mounted) {
        ref.read(chatMessagesProvider.notifier).state = list;
        // 재시작 후에도 Dalli 가 앞 대화를 기억하도록 최근 8개를 문맥으로 복원
        _history
          ..clear()
          ..addAll(list
              .where((m) => !m.isError && m.text.isNotEmpty)
              .map((m) => {
                    'role': m.isUser ? 'user' : 'assistant',
                    'content': m.text.length > 1000
                        ? m.text.substring(0, 1000)
                        : m.text,
                  })
              .toList()
              .reversed
              .take(8)
              .toList()
              .reversed);
      }
    } catch (e) {
      debugPrint('[Dalli] 히스토리 로드 실패: $e');
    }
  }

  // ── 히스토리 저장 ──────────────────────────────────────
  Future<void> _saveHistory(List<ChatMessage> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clean = messages.where((m) => !m.isError).toList();
      final toSave = clean.length > _kMaxPersistedMessages
          ? clean.sublist(clean.length - _kMaxPersistedMessages)
          : clean;
      await prefs.setString(
        _kChatHistoryKey,
        jsonEncode(toSave.map((m) => m.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('[Dalli] 히스토리 저장 실패: $e');
    }
  }

  // 이전 메시지들 (API 호출용)
  final List<Map<String, String>> _history = [];

  void _showDalliError(String text) {
    ref.read(dalliTypingProvider.notifier).state = false;
    final msgs = ref.read(chatMessagesProvider.notifier);
    msgs.state = [
      ...ref.read(chatMessagesProvider),
      ChatMessage(text: text, isUser: false, isError: true),
    ];
    _scrollDown();
  }

  void _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    if (!mounted) return;
    // 서버가 1,000자 초과 메시지를 거절한다(400) — 보내기 전에 안내
    if (text.length > 1000) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Messages can be up to 1,000 characters.')));
      return;
    }

    setState(() => _sending = true);
    _ctrl.clear();

    final msgs = ref.read(chatMessagesProvider.notifier);
    final newMessages = [
      ...ref.read(chatMessagesProvider),
      ChatMessage(text: text, isUser: true)
    ];
    msgs.state = newMessages;
    _history.add({'role': 'user', 'content': text});
    _scrollDown();
    await _saveHistory(newMessages);

    ref.read(dalliTypingProvider.notifier).state = true;

    if (!AppConfig.isBackendConfigured) {
      ref.read(dalliTypingProvider.notifier).state = false;
      final reply = ChatMessage(
        text: 'Backend URL not configured. Edit AppConfig.backendUrl.',
        isUser: false,
      );
      final updated = [...ref.read(chatMessagesProvider), reply];
      msgs.state = updated;
      await _saveHistory(updated);
      _scrollDown();
      if (mounted) setState(() => _sending = false);
      return;
    }

    http.Client? client;
    try {
      final userLevel = ref.read(userTopikLevelProvider);
      final mode = ref.read(dalliModeProvider);
      final uri = Uri.parse('${AppConfig.backendUrl}/api/ai-chat');

      // 서버(WP-01)가 Firebase ID 토큰을 요구한다. 게스트는 토큰이 없으므로
      // 왕복하지 않고 바로 로그인 안내를 띄운다.
      final idToken = await currentIdToken();
      if (idToken == null) {
        _showDalliError(AppStrings.signInForAi);
        return;
      }

      client = http.Client();
      final request = http.Request('POST', uri)
        ..headers['Content-Type'] = 'application/json'
        ..headers['Authorization'] = 'Bearer $idToken'
        ..body = json.encode({
          'messages': _history.length > 8
              ? _history.sublist(_history.length - 8)
              : _history,
          'userLevel': userLevel,
          'mode': mode.name,
        });

      final response = await client.send(request).timeout(
            _kSseTimeout,
            onTimeout: () => throw TimeoutException('ai-chat request timeout'),
          );

      // 400/401/500 은 SSE 가 아니라 JSON 오류 본문이 온다. 예전엔 이걸 SSE 로
      // 파싱하다 아무 줄도 못 찾고 조용히 끝나서 사용자는 무응답을 봤다.
      if (response.statusCode == 401) {
        _showDalliError(AppStrings.signInForAi);
        return;
      }
      if (response.statusCode != 200) {
        debugPrint('[Dalli] HTTP ${response.statusCode}');
        _showDalliError(
            "Dalli couldn't answer right now. Please try again in a moment.");
        return;
      }

      String accumulated = '';
      bool serverError = false;
      ref.read(dalliTypingProvider.notifier).state = false;

      // 줄 단위로 끊어 읽는다 — 네트워크 조각이 줄 중간에서 잘리면
      // 예전 split('\n') 방식은 그 줄을 통째로 버렸다.
      await response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .timeout(_kSseTimeout, onTimeout: (sink) => sink.close())
          .forEach((line) {
        if (!line.startsWith('data: ')) return;
        final payload = line.substring(6).trim();
        if (payload.isEmpty) return;
        try {
          final parsed = json.decode(payload) as Map<String, dynamic>;
          if (parsed['done'] == true) return;
          if (parsed['error'] != null) {
            serverError = true;
            return;
          }
          final content = parsed['content'] as String? ?? '';
          if (content.isEmpty) return;
          accumulated += content;

          final current = ref.read(chatMessagesProvider);
          if (current.isNotEmpty && !current.last.isUser) {
            msgs.state = [
              ...current.sublist(0, current.length - 1),
              ChatMessage(text: accumulated, isUser: false),
            ];
          } else {
            msgs.state = [
              ...current,
              ChatMessage(text: accumulated, isUser: false)
            ];
          }
          _scrollDown();
        } catch (e) {
          debugPrint('[Dalli] SSE parse error: $e');
        }
      });

      if (accumulated.isNotEmpty) {
        _history.add({'role': 'assistant', 'content': accumulated});
        await _saveHistory(ref.read(chatMessagesProvider));
      } else {
        _showDalliError(serverError
            ? "Dalli couldn't answer right now. Please try again in a moment."
            : "Dalli didn't reply. Please try again.");
      }
    } on TimeoutException {
      _showDalliError('Dalli is taking too long to respond. Please try again.');
    } catch (e) {
      debugPrint('[Dalli] send failed: $e');
      _showDalliError('Connection error. Check your internet connection.');
    } finally {
      // Client 반드시 닫기 — 소켓 누수 방지
      client?.close();
      if (mounted) setState(() => _sending = false);
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
    final lastMsg =
        messages.isNotEmpty && !messages.last.isUser ? messages.last : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0E1A),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────
            _Header(
                mode: mode,
                onModeChange: (m) {
                  ref.read(dalliModeProvider.notifier).state = m;
                }),

            // ── History bubbles ──────────────────────────
            if (messages.length > 1)
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: lastMsg.wordPills
                              .map((p) => _WordPill(p))
                              .toList(),
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
              sending: _sending,
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
                child: const Icon(Icons.arrow_back_ios,
                    color: Colors.white70, size: 20),
              ),
              const SizedBox(width: 12),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('D',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Dalli',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  Text('AI Korean Tutor',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.5), fontSize: 12)),
                ],
              ),
              const Spacer(),
              _OnlineDot(),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: DalliMode.values
                  .map((m) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => onModeChange(m),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: m == mode
                                  ? AppColors.primary
                                  : Colors.white.withOpacity(0.08),
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusPill),
                            ),
                            child: Text('${m.icon} ${m.label}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      m == mode ? Colors.white : Colors.white60,
                                )),
                          ),
                        ),
                      ))
                  .toList(),
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
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
              color: AppColors.success, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        const Text('Online',
            style: TextStyle(color: AppColors.success, fontSize: 12)),
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
        child: Text(text,
            style: const TextStyle(
                fontFamily: 'NotoSansKR',
                fontSize: 15,
                fontWeight: FontWeight.w600,
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
  final bool sending;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.sending,
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
                enabled: !sending,
                decoration: InputDecoration(
                  hintText:
                      sending ? 'Dalli is responding…' : 'Type a message…',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  fillColor: Colors.transparent,
                  filled: true,
                ),
                onSubmitted: sending ? null : (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: sending ? null : onSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: sending ? null : AppColors.primaryGradient,
                color: sending ? Colors.white12 : null,
                shape: BoxShape.circle,
              ),
              child: sending
                  ? const Center(
                      child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white54),
                    ))
                  : const Icon(Icons.arrow_upward_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
