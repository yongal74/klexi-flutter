# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Hive
-keep class com.hive.** { *; }

# Kotlin
-dontwarn kotlin.**
-keep class kotlin.** { *; }

# Google Play Core (split install / dynamic delivery)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# RevenueCat (purchases_flutter) — 리플렉션 기반 모델 직렬화가 깨지지 않도록 유지 (WP-05)
-keep class com.revenuecat.purchases.** { *; }
-dontwarn com.revenuecat.purchases.**

# flutter_local_notifications — 예약 알림 리시버는 매니페스트에서 이름으로 참조된다 (WP-04)
-keep class com.dexterous.flutterlocalnotifications.** { *; }
