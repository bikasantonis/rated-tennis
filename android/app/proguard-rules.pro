# Flutter keeps
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Supabase / Ktor / OkHttp
-keep class io.github.jan.supabase.** { *; }
-dontwarn io.ktor.**
-dontwarn okhttp3.**
-dontwarn okio.**

# Kotlin serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keep,includedescriptorclasses class com.rated.app.**$$serializer { *; }
-keepclassmembers class com.rated.app.** {
    *** Companion;
}
-keepclasseswithmembers class com.rated.app.** {
    kotlinx.serialization.KSerializer serializer(...);
}

# Sentry
-keep class io.sentry.** { *; }

# OneSignal
-keep class com.onesignal.** { *; }

# Google Play Services
-keep class com.google.android.gms.** { *; }
