# google_mlkit_text_recognition references the optional Chinese, Devanagari, Japanese and
# Korean recognizers. ReceiptMind only bundles the Latin model (v0.1), so those classes
# are absent at build time and must not fail R8.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
