plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.houston"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    applicationVariants.all {
        outputs.all {
            val outputImpl = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            val abi = outputImpl.getFilter(com.android.build.OutputFile.ABI)
            outputImpl.outputFileName = if (abi != null) {
                "${applicationId}-${versionName}-${abi}.apk"
            } else {
                "${applicationId}-${versionName}-universal.apk"
            }
        }
    }
    
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.houston" // Keep this consistent across all versions
        minSdk = 24
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    // Warning Disabled For Debugging 
    splits {
        abi {
            // setEnable(true)
            // reset()
            // include("armeabi-v7a", "arm64-v8a", "x86_64")
            // setUniversalApk(true) 
        } 
    }

    signingConfigs {
        create("release") {
            storeFile = file("release-key.jks") 
            storePassword = "houstondev.flywich" 
            keyAlias = "houston-release"         
            keyPassword = "houstondev.flywich"   
        }
        
        // // IMPORTANT: Using same signing for debug builds to avoid conflicts
        // getByName("debug") {
        //     storeFile = file("release-key.jks") 
        //     storePassword = "houstondev.flywich" 
        //     keyAlias = "houston-release"         
        //     keyPassword = "houstondev.flywich"   
        // }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("release")
        }
        
        debug {
            // Apply same signing to debug builds
            signingConfig = signingConfigs.getByName("debug")
            isDebuggable = true
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.google.android.play:core:1.10.3")
    // Add these dependencies for better APK installation handling
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
}