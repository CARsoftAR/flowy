allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // Force Kotlin stdlib to a stable version — prevents transitive deps
    // from pulling kotlin-stdlib 2.2.0, which is incompatible with Flutter plugins
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "org.jetbrains.kotlin" &&
                requested.name.startsWith("kotlin-stdlib")) {
                useVersion("1.9.24")
                because("Prevent 2.2.0 stdlib breaking Flutter plugin compatibility")
            }
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
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
