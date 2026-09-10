/// Web platform stub — no file I/O, no just_audio
/// On web, TtsService uses flutter_tts (browser SpeechSynthesis) directly.
library;

Future<String?> loadCached(String text, bool isSlow, String voice) async =>
    null;

Future<String> saveCache(
        String text, bool isSlow, String voice, List<int> bytes) async =>
    '';

Future<void> pruneCache({int maxBytes = 50 * 1024 * 1024}) async {}

Future<void> playFile(String path) async {}

Future<void> stopPlayer() async {}

void disposePlayer() {}
