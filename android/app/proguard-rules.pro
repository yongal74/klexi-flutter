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
