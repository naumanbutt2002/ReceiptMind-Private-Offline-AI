# google_mlkit_text_recognition references the optional Chinese, Devanagari, Japanese and
# Korean recognizers. ReceiptMind only bundles the Latin model (v0.1), so those classes
# are absent at build time and must not fail R8.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ML Kit text recognition loads its components and the bundled Latin model by
# reflection. Without these rules R8 renames them and recognition fails in
# release builds with a NullPointerException (found in M8 QA on the emulator).
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_bundled_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_common.** { *; }
-keep class com.google.android.gms.vision.** { *; }
-keep class com.google.android.libraries.vision.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }
-keep class com.google_mlkit_commons.** { *; }

# The ML Kit document scanner client (cunning_document_scanner) is built like the text
# recognizer (component registrars, firebase-encoders telemetry) but ships no consumer rules
# for its internal package, so it is kept the same way.
-keep class com.google.android.gms.internal.mlkit_vision_document_scanner.** { *; }
