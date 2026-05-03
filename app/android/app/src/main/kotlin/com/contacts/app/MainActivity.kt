package com.contacts.app

import android.content.Context
import android.content.Intent
import android.telecom.TelecomManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import android.net.Uri
import android.telecom.TelecomManager.ACTION_CHANGE_DEFAULT_DIALER

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.contacts.app/calling"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Cache the engine
        FlutterEngineCache.getInstance().put("main_engine", flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "makeCall" -> {
                    val number = call.argument<String>("number")
                    if (number != null) {
                        makeCall(number)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGS", "Number is null", null)
                    }
                }
                "isDefaultDialer" -> {
                    val telecomManager = getSystemService(Context.TELECOM_SERVICE) as TelecomManager
                    val packageName = packageName
                    val isDefault = telecomManager.defaultDialerPackage == packageName
                    result.success(isDefault)
                }
                "requestDefaultDialer" -> {
                    val intent = Intent(TelecomManager.ACTION_CHANGE_DEFAULT_DIALER).apply {
                        putExtra(TelecomManager.EXTRA_CHANGE_DEFAULT_DIALER_PACKAGE_NAME, packageName)
                    }
                    startActivity(intent)
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun makeCall(number: String) {
        val uri = Uri.fromParts("tel", number, null)
        
        // Ensure we have permission
        if (checkSelfPermission(android.Manifest.permission.CALL_PHONE) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
             val intent = Intent(Intent.ACTION_DIAL, uri).apply {
                 addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
             }
             startActivity(intent)
             return
        }

        try {
            // Using ACTION_CALL directly to "land at the calling page"
            val intent = Intent(Intent.ACTION_CALL, uri).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
        } catch (e: Exception) {
            val intent = Intent(Intent.ACTION_DIAL, uri).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
        }
    }
}
