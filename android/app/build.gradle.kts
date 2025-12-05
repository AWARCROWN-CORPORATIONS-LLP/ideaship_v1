plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
   id("com.google.gms.google-services")
}

android {
    namespace = "com.awarcrown.ideaship"
    compileSdkVersion(flutter.compileSdkVersion)
    buildToolsVersion = "34.0.0"
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    lint {
        abortOnError = false
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }
defaultConfig {
    applicationId = "com.awarcrown.ideaship"
    minSdk = 23
    targetSdk = 34
    versionCode = 1
    versionName = "1.0"
    multiDexEnabled=true
    testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
}



    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8:1.9.23")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    implementation(platform("com.google.firebase:firebase-bom:34.4.0"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-messaging")
    implementation("androidx.multidex:multidex:2.0.1")
    implementation("com.google.android.gms:play-services-base:18.2.0")
    implementation("com.google.android.gms:play-services-maps:18.1.0")
    implementation("com.google.android.gms:play-services-location:21.0.1")
    

}
