plugins {
    alias(libs.plugins.android.application)
}

android {
    namespace = "com.rustvnt.vntapp"
    compileSdk {
        version = release(37)
    }

    defaultConfig {
        applicationId = "com.rustvnt.vntapp"
        minSdk = 24
        targetSdk = 37
        versionCode = providers.gradleProperty("vntVersionCode").orNull?.toInt() ?: 1
        versionName = providers.gradleProperty("vntVersionName").orNull ?: "1.0"
        resValue("string", "vnt_core_tag", providers.gradleProperty("vntCoreTag").orNull ?: "unknown")

        providers.gradleProperty("vntAbi").orNull?.let { requestedAbi ->
            ndk.abiFilters += requestedAbi
        }

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            optimization {
                enable = false
            }
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        resValues = true
    }

    packaging {
        jniLibs.useLegacyPackaging = false
    }
}

dependencies {
    implementation(libs.androidx.appcompat)
    implementation(libs.androidx.core.ktx)
    implementation(libs.material)
    implementation(libs.androidx.drawerlayout)
    implementation(libs.zxing.android.embedded)
    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(libs.androidx.junit)
}
