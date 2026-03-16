import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Klexi 타이포그래피 스케일 — Design Brief v2.0 기준
abstract class AppTypography {
  // ── Korean Font (NotoSansKR) ──────────────────────────
  static const String fontKorean = 'NotoSansKR';
  // ── English UI Font (Inter) ───────────────────────────
  static const String fontUI = 'Inter';

  // ── Display: 48px Bold — 메인 한국어 단어 ─────────────
  static const TextStyle display = TextStyle(
    fontFamily: fontKorean,
    fontSize: 48,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.2,
    letterSpacing: -0.5,
  );

  // ── Heading 1: 32px Bold — 화면 제목 ─────────────────
  static const TextStyle heading1 = TextStyle(
    fontFamily: fontUI,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.25,
  );

  // ── Heading 2: 24px SemiBold — 섹션 제목 ─────────────
  static const TextStyle heading2 = TextStyle(
    fontFamily: fontUI,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  // ── Heading 3: 20px SemiBold — 카드 타이틀 ───────────
  static const TextStyle heading3 = TextStyle(
    fontFamily: fontUI,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  // ── Body: 16px Regular — 본문 ─────────────────────────
  static const TextStyle body = TextStyle(
    fontFamily: fontUI,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  // ── Body Medium: 16px Medium — 강조 본문 ─────────────
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontUI,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  // ── Small: 14px Regular — 부가 정보 ──────────────────
  static const TextStyle small = TextStyle(
    fontFamily: fontUI,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  // ── Caption: 12px Regular — 레이블, 태그 ─────────────
  static const TextStyle caption = TextStyle(
    fontFamily: fontUI,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.3,
  );

  // ── Label: 11px Medium — 탭 라벨 ─────────────────────
  static const TextStyle label = TextStyle(
    fontFamily: fontUI,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.2,
    letterSpacing: 0.2,
  );

  // ── Korean Body: 18px Medium — 예문 가독성 향상 ───────
  static const TextStyle koreanBody = TextStyle(
    fontFamily: fontKorean,
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.6,
  );

  // ── Korean Caption: 14px Regular — 음절 분리 ─────────
  static const TextStyle koreanCaption = TextStyle(
    fontFamily: fontKorean,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
    letterSpacing: 4.0,  // 음절 사이 간격
  );

  // ── Button: 16px Bold — 버튼 텍스트 ──────────────────
  static const TextStyle button = TextStyle(
    fontFamily: fontUI,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: 0.1,
  );
}
