# Release signing config for AI-Buddy
# Place your keystore at android/app/keystore/release.jks
# Create keystore: keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias aibuddy

# ProGuard rules for release builds
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-dontwarn kotlinx.coroutines.**

# Play Core
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }