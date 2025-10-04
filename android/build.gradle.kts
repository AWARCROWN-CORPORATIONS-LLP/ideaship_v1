allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    evaluationDependsOn(":app") // This line is often used in multi-project builds to ensure that the ':app' project is evaluated before other subprojects.
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
