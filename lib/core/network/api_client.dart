// lib/core/network/api_client.dart
// 백엔드(/api/**) 호출 단일 창구.
//
// build52 까지 백엔드는 완전 무인증이었다(functions/src/index.ts 의
// invoker: "public", 토큰 검사 없음). 누구나 OpenAI 비용을 태울 수 있었고
// 프롬프트 주입·캐시 오염이 가능했다. build53 WP-01 에서 서버가
// Firebase ID 토큰을 요구하도록 바뀌었으므로, 클라이언트는 모든 요청에
// Authorization: Bearer <idToken> 을 실어야 한다.
//
// dio 기반 호출은 [apiDioProvider] 를, SSE 처럼 dio 를 못 쓰는 곳은
// [currentIdToken] 을 직접 쓴다.

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_config.dart';

/// 로그인이 필요한 요청을 비로그인(게스트) 상태로 보냈을 때.
/// 화면은 "Sign in to use AI features" 안내 + 로그인 버튼을 보여준다.
class AuthRequiredException implements Exception {
  const AuthRequiredException([this.message = 'Sign in to use AI features']);
  final String message;
  @override
  String toString() => message;
}

/// 현재 Firebase 사용자의 ID 토큰. 게스트/비로그인이면 null.
/// 만료가 임박하면 firebase_auth 가 알아서 갱신한다.
Future<String?> currentIdToken() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  try {
    return await user.getIdToken();
  } on FirebaseAuthException catch (e) {
    debugPrint('[ApiClient] ID 토큰 발급 실패: $e');
    return null;
  }
}

/// 모든 /api 요청에 ID 토큰을 붙이고, 401 을 [AuthRequiredException] 으로
/// 바꿔 던지는 인터셉터.
class AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // /api/health 만 무인증이다. 토큰이 없으면 서버가 401 을 줄 것이므로
    // 여기서 미리 끊어 불필요한 왕복을 없앤다.
    if (!options.path.contains('/health')) {
      final token = await currentIdToken();
      if (token == null) {
        return handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.cancel,
            error: const AuthRequiredException(),
          ),
        );
      }
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      handler.reject(DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: DioExceptionType.badResponse,
        error: const AuthRequiredException(),
      ));
      return;
    }
    handler.next(err);
  }
}

/// 백엔드 호출용 단일 Dio. baseUrl 은 backendUrl 루트이므로
/// 경로는 '/api/...' 로 적는다.
final apiDioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: const String.fromEnvironment('API_URL',
        defaultValue: AppConfig.backendUrl),
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  ));
  dio.interceptors.add(AuthInterceptor());
  return dio;
});

/// DioException 안에 [AuthRequiredException] 이 들어 있는지 확인한다.
bool isAuthRequired(Object error) =>
    error is AuthRequiredException ||
    (error is DioException && error.error is AuthRequiredException);
