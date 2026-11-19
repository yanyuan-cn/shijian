import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 签名材料放在 android/key.properties（不进仓库）。文件不存在时回退 debug 签名，
// 保证别人 clone 下来也能直接 flutter run。
val keystoreFile = rootProject.file("key.properties")
val keystoreProps = Properties()
val hasKeystore = keystoreFile.exists()
if (hasKeystore) {
    FileInputStream(keystoreFile).use { keystoreProps.load(it) }
}

android {
    namespace = "com.shijian.shijian"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // 第一版就定死，之后永不更改：换 applicationId 等于换一个 App，数据不通用。
        applicationId = "com.shijian.shijian"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // 版本号来自 pubspec.yaml 的 version: 1.0.0+1 —— 应用内更新靠 versionCode 比较大小。
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasKeystore) {
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
                storeFile = file(keystoreProps.getProperty("storeFile"))
                storePassword = keystoreProps.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
