package com.kumpali.loanx

//import com.google.android.play.review.ReviewManager
//import com.google.android.play.core.review.ReviewManager;
//import com.google.android.play.core.review.ReviewManagerFactory;
//import com.google.android.gms.tasks.*;
//import android.app.Activity
//import android.os.Bundle
//import androidx.annotation.NonNull
//import android.content.Context
import com.google.android.play.core.review.ReviewManagerFactory
import io.flutter.embedding.engine.FlutterEngine
//import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import android.content.pm.PackageManager
import android.content.Intent
import android.provider.ContactsContract
//import com.google.android.play.core.appupdate.AppUpdateManagerFactory
//import com.google.android.play.core.appupdate.AppUpdateOptions
//import com.google.android.play.core.install.model.AppUpdateType
//import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    private val channel = "loanx"
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channel
        ).setMethodCallHandler { call, result ->
            if (call.method.equals("versionName")) {
                result.success(getAppVersionName())
            } else if (call.method.equals("versionCode")) {
                result.success(getAppVersionCode())
            } else if (call.method.equals("sdk")) {
                result.success(android.os.Build.VERSION.RELEASE)
            } else if (call.method.equals("openReview")) {
                openReview(result)
            } else if (call.method.equals("createContact")) {
                val name = call.argument<String>("name")?.trim().orEmpty()
                val phoneNumber = call.argument<String>("phoneNumber")?.trim().orEmpty()
                if (name.isEmpty() || phoneNumber.isEmpty()) {
                    result.error("INVALID_CONTACT", "A name and phone number are required.", null)
                } else {
                    createContact(name, phoneNumber, result)
                }
            }
            else {
                result.notImplemented()
            }
        }

    }

    private fun openReview(result: Result) {
        val manager = ReviewManagerFactory.create(this)
        val request = manager.requestReviewFlow()
        request.addOnCompleteListener { task ->
            if (task.isSuccessful) {
                val reviewInfo = task.result
                val flow = manager.launchReviewFlow(this, reviewInfo)
                flow.addOnCompleteListener { launchTask ->
                    if (launchTask.isSuccessful) {
                        result.success(null)
                    } else {
                        result.error("ERROR", "Review flow failed.", null)
                    }
                }
            } else {
                result.error("ERROR", "Request review flow failed.", null)
            }
        }
    }

    private fun createContact(name: String, phoneNumber: String, result: Result) {
        val intent = Intent(ContactsContract.Intents.Insert.ACTION).apply {
            type = ContactsContract.RawContacts.CONTENT_TYPE
            putExtra(ContactsContract.Intents.Insert.NAME, name)
            putExtra(ContactsContract.Intents.Insert.PHONE, phoneNumber)
            putExtra(
                ContactsContract.Intents.Insert.PHONE_TYPE,
                ContactsContract.CommonDataKinds.Phone.TYPE_MOBILE
            )
        }
        try {
            startActivity(intent)
            result.success(true)
        } catch (exception: Exception) {
            result.error("CONTACT_EDITOR_UNAVAILABLE", "No contact editor is available.", null)
        }
    }

//    private fun checkUpdate(context: Context){
//        val appUpdateManager = AppUpdateManagerFactory.create(context)
//
//// Returns an intent object that you use to check for an update.
//        val appUpdateInfoTask = appUpdateManager.appUpdateInfo
//
//// Checks that the platform will allow the specified type of update.
//        appUpdateInfoTask.addOnSuccessListener { appUpdateInfo ->
//            if (appUpdateInfo.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE
//                // This example applies an immediate update. To apply a flexible update
//                // instead, pass in AppUpdateType.FLEXIBLE
//                && appUpdateInfo.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE)
//            ) {
//                // Request the update.
//                appUpdateManager.startUpdateFlowForResult(
//                    // Pass the intent that is returned by 'getAppUpdateInfo()'.
//                    appUpdateInfo,
//                    // an activity result launcher registered via registerForActivityResult
//                    activityResultLauncher,
//                    // Or pass 'AppUpdateType.FLEXIBLE' to newBuilder() for
//                    // flexible updates.
//                    AppUpdateOptions.newBuilder(AppUpdateType.IMMEDIATE).build())
//            }
//        }
//    }

    private fun getAppVersionName(): String {
        return try {
            val packageInfo = packageManager.getPackageInfo(packageName, 0)
            packageInfo.versionName.toString()
        } catch (e: PackageManager.NameNotFoundException) {
            e.printStackTrace()
            "N/A"
        }
    }

    private fun getAppVersionCode(): Int {
        return try {
            val packageInfo = packageManager.getPackageInfo(
                packageName,
                0
            )
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                packageInfo.longVersionCode.toInt()
            } else {
                packageInfo.versionCode
            }
        } catch (e: PackageManager.NameNotFoundException) {
            e.printStackTrace()
            -1
        }
    }

}
