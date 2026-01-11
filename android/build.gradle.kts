buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Google Services plugin for Firebase
        classpath("com.google.gms:google-services:4.4.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Enforce JVM 17 for all projects after all plugins are evaluated
gradle.projectsEvaluated {
    allprojects {
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            kotlinOptions {
                jvmTarget = "17"
                freeCompilerArgs += listOf("-Xsuppress-version-warnings")
            }
        }
        
        // Suppress Java deprecation warnings for all subprojects
        tasks.withType<JavaCompile>().configureEach {
            options.compilerArgs.add("-Xlint:-deprecation")
        }
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

// Enforce NDK version and minSdk for all Android subprojects
// This ensures all plugins use NDK 27.0.12077973 and minSdk 21 (required by NDK 27)
subprojects {
    afterEvaluate {
        project.extensions.findByType<com.android.build.gradle.BaseExtension>()?.apply {
            ndkVersion = "27.0.12077973"
            // Ensure minSdk is at least 21 for NDK 27 compatibility
            val currentMinSdk = defaultConfig.minSdkVersion?.apiLevel ?: 0
            if (currentMinSdk < 21) {
                defaultConfig.minSdk = 21
            }
            
            // Enforce Java 17 for all subprojects to match Kotlin JVM target
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
        
        // Also configure Kotlin JVM target to match Java for all plugins
        project.tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            kotlinOptions {
                jvmTarget = "17"
            }
        }
        
        // Configure Kotlin JVM options for Android extensions
        project.extensions.findByType<org.jetbrains.kotlin.gradle.dsl.KotlinJvmOptions>()?.apply {
            jvmTarget = "17"
        }
        
        // Also configure Kotlin Android extensions
        project.extensions.findByType<org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension>()?.apply {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
