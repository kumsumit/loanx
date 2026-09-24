import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val hasReleaseSigning = listOf(
    "keyAlias",
    "keyPassword",
    "storeFile",
    "storePassword",
).all { !keystoreProperties.getProperty(it).isNullOrBlank() }

android {
    namespace = "com.kumpali.loanx"
    compileSdk = 37
    ndkVersion = "30.0.16248370"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    defaultConfig {
        applicationId = "com.kumpali.loanx"
        minSdk = flutter.minSdkVersion
        targetSdk = 37
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

//    splits {
//        abi {
//            isEnable = true
//            reset()
//            include("arm64-v8a")
//            // "armeabi-v7a", "x86", "x86_64"
//            isUniversalApk = false
//        }
//    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = true
            isShrinkResources = true
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "android/key.properties is missing or incomplete; " +
                        "signing this local release with the debug key."
                )
                signingConfigs.getByName("debug")
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Flutter generates the Android plugin registrant from all resolved Dart
    // packages, including `integration_test` in dev_dependencies.  The Flutter
    // Gradle plugin excludes dev plugins from releaseCompileClasspath, leaving
    // that generated reference unresolved.  Keep the plugin available for the
    // generated registrant; it is inert outside an instrumentation test.
    implementation(project(":integration_test"))

    implementation("com.google.android.play:review:2.0.2")
    implementation("com.google.android.play:review-ktx:2.0.2")

//    implementation("com.google.android.play:asset-delivery:2.2.2")
//    implementation("com.google.android.play:asset-delivery-ktx:2.2.2")
//    implementation("com.google.android.play:feature-delivery:2.1.0")
//    implementation("com.google.android.play:feature-delivery-ktx:2.1.0")
//    implementation("com.google.android.play:core-ktx:1.15.0")
//    implementation(platform("com.google.firebase:firebase-bom:33.5.1"))
//    implementation("com.google.firebase:firebase-analytics")
}
