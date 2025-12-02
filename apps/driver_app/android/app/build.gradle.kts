plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.driver_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Bạn đang dùng Java 11 → vẫn OK
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11

        // 🔥 Quan trọng: bật core library desugaring
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.driver_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Tạm thời ký bằng debug key cho dễ run
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// 👇 Thêm block này nếu file bạn chưa có dependencies
dependencies {
    // Version này là ví dụ, tốt nhất mở rider_app/android/app/build.gradle(.kts)
    // rồi copy y chang version nó đang dùng cho đồng bộ.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
