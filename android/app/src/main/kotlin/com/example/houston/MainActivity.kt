package com.example.houston  // <-- Make sure this matches your manifest and package

import android.os.Bundle
import io.flutter.embedding.engine.FlutterEngine
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // No need to call GeneratedPluginRegistrant manually in new Flutter versions.
    }
}
