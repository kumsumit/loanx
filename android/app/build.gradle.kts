import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.kumpali.loanx"
    compileSdk = 35
    ndkVersion = "29.0.14206865"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_24
        targetCompatibility = JavaVersion.VERSION_24
    }

    defaultConfig {
        applicationId = "com.kumpali.loanx"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = 1 // flutter.versionCode
        versionName = "1.0.1" // flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let {
                file(it as String)
            }
            storePassword = keystoreProperties["storePassword"] as String?
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
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_24)
    }
}

flutter {
    source = "../.."
}

dependencies {
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
