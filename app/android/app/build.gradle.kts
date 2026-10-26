import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing (docs/platform-setup.md): app/android/key.properties in
// Flutter's format, or, when that file is absent, the ANDROID_KEYSTORE_PATH /
// ANDROID_KEYSTORE_PASSWORD / ANDROID_KEY_ALIAS / ANDROID_KEY_PASSWORD
// environment variables (CI). With neither, release builds fall back to the
// debug key, with a warning, so `flutter run --release` works on a fresh clone.
// A half-filled configuration fails release builds (debug builds still work)
// instead of silently falling back.
// [names]: what the user sets for each value, used in error messages.
class ReleaseSigning(val source: String, val values: Map<String, String?>, val names: Map<String, String> = emptyMap()) {
    val missing: List<String> get() = values.filterValues { it.isNullOrBlank() }.keys.map { names[it] ?: it }
}

val releaseSigning: ReleaseSigning? = run {
    val keyPropertiesFile = rootProject.file("key.properties")
    if (keyPropertiesFile.isFile) {
        val properties = Properties().apply { keyPropertiesFile.inputStream().use { load(it) } }
        ReleaseSigning(
            keyPropertiesFile.path,
            listOf("storeFile", "storePassword", "keyAlias", "keyPassword").associateWith { properties.getProperty(it) },
        )
    } else {
        val variables = mapOf(
            "storeFile" to "ANDROID_KEYSTORE_PATH",
            "storePassword" to "ANDROID_KEYSTORE_PASSWORD",
            "keyAlias" to "ANDROID_KEY_ALIAS",
            "keyPassword" to "ANDROID_KEY_PASSWORD",
        )
        ReleaseSigning("the ANDROID_KEYSTORE_* environment variables", variables.mapValues { System.getenv(it.value) }, variables)
            .takeIf { it.missing.size < it.values.size }
    }
}

android {
    namespace = "dev.flutterpoc.field_inspections"
    // permission_handler_android needs 37; Flutter 3.47 defaults to 36.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications needs java.time on older Android.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.flutterpoc.field_inspections"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        // Patrol device tests (patrol_test/): native UI automation, one app
        // process per test with cleared data.
        testInstrumentationRunner = "pl.leancode.patrol.PatrolJUnitRunner"
        testInstrumentationRunnerArguments["clearPackageData"] = "true"
    }

    testOptions {
        execution = "ANDROIDX_TEST_ORCHESTRATOR"
    }

    signingConfigs {
        releaseSigning?.let { signing ->
            create("release") {
                // A relative storeFile resolves against app/android/app (Flutter's convention).
                signing.values["storeFile"]?.takeIf { it.isNotBlank() }?.let { storeFile = file(it) }
                storePassword = signing.values["storePassword"]
                keyAlias = signing.values["keyAlias"]
                keyPassword = signing.values["keyPassword"]
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (releaseSigning != null) "release" else "debug")
        }
    }
}

// Checked only when a release task runs, so a signing problem never breaks a
// debug build. `quiet` because `flutter build` runs Gradle with -q, which hides
// warn and lifecycle messages.
gradle.taskGraph.whenReady {
    if (allTasks.none { it.project == project && it.name.endsWith("Release") }) return@whenReady
    val signing = releaseSigning
    val keystore = signing?.values?.get("storeFile")?.takeIf { it.isNotBlank() }?.let { file(it) }
    when {
        signing == null -> logger.quiet(
            "WARNING: the release build is debug-signed: no app/android/key.properties and no ANDROID_KEYSTORE_* " +
                "environment variables. Fine for local testing, but it can't update a properly signed install and " +
                "Google Play rejects it. See docs/platform-setup.md.",
        )
        signing.missing.isNotEmpty() ->
            throw GradleException("Release signing: missing ${signing.missing.joinToString()} (from ${signing.source}).")
        keystore == null || !keystore.isFile ->
            throw GradleException("Release signing: keystore not found at ${keystore?.path} (from ${signing.source}).")
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // AppCompat launch theme so the biometric prompt works on Android 8 and below.
    implementation("androidx.appcompat:appcompat:1.7.1")
    androidTestUtil("androidx.test:orchestrator:1.5.1")
}
