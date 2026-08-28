fun useAliyunMirror(): Boolean {
    val explicit = System.getenv("POETRY_MATE_USE_ALIYUN_MIRROR")
    if (explicit == "true") return true
    if (explicit == "false") return false
    // GitHub Actions 环境默认使用官方仓库
    return System.getenv("GITHUB_ACTIONS") != "true"
}

allprojects {
    repositories {
        // 国内镜像策略: 本地默认走阿里云镜像;GitHub Actions 自动改用官方仓库。
        // 可用环境变量 POETRY_MATE_USE_ALIYUN_MIRROR=true/false 强制覆盖。
        if (useAliyunMirror()) {
            maven { url = uri("https://maven.aliyun.com/repository/google") }
            maven { url = uri("https://maven.aliyun.com/repository/central") }
            maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
        }
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
