// bachfmt house style for Gradle projects (Kotlin DSL).
// Copy into build.gradle.kts next to `plugins { id("com.diffplug.spotless") }`.
spotless {
    java {
        // apply a specific flavor of google-java-format (AOSP: 4 spaces, 100 columns)
        googleJavaFormat().aosp().formatJavadoc(true).reorderImports(true)
        removeUnusedImports()
        // fix formatting of type annotations
        formatAnnotations()
    }
    kotlin {
        ktfmt().kotlinlangStyle()
    }
    kotlinGradle {
        ktfmt().kotlinlangStyle()
    }
}
