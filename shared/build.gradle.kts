plugins {
    kotlin("multiplatform") version "1.9.24"
    kotlin("plugin.serialization") version "1.9.24"
    id("app.cash.sqldelight") version "2.0.2"
}

group = "com.nursify.shared"
version = "0.1.0"

repositories {
    google()
    mavenCentral()
}

val ktorVersion = "2.3.12"
val sqldelightVersion = "2.0.2"

kotlin {
    jvmToolchain(21)

    // JVM target exists purely so commonMain can be compiled/tested without a
    // Mac (Kotlin/Native's iOS targets can only link on macOS). The real
    // consumer is the iOS app; an Android target is a straightforward
    // addition once that phase starts (see REQUIREMENTS.md roadmap).
    jvm()

    iosArm64()
    iosSimulatorArm64()

    sourceSets {
        val commonMain by getting {
            dependencies {
                implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
                implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.3")
                implementation("io.ktor:ktor-client-core:$ktorVersion")
                implementation("io.ktor:ktor-client-content-negotiation:$ktorVersion")
                implementation("io.ktor:ktor-serialization-kotlinx-json:$ktorVersion")
                implementation("app.cash.sqldelight:runtime:$sqldelightVersion")
                implementation("app.cash.sqldelight:coroutines-extensions:$sqldelightVersion")
            }
        }
        val commonTest by getting {
            dependencies {
                implementation(kotlin("test"))
            }
        }
        val jvmMain by getting {
            dependencies {
                implementation("io.ktor:ktor-client-cio:$ktorVersion")
                implementation("app.cash.sqldelight:sqlite-driver:$sqldelightVersion")
            }
        }
        // Explicit intermediate source set (rather than relying on the
        // default hierarchy template, which needs opt-in on this Kotlin
        // version) shared by both iOS targets.
        val iosArm64Main by getting
        val iosSimulatorArm64Main by getting
        val iosMain by creating {
            dependsOn(commonMain)
            iosArm64Main.dependsOn(this)
            iosSimulatorArm64Main.dependsOn(this)
            dependencies {
                implementation("io.ktor:ktor-client-darwin:$ktorVersion")
                implementation("app.cash.sqldelight:native-driver:$sqldelightVersion")
            }
        }
    }
}

sqldelight {
    databases {
        create("NursifyDatabase") {
            packageName.set("com.nursify.shared.db")
        }
    }
}
