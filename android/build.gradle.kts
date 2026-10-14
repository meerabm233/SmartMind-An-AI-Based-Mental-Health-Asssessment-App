buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.0")
    }
}

allprojects {
    repositories {
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

// Some plugins (e.g. flutter_facebook_auth) don't declare an explicit Java/Kotlin
// JVM target, so they fall back to mismatched defaults (Java 1.8 vs. whatever JDK
// Gradle is running on) and fail with "Inconsistent JVM Target Compatibility".
// Force every *plugin* module to the same target the app itself uses (the app
// module already sets this in android/app/build.gradle.kts, and re-touching its
// already-finalized compileOptions from here throws, so it's excluded here).
subprojects {
    if (project.name == "app") return@subprojects
    // afterEvaluate: some plugins (e.g. flutter_webrtc) set their own
    // compileOptions inside their own build.gradle, which otherwise runs
    // after — and overwrites — the override below. Deferring to afterEvaluate
    // guarantees this runs last and actually wins.
    afterEvaluate {
        plugins.withId("com.android.library") {
            extensions.configure<com.android.build.gradle.LibraryExtension> {
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
        }
    }
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
