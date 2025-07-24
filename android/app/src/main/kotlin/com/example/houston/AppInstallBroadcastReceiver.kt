package com.example.houston

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.util.Log
import android.widget.Toast

class AppInstallBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return
        
        when (intent.action) {
            "com.example.houston.INSTALL_COMPLETE" -> {
                val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, -1)
                val message = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
                
                when (status) {
                    PackageInstaller.STATUS_SUCCESS -> {
                        Log.d("HoustonInstaller", "Installation successful")
                        Toast.makeText(context, "🚀 Houston updated successfully!", Toast.LENGTH_LONG).show()
                        
                        // Optionally restart the app
                        val restartIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                        restartIntent?.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_NEW_TASK)
                        context.startActivity(restartIntent)
                    }
                    
                    PackageInstaller.STATUS_FAILURE -> {
                        Log.e("HoustonInstaller", "Installation failed: $message")
                        Toast.makeText(context, "❌ Installation failed: $message", Toast.LENGTH_LONG).show()
                    }
                    
                    PackageInstaller.STATUS_FAILURE_ABORTED -> {
                        Log.e("HoustonInstaller", "Installation aborted by user")
                        Toast.makeText(context, "⚠️ Installation cancelled", Toast.LENGTH_SHORT).show()
                    }
                    
                    PackageInstaller.STATUS_FAILURE_BLOCKED -> {
                        Log.e("HoustonInstaller", "Installation blocked: $message")
                        Toast.makeText(context, "🚫 Installation blocked: $message", Toast.LENGTH_LONG).show()
                    }
                    
                    PackageInstaller.STATUS_FAILURE_CONFLICT -> {
                        Log.e("HoustonInstaller", "Installation conflict: $message")
                        Toast.makeText(context, "⚠️ Installation conflict: $message", Toast.LENGTH_LONG).show()
                    }
                    
                    PackageInstaller.STATUS_FAILURE_INCOMPATIBLE -> {
                        Log.e("HoustonInstaller", "Installation incompatible: $message")
                        Toast.makeText(context, "❌ App incompatible: $message", Toast.LENGTH_LONG).show()
                    }
                    
                    PackageInstaller.STATUS_FAILURE_INVALID -> {
                        Log.e("HoustonInstaller", "Installation invalid: $message")
                        Toast.makeText(context, "❌ Invalid APK: $message", Toast.LENGTH_LONG).show()
                    }
                    
                    PackageInstaller.STATUS_FAILURE_STORAGE -> {
                        Log.e("HoustonInstaller", "Installation storage error: $message")
                        Toast.makeText(context, "💾 Storage error: $message", Toast.LENGTH_LONG).show()
                    }
                    
                    PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                        Log.d("HoustonInstaller", "Waiting for user confirmation")
                        // The system will show the installation prompt
                        val confirmIntent = intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)
                        if (confirmIntent != null) {
                            confirmIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            context.startActivity(confirmIntent)
                        }
                    }
                    
                    else -> {
                        Log.w("HoustonInstaller", "Unknown installation status: $status, message: $message")
                        Toast.makeText(context, "⚠️ Unknown installation status", Toast.LENGTH_SHORT).show()
                    }
                }
            }
        }
    }
}