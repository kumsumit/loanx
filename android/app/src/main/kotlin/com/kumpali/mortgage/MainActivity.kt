```kotlin
package com.kumpali.loanx

import android.app.ActivityManager
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.provider.ContactsContract
import android.telephony.TelephonyManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterShellArgs
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import com.google.android.play.core.review.ReviewManagerFactory
import java.util.Locale
import java.util.TimeZone

class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val CHANNEL = "loanx"

        /*
         * Performance tiers are primarily for Flutter-side UI adaptation.
         *
         * IMPORTANT:
         * A low performance tier does NOT automatically mean software
         * rendering. Hardware acceleration is still preferred whenever the
         * device is capable of using it safely.
         */
        private const val TIER_ULTRA = "ULTRA"
        private const val TIER_HIGH = "HIGH"
        private const val TIER_STANDARD = "STANDARD"
        private const val TIER_SAFE = "SAFE"
    }

    /**
     * Device capabilities are calculated once for the activity.
     */
    private val capabilities: DeviceCapabilities by lazy {
        inspectDeviceCapabilities()
    }

    /**
     * Decide whether this particular device should use Flutter software
     * rendering.
     *
     * This is intentionally conservative.
     *
     * We DO NOT disable hardware rendering merely because a device is old,
     * 32-bit, has low RAM, or has a weak CPU.
     *
     * Hardware rendering is generally preferred. Software rendering is
     * reserved for configurations where GPU rendering is more likely to be
     * unsafe/problematic.
     */
    private val needsSoftwareRendering: Boolean
        get() {
            /*
             * Explicit compatibility exceptions come first.
             *
             * Add devices here only when real crash telemetry demonstrates
             * that their GPU/rendering stack is problematic.
             */
            if (isKnownProblematicGraphicsDevice()) {
                return true
            }

            /*
             * Very old 32-bit low-RAM Android devices are the final safety
             * fallback. We do NOT apply this rule to all old devices.
             */
            return capabilities.isExtremelyConstrained
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        /*
         * IMPORTANT:
         *
         * The manifest intentionally keeps android:hardwareAccelerated="false"
         * so we can selectively enable it here.
         *
         * Android only allows hardware acceleration to be enabled
         * programmatically. It cannot later be disabled when it was already
         * enabled through the manifest.
         */
        if (needsSoftwareRendering) {

            /*
             * Tell the Flutter engine to use software rendering on this
             * specific compatibility configuration.
             */
            intent.putExtra(
                FlutterShellArgs.ARG_KEY_ENABLE_SOFTWARE_RENDERING,
                true
            )

            /*
             * Do not request Impeller on this fallback configuration.
             *
             * Flutter itself normally handles renderer selection on modern
             * Android devices.
             */
            intent.putExtra(
                FlutterShellArgs.ARG_KEY_TOGGLE_IMPELLER,
                false
            )

        } else {

            /*
             * Enable Android window hardware acceleration before Flutter
             * creates its content view.
             */
            window.addFlags(
                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED
            )
        }

        super.onCreate(savedInstanceState)
    }

    /**
     * SurfaceView is the preferred Flutter render mode.
     *
     * Flutter documents SurfaceView as significantly better for performance
     * than TextureView. TextureView should mainly be used when an Android
     * View must be interleaved with Flutter content or other special
     * composition requirements exist.
     */
    override fun getRenderMode(): RenderMode {
        return RenderMode.surface
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "versionName" -> {
                    result.success(getAppVersionName())
                }

                "versionCode" -> {
                    result.success(getAppVersionCode())
                }

                "sdk" -> {
                    result.success(Build.VERSION.RELEASE)
                }

                "deviceCapabilities" -> {
                    result.success(deviceCapabilities())
                }

                "countrySignals" -> {
                    result.success(countrySignals())
                }

                "openReview" -> {
                    openReview(result)
                }

                "createContact" -> {
                    val name =
                        call.argument<String>("name")
                            ?.trim()
                            .orEmpty()

                    val phoneNumber =
                        call.argument<String>("phoneNumber")
                            ?.trim()
                            .orEmpty()

                    if (name.isEmpty() || phoneNumber.isEmpty()) {
                        result.error(
                            "INVALID_CONTACT",
                            "A name and phone number are required.",
                            null
                        )
                    } else {
                        createContact(
                            name = name,
                            phoneNumber = phoneNumber,
                            result = result
                        )
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    /**
     * Describes the Android device/network environment.
     */
    private fun countrySignals(): Map<String, String> {

        val telephony =
            getSystemService(TELEPHONY_SERVICE) as? TelephonyManager

        return mapOf(
            "deviceCountry" to Locale.getDefault().country,
            "simCountry" to (telephony?.simCountryIso ?: ""),
            "networkCountry" to (telephony?.networkCountryIso ?: ""),
            "timezone" to TimeZone.getDefault().id
        )
    }

    /**
     * Detailed capability information exposed to Flutter.
     *
     * This is intentionally richer than the previous implementation so the
     * Dart layer can make better decisions about UI complexity and runtime
     * performance.
     */
    private fun deviceCapabilities(): Map<String, Any> {

        val c = capabilities

        return mapOf(
            // Basic Android information
            "isAndroid" to true,
            "sdkInt" to c.sdkInt,
            "androidRelease" to Build.VERSION.RELEASE,

            // Device identity
            "manufacturer" to c.manufacturer,
            "brand" to c.brand,
            "model" to c.model,
            "device" to c.device,
            "product" to c.product,
            "board" to c.board,

            // CPU / ABI
            "cpuCores" to c.cpuCores,
            "supports64Bit" to c.supports64Bit,
            "supportedAbis" to c.supportedAbis,
            "supported32BitAbis" to c.supported32BitAbis,
            "supported64BitAbis" to c.supported64BitAbis,

            // Memory
            "memoryClassMb" to c.memoryClassMb,
            "isLowRamDevice" to c.isLowRamDevice,

            // Graphics
            "openGlEsVersion" to c.openGlEsVersion,
            "openGlEsMajor" to c.openGlEsMajor,
            "supportsVulkan" to c.supportsVulkan,

            // Rendering decision
            "hardwareAccelerationEnabled" to !needsSoftwareRendering,
            "softwareRenderingFallback" to needsSoftwareRendering,

            // Capability classification
            "performanceTier" to c.performanceTier,

            // Compatibility information
            "knownProblematicGraphicsDevice" to
                isKnownProblematicGraphicsDevice(),

            "extremelyConstrainedDevice" to
                c.isExtremelyConstrained
        )
    }

    /**
     * Inspect the device and classify its general performance capability.
     *
     * This classification is NOT the same thing as the renderer decision.
     *
     * For example:
     *
     * HIGH + softwareRenderingFallback=false
     *     -> hardware renderer + rich UI
     *
     * STANDARD + softwareRenderingFallback=false
     *     -> hardware renderer + optimized UI
     *
     * SAFE + softwareRenderingFallback=true
     *     -> software renderer + minimal effects
     */
    private fun inspectDeviceCapabilities(): DeviceCapabilities {

        val activityManager =
            getSystemService(ACTIVITY_SERVICE) as ActivityManager

        val memoryClassMb =
            activityManager.memoryClass

        val isLowRamDevice =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                activityManager.isLowRamDevice
            } else {
                false
            }

        val cpuCores =
            Runtime.getRuntime().availableProcessors()

        val supported32BitAbis =
            Build.SUPPORTED_32_BIT_ABIS.toList()

        val supported64BitAbis =
            Build.SUPPORTED_64_BIT_ABIS.toList()

        val supports64Bit =
            supported64BitAbis.isNotEmpty()

        val supportedAbis =
            Build.SUPPORTED_ABIS.toList()

        val glEsVersion =
            activityManager.deviceConfigurationInfo.reqGlEsVersion

        val openGlEsMajor =
            (glEsVersion shr 16) and 0xffff

        val openGlEsMinor =
            glEsVersion and 0xffff

        val openGlEsVersion =
            "$openGlEsMajor.$openGlEsMinor"

        val supportsVulkan =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                packageManager.hasSystemFeature(
                    PackageManager.FEATURE_VULKAN_HARDWARE_LEVEL
                )
            } else {
                false
            }

        /*
         * This is deliberately conservative.
         *
         * We are not saying that every device matching these conditions is
         * "bad". We are simply identifying an extremely constrained class
         * where a safer Flutter rendering configuration may be appropriate.
         */
        val isExtremelyConstrained =
            Build.VERSION.SDK_INT <= Build.VERSION_CODES.N_MR1 &&
            !supports64Bit &&
            (
                isLowRamDevice ||
                memoryClassMb <= 128 ||
                cpuCores <= 2
            )

        val performanceTier =
            when {

                /*
                 * Modern, powerful devices.
                 */
                supports64Bit &&
                memoryClassMb >= 512 &&
                cpuCores >= 8 &&
                openGlEsMajor >= 3 &&
                supportsVulkan -> TIER_ULTRA

                /*
                 * Strong devices.
                 */
                supports64Bit &&
                memoryClassMb >= 256 &&
                cpuCores >= 6 &&
                openGlEsMajor >= 3 -> TIER_HIGH

                /*
                 * Normal devices.
                 */
                memoryClassMb >= 192 &&
                cpuCores >= 4 &&
                openGlEsMajor >= 2 -> TIER_STANDARD

                /*
                 * Extremely limited devices.
                 */
                else -> TIER_SAFE
            }

        return DeviceCapabilities(
            sdkInt = Build.VERSION.SDK_INT,

            manufacturer = Build.MANUFACTURER,
            brand = Build.BRAND,
            model = Build.MODEL,
            device = Build.DEVICE,
            product = Build.PRODUCT,
            board = Build.BOARD,

            cpuCores = cpuCores,

            supports64Bit = supports64Bit,
            supportedAbis = supportedAbis,
            supported32BitAbis = supported32BitAbis,
            supported64BitAbis = supported64BitAbis,

            memoryClassMb = memoryClassMb,
            isLowRamDevice = isLowRamDevice,

            openGlEsVersion = openGlEsVersion,
            openGlEsMajor = openGlEsMajor,

            supportsVulkan = supportsVulkan,

            isExtremelyConstrained = isExtremelyConstrained,

            performanceTier = performanceTier
        )
    }

    /**
     * Add known graphics compatibility exceptions here.
     *
     * IMPORTANT:
     *
     * Do not populate this with broad manufacturer/model rules without
     * evidence from actual crash telemetry.
     *
     * The goal is to isolate genuinely problematic graphics stacks without
     * degrading all devices of a manufacturer.
     */
    private fun isKnownProblematicGraphicsDevice(): Boolean {

        val manufacturer =
            Build.MANUFACTURER
                .trim()
                .lowercase(Locale.US)

        val model =
            Build.MODEL
                .trim()
                .lowercase(Locale.US)

        /*
         * Your previously observed Samsung J250 / Android 7.1.1 type crash
         * is precisely the sort of device that can be placed here after
         * confirming the exact production model.
         *
         * Keep this narrow rather than disabling GPU rendering for all
         * Samsung Android 7 devices.
         */
        if (
            manufacturer == "samsung" &&
            (
                model.contains("sm-j250") ||
                model.contains("j250")
            ) &&
            Build.VERSION.SDK_INT <= Build.VERSION_CODES.N_MR1
        ) {
            return true
        }

        return false
    }

    /**
     * Launch Google Play's in-app review flow.
     */
    private fun openReview(result: Result) {

        val manager =
            ReviewManagerFactory.create(this)

        val request =
            manager.requestReviewFlow()

        request.addOnCompleteListener { task ->

            if (task.isSuccessful) {

                val reviewInfo =
                    task.result

                val flow =
                    manager.launchReviewFlow(
                        this,
                        reviewInfo
                    )

                flow.addOnCompleteListener { launchTask ->

                    if (launchTask.isSuccessful) {
                        result.success(null)
                    } else {
                        result.error(
                            "ERROR",
                            "Review flow failed.",
                            null
                        )
                    }
                }

            } else {

                result.error(
                    "ERROR",
                    "Request review flow failed.",
                    null
                )
            }
        }
    }

    /**
     * Open the native Android contact editor.
     */
    private fun createContact(
        name: String,
        phoneNumber: String,
        result: Result
    ) {

        val intent =
            Intent(
                ContactsContract.Intents.Insert.ACTION
            ).apply {

                type =
                    ContactsContract.RawContacts.CONTENT_TYPE

                putExtra(
                    ContactsContract.Intents.Insert.NAME,
                    name
                )

                putExtra(
                    ContactsContract.Intents.Insert.PHONE,
                    phoneNumber
                )

                putExtra(
                    ContactsContract.Intents.Insert.PHONE_TYPE,
                    ContactsContract.CommonDataKinds.Phone.TYPE_MOBILE
                )
            }

        try {

            startActivity(intent)

            result.success(true)

        } catch (exception: Exception) {

            result.error(
                "CONTACT_EDITOR_UNAVAILABLE",
                "No contact editor is available.",
                null
            )
        }
    }

    private fun getAppVersionName(): String {

        return try {

            val packageInfo =
                packageManager.getPackageInfo(
                    packageName,
                    0
                )

            packageInfo.versionName ?: "N/A"

        } catch (e: PackageManager.NameNotFoundException) {

            e.printStackTrace()

            "N/A"
        }
    }

    private fun getAppVersionCode(): Int {

        return try {

            val packageInfo =
                packageManager.getPackageInfo(
                    packageName,
                    0
                )

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {

                packageInfo.longVersionCode.toInt()

            } else {

                @Suppress("DEPRECATION")
                packageInfo.versionCode
            }

        } catch (e: PackageManager.NameNotFoundException) {

            e.printStackTrace()

            -1
        }
    }

    /**
     * Internal device capability model.
     */
    private data class DeviceCapabilities(

        val sdkInt: Int,

        val manufacturer: String,
        val brand: String,
        val model: String,
        val device: String,
        val product: String,
        val board: String,

        val cpuCores: Int,

        val supports64Bit: Boolean,
        val supportedAbis: List<String>,
        val supported32BitAbis: List<String>,
        val supported64BitAbis: List<String>,

        val memoryClassMb: Int,
        val isLowRamDevice: Boolean,

        val openGlEsVersion: String,
        val openGlEsMajor: Int,

        val supportsVulkan: Boolean,

        val isExtremelyConstrained: Boolean,

        val performanceTier: String
    )
}
```
