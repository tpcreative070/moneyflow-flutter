plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "co.tpcreative.moneyflow.app"
    // UPDATED: Set compilation toolchain platform to API level 36
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "co.tpcreative.moneyflow.app"
        minSdk = flutter.minSdkVersion
        // UPDATED: Set runtime targeted performance behaviors to Android 16 (API 36)
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Release signing — reads android/key.properties
    val keyPropsFile = rootProject.file("key.properties")
    if (keyPropsFile.exists()) {
        val keyProps = java.util.Properties().apply {
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