pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        // 国内镜像策略: 本地默认走阿里云镜像(公司网络直连 dl.google.com 不稳定);
        // GitHub Actions 上自动改用官方仓库(镜像 502 会导致依赖解析失败)。
        // 可用环境变量 POETRY_MATE_USE_ALIYUN_MIRROR=true/false 强制覆盖。
        if (useAliyunMirror()) {
            maven { url = uri("https://maven.aliyun.com/repository/google") }
            maven { url = uri("https://maven.aliyun.com/repository/central") }
            maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
        }
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

fun useAliyunMirror(): Boolean {
    val explicit = System.getenv("POETRY_MATE_USE_ALIYUN_MIRROR")
    if (explicit == "true") return true
    if (explicit == "false") return false
    // GitHub Actions 环境默认使用官方仓库
    return System.getenv("GITHUB_ACTIONS") != "true"
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
