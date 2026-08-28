import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 发布签名(可选):
//   本地开发无需配置,release 回退到 debug 签名,产物仍可直接安装;
//   正式发布在 android/key.properties 提供 keystore(不入库),或由 CI 注入。
const val KEY_PROPS_FILE = "key.properties"

val signing = Properties()
val signingFile = rootProject.file(KEY_PROPS_FILE)
if (signingFile.exists()) {
    signingFile.inputStream().use(signing::load)
}
val hasSigning = signing.getProperty("storeFile") != null &&
    signing.getProperty("storePassword") != null &&
    signing.getProperty("keyAlias") != null &&
    signing.getProperty("keyPassword") != null

android {
    namespace = "com.poetrymate.poetry_mate"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.poetrymate.poetry_mate"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasSigning) {
            create("release") {
                keyAlias = signing.getProperty("keyAlias")
                keyPassword = signing.getProperty("keyPassword")
                storeFile = rootProject.file(signing.getProperty("storeFile")!!)
                storePassword = signing.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // 配置了 key.properties 则使用正式签名,否则回退 debug 签名(可直接安装)。
            signingConfig = if (hasSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
