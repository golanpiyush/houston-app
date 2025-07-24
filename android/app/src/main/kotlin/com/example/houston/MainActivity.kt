package com.example.houston

import android.os.Bundle
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity
import android.media.AudioManager
import android.media.MediaPlayer
import android.content.Context
import android.util.Log

class MainActivity : AudioServiceActivity() {
    private val TAG = "MainActivity"
    
    private lateinit var audioEffectsManager: AudioEffectsManager
    private var audioSessionId: Int = 0
    private var mediaPlayer: MediaPlayer? = null
    private lateinit var houstonInstaller: HoustonInstaller  // Add this line
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize AudioEffectsManager
        audioEffectsManager = AudioEffectsManager(this)
        houstonInstaller = HoustonInstaller(this, flutterEngine)
        
        // Set up method channel for Flutter communication
         MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.houston/audio_effects").setMethodCallHandler { call, result ->
        // Handle method calls here
            when (call.method) {
                "initializeEffects" -> {
                    val sessionId = call.argument<Int>("sessionId") ?: 0
                    audioSessionId = sessionId
                    val success = audioEffectsManager.initialize(sessionId, mediaPlayer)
                    result.success(success)
                }


                        
                "updateMediaPlayer" -> {
                    // Allow Flutter to notify when MediaPlayer is available
                    val sessionId = call.argument<Int>("sessionId") ?: audioSessionId
                    // In a real implementation, you'd get the MediaPlayer reference from your audio service
                    audioEffectsManager.updateMediaPlayer(mediaPlayer)
                    result.success(true)
                }
                
                "setBassBoost" -> {
                    val strength = call.argument<Int>("strength")?.toShort() ?: 0
                    val success = audioEffectsManager.setBassBoost(strength)
                    result.success(success)
                }
                
                "getBassBoost" -> {
                    val value = audioEffectsManager.getBassBoost()
                    result.success(value.toInt())
                }
                
                // Audio Balance methods
                "setAudioBalance" -> {
                    val balance = call.argument<Double>("balance")?.toFloat() ?: 0.5f
                    val success = audioEffectsManager.setAudioBalance(balance)
                    result.success(success)
                }
                
                "getAudioBalance" -> {
                    val value = audioEffectsManager.getAudioBalance()
                    result.success(value.toDouble())
                }
                
                "setAudioBalancePercentage" -> {
                    val percentage = call.argument<Int>("percentage") ?: 50
                    val success = audioEffectsManager.setAudioBalancePercentage(percentage)
                    result.success(success)
                }
                
                "getAudioBalancePercentage" -> {
                    val value = audioEffectsManager.getAudioBalancePercentage()
                    result.success(value)
                }
                
                "resetAudioBalance" -> {
                    val success = audioEffectsManager.resetAudioBalance()
                    result.success(success)
                }
                
                "isAudioBalanceSupported" -> {
                    val supported = audioEffectsManager.isAudioBalanceSupported()
                    result.success(supported)
                }
                
                // Equalizer methods
                "setEqualizerBand" -> {
                    val band = call.argument<Int>("band") ?: 0
                    val level = call.argument<Int>("level")?.toShort() ?: 0
                    val success = audioEffectsManager.setEqualizerBand(band, level)
                    result.success(success)
                }
                
                "getEqualizerBand" -> {
                    val band = call.argument<Int>("band") ?: 0
                    val value = audioEffectsManager.getEqualizerBand(band)
                    result.success(value.toInt())
                }
                
                "getEqualizerBandCount" -> {
                    val count = audioEffectsManager.getEqualizerBandCount()
                    result.success(count)
                }
                
                "getEqualizerBandFreq" -> {
                    val band = call.argument<Int>("band") ?: 0
                    val freq = audioEffectsManager.getEqualizerBandFreq(band)
                    result.success(freq)
                }
                
                // Loudness Enhancer methods
                "setLoudnessEnhancer" -> {
                    val gain = call.argument<Int>("gain") ?: 0
                    val success = audioEffectsManager.setLoudnessEnhancer(gain)
                    result.success(success)
                }
                
                "getLoudnessEnhancer" -> {
                    val value = audioEffectsManager.getLoudnessEnhancer()
                    result.success(value)
                }
                
                // Environmental Reverb methods (simplified percentage-based)
                "setEnvironmentalReverbLevel" -> {
                    val level = call.argument<Int>("level") ?: 0
                    val success = audioEffectsManager.setEnvironmentalReverbLevel(level)
                    result.success(success)
                }
                
                "getEnvironmentalReverbLevel" -> {
                    val value = audioEffectsManager.getEnvironmentalReverbLevel()
                    result.success(value)
                }
                
                // Environmental Reverb methods (detailed parameters)
                "setEnvironmentalReverb" -> {
                    val roomLevel = call.argument<Int>("roomLevel")?.toShort() ?: -1000
                    val roomHFLevel = call.argument<Int>("roomHFLevel")?.toShort() ?: -100
                    val decayTime = call.argument<Int>("decayTime") ?: 1490
                    val decayHFRatio = call.argument<Int>("decayHFRatio")?.toShort() ?: 830
                    val reflectionsLevel = call.argument<Int>("reflectionsLevel")?.toShort() ?: -2602
                    val reflectionsDelay = call.argument<Int>("reflectionsDelay") ?: 7
                    val reverbLevel = call.argument<Int>("reverbLevel")?.toShort() ?: 200
                    val reverbDelay = call.argument<Int>("reverbDelay") ?: 11
                    val diffusion = call.argument<Int>("diffusion")?.toShort() ?: 1000
                    val density = call.argument<Int>("density")?.toShort() ?: 1000
                    
                    val success = audioEffectsManager.setEnvironmentalReverb(
                        roomLevel, roomHFLevel, decayTime, decayHFRatio,
                        reflectionsLevel, reflectionsDelay, reverbLevel, reverbDelay,
                        diffusion, density
                    )
                    result.success(success)
                }
                
                // Preset methods
                "applyPreset" -> {
                    val presetName = call.argument<String>("presetName") ?: "Normal"
                    val success = audioEffectsManager.applyPreset(presetName)
                    result.success(success)
                }
                
                "getAvailablePresets" -> {
                    val presets = audioEffectsManager.getAvailablePresets()
                    result.success(presets)
                }
                
                // Master control methods
                "enableAllEffects" -> {
                    val success = audioEffectsManager.enableAllEffects()
                    result.success(success)
                }
                
                "disableAllEffects" -> {
                    val success = audioEffectsManager.disableAllEffects()
                    result.success(success)
                }
                
                "resetAllEffects" -> {
                    val success = audioEffectsManager.resetAllEffects()
                    result.success(success)
                }
                
                // Support checking methods
                "isEffectSupported" -> {
                    val effectType = call.argument<String>("effectType") ?: ""
                    val supported = audioEffectsManager.isEffectSupported(effectType)
                    result.success(supported)
                }
                
                // Settings and info methods
                "getCurrentSettings" -> {
                    val settings = audioEffectsManager.getCurrentSettings()
                    result.success(settings)
                }
                
                "getSafeLimits" -> {
                    val limits = mapOf(
                        "bassBoostLimit" to AudioEffectsManager.SAFE_BASS_BOOST_LIMIT,
                        "loudnessLimit" to AudioEffectsManager.SAFE_LOUDNESS_LIMIT,
                        "eqBandLimit" to AudioEffectsManager.SAFE_EQ_BAND_LIMIT,
                        "dangerLoudnessThreshold" to AudioEffectsManager.DANGER_LOUDNESS_THRESHOLD,
                        "minBalance" to AudioEffectsManager.MIN_BALANCE,
                        "maxBalance" to AudioEffectsManager.MAX_BALANCE,
                        "centerBalance" to AudioEffectsManager.CENTER_BALANCE
                    )
                    result.success(limits)
                }
                
                "getAudioSessionId" -> {
                    result.success(audioSessionId)
                }
                
                // Debug/utility methods
                "createTestMediaPlayer" -> {
                    // For testing audio balance - creates a dummy MediaPlayer
                    try {
                        mediaPlayer?.release()
                        mediaPlayer = MediaPlayer().apply {
                            // Set a dummy data source or prepare for testing
                            // In real usage, this would be your actual audio player
                        }
                        audioEffectsManager.updateMediaPlayer(mediaPlayer)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error creating test MediaPlayer: ${e.message}")
                        result.success(false)
                    }
                }
                
                "releaseTestMediaPlayer" -> {
                    try {
                        mediaPlayer?.release()
                        mediaPlayer = null
                        audioEffectsManager.updateMediaPlayer(null)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error releasing test MediaPlayer: ${e.message}")
                        result.success(false)
                    }
                }
                
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Set up audio session ID from AudioManager
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audioSessionId = audioManager.generateAudioSessionId()
        
        Log.d(TAG, "MainActivity created with audio session ID: $audioSessionId")
    }
    
    override fun onDestroy() {
        super.onDestroy()
        
        // Clean up audio effects and media player
        try {
            mediaPlayer?.release()
            mediaPlayer = null
             
            audioEffectsManager.release()
            Log.d(TAG, "AudioEffectsManager and MediaPlayer released")
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing resources: ${e.message}")
        }
    }
    
    override fun onPause() {
        super.onPause()
        
        // Optionally disable effects when app is paused
        try {
            audioEffectsManager.disableAllEffects()
            Log.d(TAG, "Audio effects disabled on pause")
        } catch (e: Exception) {
            Log.e(TAG, "Error disabling effects on pause: ${e.message}")
        }
    }
    
    override fun onResume() {
        super.onResume()
        
        // Optionally re-enable effects when app is resumed
        try {
            // You can choose to enable all effects or maintain previous state
            Log.d(TAG, "Audio effects ready on resume")
        } catch (e: Exception) {
            Log.e(TAG, "Error handling effects on resume: ${e.message}")
        }
    }
    
    // Helper method to set MediaPlayer reference from external source
    // This would typically be called from your audio service
    fun setMediaPlayerReference(player: MediaPlayer?) {
        mediaPlayer = player
        audioEffectsManager.updateMediaPlayer(player)
        Log.d(TAG, "MediaPlayer reference updated for audio balance control")
    }
}