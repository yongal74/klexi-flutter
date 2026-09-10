# Klexi build52 7축 리뷰 원문 — 2026-09-10

PM 봇(claude-ad)이 병렬 서브에이전트 7개로 수행한 읽기 전용 리뷰의 **원문 보존본**. 기준 커밋 `38cdcf2`(1.0.6+52, Play 라이브). 조치 항목은 `../../UPGRADE_PLAN_build53.md`에 WP로 정리돼 있고, 여기는 그 근거 전체(P2 포함)다.

| 파일 | 축 | 핵심 |
|---|---|---|
| security.md | 보안 | 백엔드 무인증 비용 노출, 프롬프트 주입·캐시 오염, 계정삭제 박스명 불일치, 음성 미고지 |
| stability.md | 안정성/정확성 | 정확알람 예외로 리마인더 무음 실패, 세션 미복원, Hive 박스 uid 없음, TTS 라우트 부재, FCM fatal 기록 |
| performance.md | 성능 | 콜드스타트 RC 대기, 워드네트워크 프레임 재빌드·TextPainter·수천 drawLine, TTS 캐시 무제한, 폰트 런타임 로딩 |
| ux.md | UX/UI | Start Free Trial 무동작, 페이월 무한 스피너, 한국어 UI 문자열, 게스트 업그레이드 경로 없음, 온보딩 없음, 대비·터치타깃 |
| functional.md | 기능 완결성 | 클라↔서버 라우트 불일치, 테마 카드 오동작, cloze 게이팅 누락, 웹 빌드 빈 화면, 게이팅 맵, FCM 딥링크 미사용 |
| maintainability.md | 유지보수성 | CI 3중 불통, required 인자 회귀, SRS 3중 정의, polar 잔재, 가짜 테스트, 문서 드리프트, 단종 패키지 |
| android16_policy.md | Android 16/정책 | 정확알람·부트 리시버, 광고ID 미고지, 백업 규칙, edge-to-edge, predictive back, 16KB, 구독 고지 문구 |

PM 재검증(09-10): 각 축의 P0/P1 핵심 주장은 file:line로 실제 코드 대조 완료, 오탐 없음. 단 `functional.md` A9의 "asset 디렉토리 부재가 빌드 실패"는 경고에 그침(빌드는 성공) — 정정.

당일 처리 상태(09-10 세션 종료 시점): security 1·2·3·4·6·7·11, stability 1·2·3·4·5·9·10·12, functional A1·A2·A3·A7(일부)·A9, maintainability 1·2·4·11(일부), android16 1·2·3·4·6·10 → **코드 반영 완료**(master `66e84ba`, 배포 전). 나머지는 P1/P2로 `HANDOFF_build53.md` 참조.
