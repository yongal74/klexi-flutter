/// Mobile platform implementation — dart:io + just_audio + path_provider
library;

import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
final AudioPlayer _player = AudioPlayer();

Future<String> get _cacheDir async {
  final dir = await getTemporaryDirectory();
  final ttsDir = Directory('${dir.path}/tts_cache');
  if (!await ttsDir.exists()) await ttsDir.create(recursive: true);
  return ttsDir.path;
}

String _cacheKey(String text, bool isSlow, String engine) {
  final slug = text.hashCode.abs().toString();
  final speedTag = isSlow ? 'slow' : 'normal';
  return '${engine}_${slug}_$speedTag.mp3';
}

Future<String?> loadCached(String text, bool isSlow, String engine) async {
  final dir = await _cacheDir;
  final file = File('$dir/${_cacheKey(text, isSlow, engine)}');
  return await file.exists() ? file.path : null;
}

Future<String> saveCache(
    String text, bool isSlow, String engine, List<int> bytes) async {
  final dir = await _cacheDir;
  final file = File('$dir/${_cacheKey(text, isSlow, engine)}');
  await file.writeAsBytes(bytes);
  return file.path;
}

Future<void> playFile(String path) async {
  await _player.stop();
  await _player.setFilePath(path);
  await _player.play();
}

Future<void> stopPlayer() async {
  await _player.stop();
}

void disposePlayer() {
  _player.dispose();
}
