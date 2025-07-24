# Flutter and Dart need these to keep reflection and generated code
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.app.** { *; }

# Keep annotation information
-keepattributes *Annotation*

# Keep class members annotated with @Keep
-keep @androidx.annotation.Keep class * { *; }

# Keep the native library names
-keep class com.google.android.gms.** { *; }
-keep class com.google.firebase.** { *; }

# Workaround for bugs in Firebase and Google Play Services
-dontwarn com.google.android.gms.**
-dontwarn com.google.firebase.**

# Keep classes required for JSON serialization if using json_serializable or similar
-keep class com.example.yourpackage.** { *; }
