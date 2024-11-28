package com.kumpali.mortgage

//import com.google.android.play.review.ReviewManager
//import com.google.android.play.core.review.ReviewManager;
//import com.google.android.play.core.review.ReviewManagerFactory;
//import com.google.android.gms.tasks.*;
//import android.app.Activity
//import android.os.Bundle
//import androidx.annotation.NonNull
import com.google.android.play.core.review.ReviewManagerFactory
import io.flutter.embedding.engine.FlutterEngine
//import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    private val channel = "mortgage"
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
