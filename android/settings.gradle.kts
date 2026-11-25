pluginManagement {
    val flutterSdkPath = run {
        fun isValidFlutterSdk(path: String?): Boolean {
            if (path.isNullOrBlank()) return false
            return java.io.File(path, "packages/flutter_tools/gradle").exists()
        }

        val properties = java.util.Properties()
        val localPropertiesFile = file("local.properties")
        if (localPropertiesFile.exists()) {
            localPropertiesFile.inputStream().use { properties.load(it) }
        }

        val candidates = listOfNotNull(
            properties.getProperty("flutter.sdk"),
            System.getenv("FLUTTER_ROOT"),
            System.getenv("FLUTTER_HOME")
        )

        val resolved = candidates.firstOrNull { isValidFlutterSdk(it) }
            ?: run {
                val pathDirs = (System.getenv("PATH") ?: "")
                    .split(java.io.File.pathSeparator)
                    .filter { it.isNotBlank() }
                pathDirs.mapNotNull { dir ->
                    val binDir = java.io.File(dir)
                    val flutterBin = listOf("flutter", "flutter.bat")
                        .map { java.io.File(binDir, it) }
                        .firstOrNull { it.exists() }
                    flutterBin?.canonicalFile?.parentFile?.parentFile?.absolutePath
                }.firstOrNull { isValidFlutterSdk(it) }
            }

        require(resolved != null) {
            "Flutter SDK not found. Set flutter.sdk in android/local.properties or set FLUTTER_ROOT."
        }
        resolved
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.1" apply false
    id("org.jetbrains.kotlin.android") version "2.4.20" apply false
}

include(":app")
