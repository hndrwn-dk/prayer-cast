import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.tursinalabs.prayer_cast"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.tursinalabs.prayer_cast"
        // You can update the following values to match your application needs.
        // For more information, see https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Play / production: upload key from android/key.properties.
            // Never fall back to debug keys — Play rejects those, and a
            // debug-signed AAB would lock the listing to the wrong cert.
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

tasks.configureEach {
    val releaseTask =
        name.contains("assembleRelease", ignoreCase = true) ||
            name.contains("bundleRelease", ignoreCase = true)
    if (releaseTask) {
        doFirst {
            check(keystorePropertiesFile.exists()) {
                "Missing android/key.properties. Copy android/key.properties.example, " +
                    "create the upload keystore, and do not sign release with debug keys."
            }
            val store = file(keystoreProperties.getProperty("storeFile"))
            check(store.isFile) {
                "Upload keystore not found at ${store.absolutePath}."
            }
        }
    }
}

dependencies {
    // NotificationCompat + ContextCompat for FGS / alarm receiver (spec §5.5).
    implementation("androidx.core:core-ktx:1.15.0")
    // Same pin as flutter_chrome_cast — probe RemoteMediaClient readiness.
    implementation("com.google.android.gms:play-services-cast-framework:21.5.0")
    // Periodic alarm heal. Not in pubspec — no Flutter WorkManager plugin.
    implementation("androidx.work:work-runtime-ktx:2.9.1")
}
