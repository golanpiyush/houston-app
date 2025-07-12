plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.houston"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.houston" // Change to your unique ID
        minSdk = 24
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true // optional for large apps
    }

    splits {
        abi {
            isEnable = true           // <-- fix here: was `isEnable`, should be `enable`
            reset()
            include("armeabi-v7a", "arm64-v8a", "x86_64")
            isUniversalApk = false    // smaller APKs instead of fat APK
        }
    }

    signingConfigs {
        create("release") {
            storeFile = file("keystore.jks") 
            storePassword = "houston-piyush" 
            keyAlias = "my-key-alias"         
            keyPassword = "houston-piyush"   
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro" // This file should be in android/app/
            )
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
        implementation("com.google.android.play:core:1.10.3")

}
