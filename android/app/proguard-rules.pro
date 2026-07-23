# ── M7 — ProGuard/R8 rules ────────────────────────────────────────────
# Obfuscation tingkat tinggi: rename class/method/field, buang unused code,
# tapi keep Flutter engine + native bridges biar tidak crash.

# Flutter engine
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-dontwarn io.flutter.**

# Firebase / Play services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Anti-tamper JNI bridge — nama method harus tetap supaya JNI resolve.
-keepclasseswithmembernames class com.claudememek.app.NativeBridge {
    native <methods>;
}
-keep class com.claudememek.app.NativeBridge { *; }
-keep class com.claudememek.app.MainActivity { *; }

# Aggressive rename untuk semua class app lain
-repackageclasses 'o'
-allowaccessmodification
-optimizationpasses 5
-overloadaggressively

# Kotlin metadata
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**

# String obfuscation-friendly (buang log)
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}
