plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

// 1. Load the Key Properties safely
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.example.work_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        if (keystoreProperties["keyAlias"] != null) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = if (keystoreProperties["storeFile"] != null) {
                    file(keystoreProperties["storeFile"] as String)
                } else {
                    null
                }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    defaultConfig {
        applicationId = "com.example.work_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("debug") {
            // 1. This adds ".debug" to the ID so it installs as a SEPARATE app
            applicationIdSuffix = ".debug"
            
            // 2. This names the app "Pay Tracker (Dev)" on your home screen
            resValue("string", "app_name", "Pay Tracker (Dev)")
        }
        
        getByName("release") {
            val releaseConfig = signingConfigs.findByName("release")
            if (releaseConfig != null) {
                signingConfig = releaseConfig
            }
            isMinifyEnabled = false
            isShrinkResources = false
            
            // 3. This names the real app "Pay Tracker"
            resValue("string", "app_name", "Pay Tracker")
        }
    }
}

flutter {
    source = "../.."
}