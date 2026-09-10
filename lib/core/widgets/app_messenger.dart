// lib/core/widgets/app_messenger.dart
// 위젯 트리 밖(서비스 계층)에서도 스낵바를 띄우기 위한 전역 키.
// MaterialApp.router 의 scaffoldMessengerKey 로 넘긴다.

import 'package:flutter/material.dart';

final GlobalKey<ScaffoldMessengerState> klexiMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
