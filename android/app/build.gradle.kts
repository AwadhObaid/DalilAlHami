import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val dalilSigningProperties = Properties().apply {
    val propertiesFile = rootProject.file("key.properties")
    if (propertiesFile.exists()) {
        propertiesFile.inputStream().use { load(it) }
    }
}

val dalilSigningMode = (System.getenv("DALIL_SIGNING_MODE") ?: "app")
    .trim()
    .lowercase()

if (dalilSigningMode != "app" && dalilSigningMode != "upload") {
    throw org.gradle.api.GradleException(
        "DALIL_SIGNING_MODE must be either 'app' or 'upload'.",
    )
}

val dalilSigningStoreProperty =
    if (dalilSigningMode == "upload") "uploadStoreFile" else "appStoreFile"
val dalilSigningAliasProperty =
    if (dalilSigningMode == "upload") "uploadKeyAlias" else "appKeyAlias"
val dalilSigningStorePasswordEnv =
    if (dalilSigningMode == "upload") "DALIL_UPLOAD_STORE_PASSWORD" else "DALIL_APP_STORE_PASSWORD"
val dalilSigningKeyPasswordEnv =
    if (dalilSigningMode == "upload") "DALIL_UPLOAD_KEY_PASSWORD" else "DALIL_APP_KEY_PASSWORD"

val dalilSigningStoreFile = dalilSigningProperties.getProperty(dalilSigningStoreProperty)
val dalilSigningKeyAlias = dalilSigningProperties.getProperty(dalilSigningAliasProperty)
val dalilSigningStorePassword = System.getenv(dalilSigningStorePasswordEnv)
val dalilSigningKeyPassword =
    System.getenv(dalilSigningKeyPasswordEnv) ?: dalilSigningStorePassword

val dalilReleaseTaskRequested = gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true)
}

if (dalilReleaseTaskRequested) {
    val missingSigningInputs = mutableListOf<String>()

    if (dalilSigningStoreFile.isNullOrBlank()) {
        missingSigningInputs += "android/key.properties:$dalilSigningStoreProperty"
    }
    if (dalilSigningKeyAlias.isNullOrBlank()) {
        missingSigningInputs += "android/key.properties:$dalilSigningAliasProperty"
    }
    if (dalilSigningStorePassword.isNullOrBlank()) {
        missingSigningInputs += dalilSigningStorePasswordEnv
    }
    if (dalilSigningKeyPassword.isNullOrBlank()) {
        missingSigningInputs += dalilSigningKeyPasswordEnv
    }

    if (missingSigningInputs.isNotEmpty()) {
        throw org.gradle.api.GradleException(
            "Missing Dalil Al Hami release signing inputs: " +
                missingSigningInputs.joinToString(", "),
        )
    }
}

android {
    namespace = "com.awadhobaid.dalilalhami"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }


    defaultConfig {
        applicationId = "com.awadhobaid.dalilalhami"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        multiDexEnabled = true
        versionCode = flutter.versionCode.toInt()
        versionName = flutter.versionName
    }

    signingConfigs {
        create("production") {
            if (!dalilSigningStoreFile.isNullOrBlank()) {
                storeFile = rootProject.file(dalilSigningStoreFile)
            }
            if (!dalilSigningStorePassword.isNullOrBlank()) {
                storePassword = dalilSigningStorePassword
            }
            if (!dalilSigningKeyAlias.isNullOrBlank()) {
                keyAlias = dalilSigningKeyAlias
            }
            if (!dalilSigningKeyPassword.isNullOrBlank()) {
                keyPassword = dalilSigningKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("production")
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


dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
