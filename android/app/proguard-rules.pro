# Reglas para Flowy - Protege la librería de carga de música
-keep class com.google.android.gms.internal.** { *; }
-dontwarn com.google.android.gms.internal.**

# No tocar clases de YouTube Explode
-keep class youtube_explode_dart.** { *; }
-dontwarn youtube_explode_dart.**

# Preservar anotaciones para JSON/Serialización
-keepattributes Signature, Exceptions, *Annotation*, InnerClasses
-keep class * implements double.com.google.gson.TypeAdapterFactory
-keep class * implements double.com.google.gson.JsonSerializer
-keep class * implements double.com.google.gson.JsonDeserializer

# Preservar el motor de Flutter y Plugins
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class com.ryanheise.audioservice.** { *; }

# Ignorar errores de Play Core (común en builds de Flutter)
-dontwarn com.google.android.play.core.**

