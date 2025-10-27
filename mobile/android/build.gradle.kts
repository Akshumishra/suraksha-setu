// Top-level Gradle build configuration for Flutter Android module

plugins {
    // ✅ Required Android and Kotlin plugins (do not apply directly)
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    id("com.google.gms.google-services") version "4.4.2" apply false

    // ✅ Flutter Gradle plugin (do not add version manually)
    id("dev.flutter.flutter-gradle-plugin") apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
        maven("https://storage.googleapis.com/download.flutter.io") // ✅ Flutter engine artifacts
    }
}

// ✅ Custom build directory logic (you can keep this as-is)
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    project.evaluationDependsOn(":app")
}

// ✅ Define a clean task for the whole project
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
