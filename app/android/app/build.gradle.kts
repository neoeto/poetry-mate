import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 发布签名:
//   本地开发未配置时,release 回退到 debug 签名,产物仅适合临时测试;
//   正式发布在 android/key.properties 提供固定 keystore(不入库),CI 可通过环境变量强制要求。
// 注意: 脚本顶层不能用 const val,用普通 val。
val KEY_PROPS_FILE = "key.properties"

val signing = Properties()
val signingFile = rootProject.file(KEY_PROPS_FILE)
if (signingFile.exists()) {
    signingFile.inputStream().use(signing::load)
}
val hasSigning = listOf(
    "storeFile",
    "storePassword",
    "keyAlias",
    "keyPassword",
).all { !signing.getProperty(it).isNullOrBlank() }
val requireReleaseSigning =
    System.getenv("POETRY_MATE_REQUIRE_RELEASE_SIGNING") == "true"

android {
    namespace = "com.poetrymate.poetry_mate"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // Kotlin 编译目标改用 compilerOptions DSL(kotlinOptions.jvmTarget 字符串写法已弃用)

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
            // CI 发布包必须使用固定签名；本地未配置时仍允许 debug release 便于开发调试。
            signingConfig = when {
                hasSigning -> signingConfigs.getByName("release")
                requireReleaseSigning -> error(
                    "Release signing is required, but android/key.properties is missing or incomplete",
                )
                else -> signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}
