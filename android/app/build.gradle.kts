// FIX: import required in Kotlin DSL — java.util.Properties is not auto-imported
import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")      // applied here, declared in settings.gradle.kts
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "co.tpcreative.moneyflow.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "co.tpcreative.moneyflow.app"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Release signing — reads android/key.properties
    val keyPropsFile = rootProject.file("key.properties")
    if (keyPropsFile.exists()) {
        val keyProps = Properties().apply {
            load(keyPropsFile.inputStream())
        }
        signingConfigs {
            create("release") {
                storeFile     = file(keyProps["storeFile"] as String)
                storePassword = keyProps["storePassword"] as String
                keyAlias      = keyProps["keyAlias"] as String
                keyPassword   = keyProps["keyPassword"] as String
            }
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
        release {
            signingConfig = if (keyPropsFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
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
