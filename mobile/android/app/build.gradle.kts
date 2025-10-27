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
    // Firebase (BoM manages versions)
    implementation(platform("com.google.firebase:firebase-bom:33.4.0"))
   
    implementation("com.google.firebase:firebase-auth-ktx:22.3.1")
    implementation("com.google.firebase:firebase-firestore-ktx:25.1.0")
    implementation("com.google.firebase:firebase-storage-ktx:21.0.0")
    // Google Play Services - Location + Tasks
    implementation("com.google.android.gms:play-services-location:21.3.0")
    implementation("com.google.android.gms:play-services-tasks:18.1.0")

    // Kotlin stdlib
    implementation("org.jetbrains.kotlin:kotlin-stdlib:2.1.0")
}
apply(plugin = "com.google.gms.google-services")

