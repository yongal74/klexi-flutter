/// Web platform stub — no file I/O, no just_audio
/// On web, TtsService uses flutter_tts (browser SpeechSynthesis) directly.
library;

Future<String?> loadCached(
    String text, bool isSlow, String engine) async => null;

Future<String> saveCache(
    String text, bool isSlow, String engine, List<int> bytes) async => '';

Future<void> playFile(String path) async {}

Future<void> stopPlayer() async {}

void disposePlayer() {}
