plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.surakshasetu.mobile"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.surakshasetu.mobile"
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"

        buildConfigField("String", "CLOUDINARY_CLOUD_NAME", "\"dkryeldxv\"")
        buildConfigField("String", "CLOUDINARY_UPLOAD_PRESET", "\"Suraksha_Media\"")
        buildConfigField("String", "CLOUDINARY_FOLDER", "\"sos_media\"")
    }

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    buildTypes {
        debug {
        // Disable shrinking in debug builds
        isMinifyEnabled = false
        isShrinkResources = false
    }
    release {
        // Enable shrinking safely only if you plan to release
        isMinifyEnabled = true
        isShrinkResources = true
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
        signingConfig = signingConfigs.getByName("debug")
    }
}}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.constraintlayout:constraintlayout:2.1.4")
    implementation("com.google.android.material:material:1.12.0")

    // ✅ CameraX (all required modules)
    val camerax_version = "1.3.4"
    implementation("androidx.camera:camera-core:$camerax_version")
    implementation("androidx.camera:camera-camera2:$camerax_version")
    implementation("androidx.camera:camera-lifecycle:$camerax_version")
    implementation("androidx.camera:camera-video:$camerax_version")
    implementation("androidx.camera:camera-view:$camerax_version")

    // ✅ Guava (for ListenableFuture)
    implementation("com.google.guava:guava:32.1.3-android")

    // ✅ Lifecycle and coroutines
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.6")
    implementation("androidx.lifecycle:lifecycle-service:2.8.6")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")

    // ✅ Firebase KTX libraries
    implementation("com.google.firebase:firebase-firestore-ktx:25.1.0")
    implementation("com.google.firebase:firebase-auth-ktx:23.0.0")

    // ✅ Google Play Services (for Location)
    implementation("com.google.android.gms:play-services-location:21.3.0")
}

apply(plugin = "com.google.gms.google-services")
