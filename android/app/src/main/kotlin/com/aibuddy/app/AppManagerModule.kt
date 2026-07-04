package com.aibuddy.app

import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/// App management helper for MainActivity — list/uninstall/query installed apps.
class AppManagerModule(private val activity: MainActivity) {

    private val channelName = "com.aibuddy.app/apps"

    fun register(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstalledApps" -> {
                    val includeSystem = call.argument<Boolean>("includeSystem") ?: false
                    result.success(getInstalledApps(includeSystem))
                }
                "getAppDetails" -> {
                    val packageName = call.argument<String>("packageName")?.trim().orEmpty()
                    result.success(getAppDetails(packageName))
                }
                "uninstallApp" -> {
                    val packageName = call.argument<String>("packageName")?.trim().orEmpty()
                    result.success(uninstallApp(packageName))
                }
                "openAppStore" -> {
                    val query = call.argument<String>("query")?.trim().orEmpty()
                    result.success(openAppStore(query))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getInstalledApps(includeSystem: Boolean): List<Map<String, Any>> {
        val pm = activity.packageManager
        val apps = mutableListOf<Map<String, Any>>()
        val packages = pm.getInstalledApplications(PackageManager.GET_META_DATA)

        for (appInfo in packages) {
            // Skip system apps unless requested
            if (!includeSystem && (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0) {
                continue
            }

            val label = pm.getApplicationLabel(appInfo).toString()
            val packageName = appInfo.packageName
            val version = try {
                pm.getPackageInfo(packageName, 0).versionName ?: "unknown"
            } catch (e: Exception) { "unknown" }

            val isSystem = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0

            apps.add(mapOf(
                "packageName" to packageName,
                "name" to label,
                "version" to version,
                "isSystem" to isSystem,
                "isEnabled" to appInfo.enabled,
            ))
        }

        apps.sortBy { it["name"].toString().lowercase(Locale.ROOT) }
        return apps
    }

    private fun getAppDetails(packageName: String): Map<String, Any>? {
        if (packageName.isEmpty()) return null
        val pm = activity.packageManager

        return try {
            val appInfo = pm.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
            val pkgInfo = pm.getPackageInfo(packageName, 0)
            val label = pm.getApplicationLabel(appInfo).toString()

            val isSystemDetail = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0

            mapOf(
                "packageName" to packageName,
                "name" to label,
                "version" to (pkgInfo.versionName ?: "unknown"),
                "versionCode" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    pkgInfo.longVersionCode
                } else {
                    @Suppress("DEPRECATION")
                    pkgInfo.versionCode.toLong()
                },
                "firstInstallTime" to pkgInfo.firstInstallTime,
                "lastUpdateTime" to pkgInfo.lastUpdateTime,
                "isSystem" to isSystemDetail,
                "isEnabled" to appInfo.enabled,
                "dataDir" to (appInfo.dataDir ?: ""),
                "targetSdk" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    appInfo.targetSdkVersion
                } else { 0 },
            )
        } catch (e: Exception) {
            Log.e("AppManager", "getAppDetails error: $e")
            null
        }
    }

    private fun uninstallApp(packageName: String): Boolean {
        if (packageName.isEmpty()) return false
        return try {
            val intent = Intent(Intent.ACTION_DELETE).apply {
                data = Uri.parse("package:$packageName")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            activity.startActivity(intent)
            true
        } catch (e: Exception) {
            Log.e("AppManager", "uninstallApp error: $e")
            false
        }
    }

    private fun openAppStore(query: String): Boolean {
        if (query.isEmpty()) return false
        return try {
            val intent = Intent(Intent.ACTION_VIEW).apply {
                // Try Play Store search first
                data = Uri.parse("https://play.google.com/store/search?q=${Uri.encode(query)}&c=apps")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            activity.startActivity(intent)
            true
        } catch (e: Exception) {
            Log.e("AppManager", "openAppStore error: $e")
            false
        }
    }
}
