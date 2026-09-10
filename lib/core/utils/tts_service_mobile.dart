/// Mobile platform implementation — dart:io + just_audio + path_provider
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

final AudioPlayer _player = AudioPlayer();

/// getTemporaryDirectory() 는 플랫폼 채널 왕복이라 재생마다 부르지 않는다.
String? _cachedDirPath;

Future<String> get _cacheDir async {
  final cached = _cachedDirPath;
  if (cached != null) return cached;
  final dir = await getTemporaryDirectory();
  final ttsDir = Directory('${dir.path}/tts_cache');
  if (!await ttsDir.exists()) await ttsDir.create(recursive: true);
  _cachedDirPath = ttsDir.path;
  return ttsDir.path;
}

/// 캐시 파일명. text.hashCode 는 실행마다 값이 달라질 수 있고 충돌하면
/// 엉뚱한 음성이 재생되므로 SHA-1 을 쓴다.
String _cacheKey(String text, bool isSlow, String voice) {
  final digest = sha1.convert(utf8.encode('$text|$voice|$isSlow'));
  return '$digest.mp3';
}

Future<String?> loadCached(String text, bool isSlow, String voice) async {
  final dir = await _cacheDir;
  final file = File('$dir/${_cacheKey(text, isSlow, voice)}');
  return await file.exists() ? file.path : null;
}

Future<String> saveCache(
    String text, bool isSlow, String voice, List<int> bytes) async {
  final dir = await _cacheDir;
  final file = File('$dir/${_cacheKey(text, isSlow, voice)}');
  await file.writeAsBytes(bytes);
  return file.path;
}

/// 캐시가 무한히 커지지 않도록 앱 시작 시 1회 정리한다.
/// 최근 접근(mtime) 순으로 남기고 [maxBytes] 를 넘는 만큼 오래된 것부터 지운다.
Future<void> pruneCache({int maxBytes = 50 * 1024 * 1024}) async {
  try {
    final dir = Directory(await _cacheDir);
    final files = <File>[];
    await for (final entity in dir.list()) {
      if (entity is File) files.add(entity);
    }
    var total = 0;
    for (final f in files) {
      total += await f.length();
    }
    if (total <= maxBytes) return;

    files
        .sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
    for (final f in files) {
      if (total <= maxBytes) break;
      total -= await f.length();
      await f.delete();
    }
  } on Exception catch (e) {
    debugPrint('[TTS] 캐시 정리 실패: $e');
  }
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
