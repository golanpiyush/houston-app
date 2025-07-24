package com.example.houston

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class HoustonInstaller(private val context: Context, flutterEngine: FlutterEngine) {

    companion object {
        private const val TAG = "HoustonInstaller"
        private const val CHANNEL_NAME = "apk_installer"
        private const val INSTALL_REQUEST_CODE = 1001
        private const val PERMISSION_CHECK_DELAY = 2000L // 2 seconds
    }

    private val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
    private val handler = Handler(Looper.getMainLooper())
    private var pendingInstallPath: String? = null

    init {
        channel.setMethodCallHandler { call, result ->
            Log.d(TAG, "Method called: ${call.method}")
            
            when (call.method) {
                "installApk" -> {
                    val apkPath = call.argument<String>("apkPath")
                    if (apkPath != null) {
                        try {
                            // Check permission first
                            if (!canInstallUnknownSources()) {
                                // Store the path for retry after permission is granted
                                pendingInstallPath = apkPath
                                result.error("PERMISSION_REQUIRED", "Install from unknown sources permission required", null)
                            } else {
                                installApk(apkPath)
                                result.success(true)
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Install failed", e)
                            result.error("INSTALL_FAILED", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "APK path is null", null)
                    }
                }
                
                "canInstallPackages" -> {
                    try {
                        val canInstall = canInstallUnknownSources()
                        Log.d(TAG, "Can install packages: $canInstall")
                        
                        // If permission was just granted and we have a pending install, trigger it
                        if (canInstall && pendingInstallPath != null) {
                            val pathToInstall = pendingInstallPath
                            pendingInstallPath = null
                            
                            // Delay slightly to ensure the permission change is fully processed
                            handler.postDelayed({
                                try {
                                    installApk(pathToInstall!!)
                                    // Notify Flutter that installation started
                                    channel.invokeMethod("installStarted", null)
                                } catch (e: Exception) {
                                    Log.e(TAG, "Auto-retry install failed", e)
                                    channel.invokeMethod("installFailed", e.message)
                                }
                            }, 500)
                        }
                        
                        result.success(canInstall)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error checking install permission", e)
                        result.success(false)
                    }
                }
                
                "openAppSettings" -> {
                    try {
                        openInstallPermissionSettings()
                        // Start periodic permission checking
                        startPermissionMonitoring()
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error opening settings", e)
                        result.error("SETTINGS_ERROR", e.message, null)
                    }
                }
                
                "getAppInfo" -> {
                    try {
                        val info = getAppInfo()
                        result.success(info)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error getting app info", e)
                        result.error("APP_INFO_ERROR", e.message, null)
                    }
                }
                
                else -> {
                    Log.w(TAG, "Method not implemented: ${call.method}")
                    result.notImplemented()
                }
            }
        }
    }

    private fun canInstallUnknownSources(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.packageManager.canRequestPackageInstalls()
        } else {
            // For older versions, check if unknown sources is enabled
            try {
                @Suppress("DEPRECATION")
                Settings.Secure.getInt(context.contentResolver, Settings.Secure.INSTALL_NON_MARKET_APPS) == 1
            } catch (e: Exception) {
                Log.w(TAG, "Could not check unknown sources setting", e)
                true // Assume it's enabled
            }
        }
    }

    private fun startPermissionMonitoring() {
        val checkPermission = object : Runnable {
            override fun run() {
                try {
                    val canInstall = canInstallUnknownSources()
                    Log.d(TAG, "Permission monitoring - Can install: $canInstall")
                    
                    if (canInstall && pendingInstallPath != null) {
                        val pathToInstall = pendingInstallPath
                        pendingInstallPath = null
                        
                        // Permission granted, proceed with installation
                        try {
                            installApk(pathToInstall!!)
                            channel.invokeMethod("permissionGrantedInstallStarted", null)
                        } catch (e: Exception) {
                            Log.e(TAG, "Auto-install after permission grant failed", e)
                            channel.invokeMethod("installFailed", e.message)
                        }
                    } else if (!canInstall && pendingInstallPath != null) {
                        // Still no permission, check again
                        handler.postDelayed(this, PERMISSION_CHECK_DELAY)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error in permission monitoring", e)
                }
            }
        }
        
        handler.postDelayed(checkPermission, PERMISSION_CHECK_DELAY)
    }

    private fun openInstallPermissionSettings() {
        try {
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                    data = Uri.parse("package:${context.packageName}")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
            } else {
                Intent(Settings.ACTION_SECURITY_SETTINGS).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
            }
            
            context.startActivity(intent)
            Log.d(TAG, "Opened install permission settings")
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open install permission settings", e)
            throw e
        }
    }

    private fun installApk(apkPath: String) {
        Log.d(TAG, "Starting APK installation: $apkPath")
        
        val apkFile = File(apkPath)
        if (!apkFile.exists()) {
            throw Exception("APK file not found at: $apkPath")
        }

        if (!apkFile.canRead()) {
            throw Exception("Cannot read APK file: $apkPath")
        }

        // Validate APK before installation (with better error handling)
        try {
            validateApk(apkFile)
        } catch (e: Exception) {
            Log.w(TAG, "APK validation had issues but continuing: ${e.message}")
            // Don't fail here - some validation errors are non-critical
        }

        // Check if this is a self-update scenario
        val isSelfUpdate = isSelfUpdateScenario(apkFile)
        Log.d(TAG, "Is self-update: $isSelfUpdate")

        // Try direct Intent installation first for better compatibility
        if (attemptDirectInstallation(apkFile)) {
            return
        }

        // Fall back to PackageInstaller with proper configuration
        Log.d(TAG, "Falling back to PackageInstaller API")
        performPackageInstallerInstallation(apkFile, isSelfUpdate)
    }

    private fun validateApk(apkFile: File): Boolean {
        try {
            val packageManager = context.packageManager
            
            // Use modern API for getting package info without deprecated flags
            val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageManager.getPackageArchiveInfo(
                    apkFile.absolutePath, 
                    PackageManager.GET_META_DATA
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageArchiveInfo(
                    apkFile.absolutePath, 
                    PackageManager.GET_SIGNATURES or PackageManager.GET_META_DATA
                )
            }
            
            if (packageInfo == null) {
                throw Exception("Invalid APK: Cannot read package info")
            }
            
            Log.d(TAG, "APK validation successful: ${packageInfo.packageName}, version: ${packageInfo.versionName}")
            return true
            
        } catch (e: Exception) {
            Log.e(TAG, "APK validation error (may be non-critical)", e)
            // Re-throw only for critical validation failures
            if (e.message?.contains("not a valid zip file") == true) {
                throw e
            }
            // For other validation issues, log but continue
            return false
        }
    }

    private fun isSelfUpdateScenario(apkFile: File): Boolean {
        return try {
            val packageManager = context.packageManager
            val apkPackageInfo = packageManager.getPackageArchiveInfo(
                apkFile.absolutePath, 
                0
            )
            
            apkPackageInfo?.packageName == context.packageName
        } catch (e: Exception) {
            Log.w(TAG, "Could not determine if self-update", e)
            false
        }
    }

    private fun attemptDirectInstallation(apkFile: File): Boolean {
        return try {
            Log.d(TAG, "Attempting direct Intent-based installation")
            
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                // Create a more robust FileProvider URI
                createFileProviderIntent(apkFile)
            } else {
                // For older versions, use file URI
                Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(Uri.fromFile(apkFile), "application/vnd.android.package-archive")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            }
            
            context.startActivity(intent)
            Log.d(TAG, "Direct installation intent started successfully")
            
            // Notify Flutter
            handler.post {
                channel.invokeMethod("installationStarted", mapOf(
                    "method" to "intent",
                    "message" to "System installer launched"
                ))
            }
            
            true
        } catch (e: Exception) {
            Log.w(TAG, "Direct installation failed, will try PackageInstaller", e)
            false
        }
    }

    private fun createFileProviderIntent(apkFile: File): Intent {
        // Try multiple approaches for FileProvider
        val possibleProviders = listOf(
            "${context.packageName}.fileprovider",
            "${context.packageName}.provider",
            "androidx.core.content.FileProvider"
        )
        
        for (provider in possibleProviders) {
            try {
                val apkUri = androidx.core.content.FileProvider.getUriForFile(
                    context,
                    provider,
                    apkFile
                )
                
                return Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(apkUri, "application/vnd.android.package-archive")
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            } catch (e: Exception) {
                Log.d(TAG, "Provider $provider failed: ${e.message}")
                continue
            }
        }
        
        // If all FileProvider attempts fail, try copying to external cache
        return createExternalCacheIntent(apkFile)
    }

    private fun createExternalCacheIntent(apkFile: File): Intent {
        // Copy APK to external cache directory which doesn't require FileProvider
        val externalCacheDir = context.externalCacheDir
        if (externalCacheDir != null && externalCacheDir.exists()) {
            val cachedApk = File(externalCacheDir, "update.apk")
            
            try {
                apkFile.copyTo(cachedApk, overwrite = true)
                
                return Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(Uri.fromFile(cachedApk), "application/vnd.android.package-archive")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            } catch (e: Exception) {
                Log.w(TAG, "Failed to copy to external cache", e)
            }
        }
        
        throw Exception("Could not create valid file URI for APK installation")
    }

    private fun performPackageInstallerInstallation(apkFile: File, isSelfUpdate: Boolean) {
        val packageInstaller = context.packageManager.packageInstaller
        
        // Configure session parameters based on update type
        val params = if (isSelfUpdate && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            // For self-updates, try to inherit existing install
            PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_INHERIT_EXISTING).apply {
                setAppPackageName(context.packageName)
            }
        } else {
            // For new installs or when inheritance fails
            PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
        }.apply {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                setInstallReason(PackageManager.INSTALL_REASON_USER)
            }
            // Install location is handled automatically by the system
        }

        var sessionId = -1
        var session: PackageInstaller.Session? = null

        try {
            sessionId = packageInstaller.createSession(params)
            Log.d(TAG, "Created PackageInstaller session: $sessionId")
            
            session = packageInstaller.openSession(sessionId)
            Log.d(TAG, "Opened PackageInstaller session")

            // Copy APK data to the session with progress tracking
            copyApkToSession(session, apkFile)

            // Create intent for the installation result
            val intent = Intent(context, AppInstallBroadcastReceiver::class.java).apply {
                action = "com.example.houston.INSTALL_COMPLETE"
                putExtra("apkPath", apkFile.absolutePath)
                putExtra("installMethod", "packageinstaller")
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                INSTALL_REQUEST_CODE,
                intent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
            )

            // Commit the session
            session.commit(pendingIntent.intentSender)
            Log.d(TAG, "PackageInstaller session committed successfully")

            // Notify Flutter about the installation progress
            handler.post {
                channel.invokeMethod("installationStarted", mapOf(
                    "method" to "packageinstaller",
                    "message" to "Package installer session committed"
                ))
            }

        } catch (e: Exception) {
            Log.e(TAG, "PackageInstaller installation failed", e)
            
            // Clean up session if it was created
            if (sessionId != -1) {
                try {
                    packageInstaller.abandonSession(sessionId)
                    Log.d(TAG, "Abandoned PackageInstaller session: $sessionId")
                } catch (cleanupException: Exception) {
                    Log.w(TAG, "Failed to abandon session: $sessionId", cleanupException)
                }
            }
            
            // Handle specific error types and try fallback
            handlePackageInstallerError(e, apkFile)
            
        } finally {
            try {
                session?.close()
                Log.d(TAG, "Closed PackageInstaller session")
            } catch (e: Exception) {
                Log.w(TAG, "Error closing PackageInstaller session", e)
            }
        }
    }

    private fun copyApkToSession(session: PackageInstaller.Session, apkFile: File) {
        FileInputStream(apkFile).use { inputStream ->
            session.openWrite("houston_app.apk", 0, apkFile.length()).use { outputStream ->
                val buffer = ByteArray(16384) // 16KB buffer
                var totalBytes = 0L
                var bytes: Int
                
                while (inputStream.read(buffer).also { bytes = it } != -1) {
                    outputStream.write(buffer, 0, bytes)
                    totalBytes += bytes
                    
                    // Optional: Report progress
                    if (totalBytes % (1024 * 1024) == 0L) { // Every MB
                        Log.d(TAG, "Copied ${totalBytes / (1024 * 1024)}MB / ${apkFile.length() / (1024 * 1024)}MB")
                    }
                }
                
                session.fsync(outputStream)
                Log.d(TAG, "Copied $totalBytes bytes to PackageInstaller session")
            }
        }
    }

    private fun handlePackageInstallerError(e: Exception, apkFile: File) {
        val errorMessage = e.message ?: ""
        
        when {
            errorMessage.contains("INSTALL_FAILED_INVALID_APK") -> {
                throw Exception("APK file is corrupted or has invalid signatures")
            }
            errorMessage.contains("signatures do not match") || 
            errorMessage.contains("INSTALL_FAILED_UPDATE_INCOMPATIBLE") -> {
                Log.w(TAG, "Signature mismatch detected, attempting fallback installation")
                // For signature mismatches, try direct installation as last resort
                try {
                    val fallbackIntent = createExternalCacheIntent(apkFile)
                    context.startActivity(fallbackIntent)
                    Log.d(TAG, "Fallback installation started")
                } catch (fallbackError: Exception) {
                    throw Exception("Installation failed due to signature mismatch. Please uninstall the existing app first.")
                }
            }
            errorMessage.contains("INSTALL_FAILED_INSUFFICIENT_STORAGE") -> {
                throw Exception("Insufficient storage space for installation")
            }
            errorMessage.contains("INSTALL_FAILED_VERSION_DOWNGRADE") -> {
                throw Exception("Cannot install older version over newer version")
            }
            else -> {
                throw Exception("Installation failed: $errorMessage")
            }
        }
    }

    private fun getAppInfo(): Map<String, Any> {
        try {
            val pm = context.packageManager
            val packageName = context.packageName
            val packageInfo = pm.getPackageInfo(packageName, 0)
            val applicationInfo = packageInfo.applicationInfo
                ?: throw IllegalStateException("ApplicationInfo is null")

            val appName = pm.getApplicationLabel(applicationInfo).toString()
            val versionName = packageInfo.versionName ?: "Unknown"
            val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageInfo.longVersionCode
            } else {
                @Suppress("DEPRECATION")
                packageInfo.versionCode.toLong()
            }

            return mapOf(
                "appName" to appName,
                "packageName" to packageName,
                "versionName" to versionName,
                "versionCode" to versionCode.toInt(),
                "targetSdkVersion" to applicationInfo.targetSdkVersion
            )
            
        } catch (e: Exception) {
            Log.e(TAG, "Error getting app info", e)
            throw e
        }
    }
}