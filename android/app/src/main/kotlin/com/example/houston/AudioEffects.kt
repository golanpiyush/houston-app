package com.example.houston

import android.media.AudioManager
import android.media.audiofx.*
import android.media.MediaPlayer
import android.content.Context
import android.widget.Toast
import android.util.Log
import java.util.*
import kotlin.math.abs

class AudioEffectsManager(private val context: Context) {
    private val TAG = "AudioEffectsManager"
    
    // Audio session ID - should be set from your audio player
    private var audioSessionId: Int = 0
    
    // MediaPlayer reference for audio balance control
    private var mediaPlayer: MediaPlayer? = null
    
    // Effect instances
    private var bassBoost: BassBoost? = null
    private var equalizer: Equalizer? = null
    private var environmentalReverb: EnvironmentalReverb? = null
    private var loudnessEnhancer: LoudnessEnhancer? = null
    private var dynamicsProcessing: DynamicsProcessing? = null
    
    // Audio balance (0.0 = full left, 0.5 = center, 1.0 = full right)
    private var audioBalance: Float = 0.5f
    
    // Safe limits
    companion object {
        const val SAFE_BASS_BOOST_LIMIT = 800 // millibels
        const val SAFE_LOUDNESS_LIMIT = 600 // millibels
        const val SAFE_EQ_BAND_LIMIT = 1200 // millibels
        const val DANGER_LOUDNESS_THRESHOLD = 1000 // millibels
        const val MIN_BALANCE = 0.0f // Full left
        const val MAX_BALANCE = 1.0f // Full right
        const val CENTER_BALANCE = 0.5f // Center
    }
    
    // Preset configurations (updated without virtualizer and preset reverb)
    data class AudioPreset(
        val name: String,
        val bassBoost: Short,
        val loudnessEnhancer: Int,
        val equalizerBands: ShortArray,
        val reverbLevel: Int, // 0-100% for environmental reverb
        val audioBalance: Float
    )
    
    private val presets = mapOf(
        "Normal" to AudioPreset(
            "Normal", 0, 0, 
            shortArrayOf(0, 0, 0, 0, 0), 
            0, CENTER_BALANCE
        ),
        "Rock" to AudioPreset(
            "Rock", 400, 300,
            shortArrayOf(300, 200, -100, 100, 400),
            30, CENTER_BALANCE
        ),
        "Pop" to AudioPreset(
            "Pop", 200, 200,
            shortArrayOf(100, 200, 300, 200, 100),
            20, CENTER_BALANCE
        ),
        "Jazz" to AudioPreset(
            "Jazz", 100, 100,
            shortArrayOf(200, 100, 0, 100, 200),
            40, CENTER_BALANCE
        ),
        "Classical" to AudioPreset(
            "Classical", 0, 0,
            shortArrayOf(200, 0, 0, 0, 200),
            50, CENTER_BALANCE
        ),
        "Bass Boost" to AudioPreset(
            "Bass Boost", 800, 400,
            shortArrayOf(600, 400, 200, 0, 0),
            15, CENTER_BALANCE
        ),
        "Vocal" to AudioPreset(
            "Vocal", 0, 200,
            shortArrayOf(0, 200, 400, 400, 200),
            25, CENTER_BALANCE
        ),
        "Gaming" to AudioPreset(
            "Gaming", 300, 300,
            shortArrayOf(200, 300, 200, 300, 400),
            35, CENTER_BALANCE
        )
    )
    
    // Initialize effects with audio session ID and optionally MediaPlayer
    fun initialize(sessionId: Int, player: MediaPlayer? = null): Boolean {
        audioSessionId = sessionId
        mediaPlayer = player
        return try {
            initializeEffects()
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing effects: ${e.message}")
            false
        }
    }
    
    private fun initializeEffects() {
    try {
        // Bass Boost - Most widely supported
        try {
            bassBoost = BassBoost(0, audioSessionId).apply {
                enabled = false
            }
        } catch (e: Exception) {
            Log.w(TAG, "BassBoost not supported: ${e.message}")
        }
        
        // Equalizer - Most widely supported
        try {
            equalizer = Equalizer(0, audioSessionId).apply {
                enabled = false
            }
        } catch (e: Exception) {
            Log.w(TAG, "Equalizer not supported: ${e.message}")
        }
        
        // Environmental Reverb - Check device support first
        try {
            environmentalReverb = EnvironmentalReverb(0, audioSessionId).apply {
                enabled = false
                // Test if we can actually use it
                val testSettings = EnvironmentalReverb.Settings()
                testSettings.roomLevel = -1000
                properties = testSettings
            }
        } catch (e: Exception) {
            Log.w(TAG, "EnvironmentalReverb not supported: ${e.message}")
            environmentalReverb = null
        }
        
        // Loudness Enhancer - API 19+ with better error handling
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.KITKAT) {
            try {
                loudnessEnhancer = LoudnessEnhancer(audioSessionId).apply {
                    enabled = false
                    // Test with a small value
                    setTargetGain(100)
                    setTargetGain(0)
                }
            } catch (e: Exception) {
                Log.w(TAG, "LoudnessEnhancer not supported on this device: ${e.message}")
                loudnessEnhancer = null
            }
        }
        
        // Dynamics Processing - API 28+ with better error handling
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
            try {
                val config = DynamicsProcessing.Config.Builder(
                    0, // variant
                    1, // inputChannelCount
                    true, // preEqInUse
                    1, // preEqBandCount
                    true, // mbcInUse
                    1, // mbcBandCount
                    true, // postEqInUse
                    1, // postEqBandCount
                    true  // limiterInUse
                ).build()
                
                dynamicsProcessing = DynamicsProcessing(0, audioSessionId, config)
                dynamicsProcessing?.enabled = false
            } catch (e: Exception) {
                Log.w(TAG, "DynamicsProcessing not supported on this device: ${e.message}")
                dynamicsProcessing = null
            }
        }
        
    } catch (e: Exception) {
        Log.e(TAG, "Error initializing effects: ${e.message}")
        throw e
    }
}
    
    // Apply preset
    fun applyPreset(presetName: String): Boolean {
        val preset = presets[presetName] ?: return false
        
        try {
            // Apply bass boost
            setBassBoost(preset.bassBoost)
            
            // Apply loudness enhancer
            setLoudnessEnhancer(preset.loudnessEnhancer)
            
            // Apply equalizer bands
            preset.equalizerBands.forEachIndexed { index, value ->
                setEqualizerBand(index, value)
            }
            
            // Apply environmental reverb (convert percentage to reverb settings)
            setEnvironmentalReverbLevel(preset.reverbLevel)
            
            // Apply audio balance
            setAudioBalance(preset.audioBalance)
            
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error applying preset: ${e.message}")
            return false
        }
    }
    
    // Bass Boost controls
    fun setBassBoost(strength: Short): Boolean {
        return try {
            bassBoost?.let { effect ->
                val safeStrength = if (strength > SAFE_BASS_BOOST_LIMIT) {
                    showWarningToast("Bass boost exceeds safe limit!")
                    strength
                } else {
                    strength
                }
                
                effect.setStrength(safeStrength)
                effect.enabled = safeStrength > 0
                true
            } ?: false
        } catch (e: Exception) {
            Log.e(TAG, "Error setting bass boost: ${e.message}")
            false
        }
    }
    
    fun getBassBoost(): Short {
        return try {
            bassBoost?.roundedStrength ?: 0
        } catch (e: Exception) {
            0
        }
    }
    
    // Audio Balance controls (0.0 = full left, 0.5 = center, 1.0 = full right)
    fun setAudioBalance(balance: Float): Boolean {
    return try {
        val clampedBalance = balance.coerceIn(MIN_BALANCE, MAX_BALANCE)
        audioBalance = clampedBalance
        
        mediaPlayer?.let { player ->
            // Simplified and corrected balance calculation
            // balance: 0.0 = full left, 0.5 = center, 1.0 = full right
            val leftVolume = 1.0f - clampedBalance
            val rightVolume = clampedBalance
            
            // For center position (0.5), both should be 0.5, not 1.0
            val adjustedLeftVolume = if (clampedBalance == CENTER_BALANCE) 1.0f else leftVolume * 2.0f
            val adjustedRightVolume = if (clampedBalance == CENTER_BALANCE) 1.0f else rightVolume * 2.0f
            
            player.setVolume(
                adjustedLeftVolume.coerceIn(0.0f, 1.0f),
                adjustedRightVolume.coerceIn(0.0f, 1.0f)
            )
            true
        } ?: run {
            Log.w(TAG, "MediaPlayer not available for audio balance control")
            true
        }
    } catch (e: Exception) {
        Log.e(TAG, "Error setting audio balance: ${e.message}")
        false
    }
}
    
    fun getAudioBalance(): Float {
        return audioBalance
    }
    
    // Audio balance helper methods
    fun setAudioBalancePercentage(percentage: Int): Boolean {
        // Convert percentage (0-100) to balance (0.0-1.0)
        val balance = percentage.coerceIn(0, 100) / 100.0f
        return setAudioBalance(balance)
    }
    
    fun getAudioBalancePercentage(): Int {
        return (audioBalance * 100).toInt()
    }
    
    fun resetAudioBalance(): Boolean {
        return setAudioBalance(CENTER_BALANCE)
    }
    
    // Check if audio balance is supported
    fun isAudioBalanceSupported(): Boolean {
        return mediaPlayer != null
    }
    
    // Equalizer controls
    fun setEqualizerBand(band: Int, level: Short): Boolean {
        return try {
            equalizer?.let { eq ->
                if (band < 0 || band >= eq.numberOfBands) return false
                
                val safeLevel = if (abs(level.toInt()) > SAFE_EQ_BAND_LIMIT) {
                    showWarningToast("EQ band ${band + 1} exceeds safe limit!")
                    level
                } else {
                    level
                }
                
                eq.setBandLevel(band.toShort(), safeLevel)
                eq.enabled = true
                true
            } ?: false
        } catch (e: Exception) {
            Log.e(TAG, "Error setting equalizer band: ${e.message}")
            false
        }
    }
    
    fun getEqualizerBand(band: Int): Short {
        return try {
            equalizer?.getBandLevel(band.toShort()) ?: 0
        } catch (e: Exception) {
            0
        }
    }
    
    fun getEqualizerBandCount(): Int {
        return try {
            equalizer?.numberOfBands?.toInt() ?: 0
        } catch (e: Exception) {
            0
        }
    }
    
    fun getEqualizerBandFreq(band: Int): Int {
        return try {
            equalizer?.getCenterFreq(band.toShort()) ?: 0
        } catch (e: Exception) {
            0
        }
    }
    
    // Loudness Enhancer controls
    fun setLoudnessEnhancer(gainmB: Int): Boolean {
    return try {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.KITKAT) {
            loudnessEnhancer?.let { effect ->
                // LoudnessEnhancer accepts values from 0 to 2000 mB typically
                val clampedGain = gainmB.coerceIn(0, 2000)
                
                if (clampedGain > SAFE_LOUDNESS_LIMIT) {
                    showWarningToast("Loudness enhancer exceeds safe limit!")
                    if (clampedGain > DANGER_LOUDNESS_THRESHOLD) {
                        showDangerToast("WARNING: Extremely high loudness levels can damage hearing!")
                    }
                }
                
                effect.setTargetGain(clampedGain)
                effect.enabled = clampedGain > 0
                true
            } ?: false
        } else {
            false
        }
    } catch (e: Exception) {
        Log.e(TAG, "Error setting loudness enhancer: ${e.message}")
        false
    }
}
    
    fun getLoudnessEnhancer(): Int {
        return try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.KITKAT) {
                loudnessEnhancer?.targetGain?.toInt() ?: 0
            } else {
                0
            }
        } catch (e: Exception) {
            0
        }
    }
    
    // Environmental Reverb controls (0-100% intensity)
   fun setEnvironmentalReverbLevel(levelPercentage: Int): Boolean {
    return try {
        val clampedLevel = levelPercentage.coerceIn(0, 100)
        
        environmentalReverb?.let { effect ->
            if (clampedLevel == 0) {
                effect.enabled = false
                return true
            }
            
            // Use proper parameter ranges for EnvironmentalReverb
            val intensity = clampedLevel / 100.0f
            
            val settings = EnvironmentalReverb.Settings().apply {
                // Corrected parameter ranges based on Android documentation
                roomLevel = (-1000 + (800 * intensity)).toInt().toShort() // -1000 to -200
                roomHFLevel = (-500 + (400 * intensity)).toInt().toShort() // -500 to -100
                decayTime = (300 + (1200 * intensity)).toInt() // 300 to 1500 ms
                decayHFRatio = (100 + (900 * intensity)).toInt().toShort() // 100 to 1000
                reflectionsLevel = (-2000 + (1500 * intensity)).toInt().toShort() // -2000 to -500
                reflectionsDelay = (5 + (40 * intensity)).toInt() // 5 to 45 ms
                reverbLevel = (-1000 + (1000 * intensity)).toInt().toShort() // -1000 to 0
                reverbDelay = (10 + (30 * intensity)).toInt() // 10 to 40 ms
                diffusion = (500 + (500 * intensity)).toInt().toShort() // 500 to 1000
                density = (500 + (500 * intensity)).toInt().toShort() // 500 to 1000
            }
            
            effect.properties = settings
            effect.enabled = true
            true
        } ?: false
    } catch (e: Exception) {
        Log.e(TAG, "Error setting environmental reverb level: ${e.message}")
        false
    }
}
    
    fun getEnvironmentalReverbLevel(): Int {
    return try {
        environmentalReverb?.let { effect ->
            if (!effect.enabled) return 0
            
            val settings = effect.properties
            // Calculate level based on reverbLevel parameter
            val reverbLevel = settings.reverbLevel.toFloat()
            // Convert from range [-1000, 0] to [0, 100]
            val percentage = ((reverbLevel + 1000) / 1000.0f * 100).toInt()
            percentage.coerceIn(0, 100)
        } ?: 0
    } catch (e: Exception) {
        Log.e(TAG, "Error getting environmental reverb level: ${e.message}")
        0
    }
}
    
    // Environmental Reverb controls (detailed)
    fun setEnvironmentalReverb(
        roomLevel: Short = -1000,
        roomHFLevel: Short = -100,
        decayTime: Int = 1490,
        decayHFRatio: Short = 830,
        reflectionsLevel: Short = -2602,
        reflectionsDelay: Int = 7,
        reverbLevel: Short = 200,
        reverbDelay: Int = 11,
        diffusion: Short = 1000,
        density: Short = 1000
    ): Boolean {
        return try {
            environmentalReverb?.let { effect ->
                val settings = EnvironmentalReverb.Settings().apply {
                    this.roomLevel = roomLevel
                    this.roomHFLevel = roomHFLevel
                    this.decayTime = decayTime
                    this.decayHFRatio = decayHFRatio
                    this.reflectionsLevel = reflectionsLevel
                    this.reflectionsDelay = reflectionsDelay
                    this.reverbLevel = reverbLevel
                    this.reverbDelay = reverbDelay
                    this.diffusion = diffusion
                    this.density = density
                }
                effect.properties = settings
                effect.enabled = true
                true
            } ?: false
        } catch (e: Exception) {
            Log.e(TAG, "Error setting environmental reverb: ${e.message}")
            false
        }
    }
    
    // Master controls
    fun enableAllEffects(): Boolean {
        return try {
            bassBoost?.enabled = true
            equalizer?.enabled = true
            environmentalReverb?.enabled = true
            loudnessEnhancer?.enabled = true
            dynamicsProcessing?.enabled = true
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error enabling all effects: ${e.message}")
            false
        }
    }
    
    fun disableAllEffects(): Boolean {
        return try {
            bassBoost?.enabled = false
            equalizer?.enabled = false
            environmentalReverb?.enabled = false
            loudnessEnhancer?.enabled = false
            dynamicsProcessing?.enabled = false
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error disabling all effects: ${e.message}")
            false
        }
    }
    
    fun resetAllEffects(): Boolean {
        return try {
            setBassBoost(0)
            setLoudnessEnhancer(0)
            setEnvironmentalReverbLevel(0)
            resetAudioBalance()
            
            // Reset equalizer bands
            equalizer?.let { eq ->
                for (i in 0 until eq.numberOfBands) {
                    eq.setBandLevel(i.toShort(), 0)
                }
            }
            
            disableAllEffects()
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error resetting all effects: ${e.message}")
            false
        }
    }
    
    // Get available presets
    fun getAvailablePresets(): List<String> {
        return presets.keys.toList()
    }
    
    // Check if effects are supported
    fun isEffectSupported(effectType: String): Boolean {
    return when (effectType) {
        "BassBoost" -> bassBoost != null
        "Equalizer" -> equalizer != null
        "EnvironmentalReverb" -> environmentalReverb != null
        "LoudnessEnhancer" -> loudnessEnhancer != null && 
                             android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.KITKAT
        "DynamicsProcessing" -> dynamicsProcessing != null && 
                               android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P
        "AudioBalance" -> mediaPlayer != null
        else -> false
    }
}
    
    // Get current settings as JSON-like string for Flutter
    fun getCurrentSettings(): String {
        return try {
            val settings = mutableMapOf<String, Any>()
            
            settings["bassBoost"] = getBassBoost()
            settings["loudnessEnhancer"] = getLoudnessEnhancer()
            settings["environmentalReverbLevel"] = getEnvironmentalReverbLevel()
            settings["audioBalance"] = getAudioBalance()
            settings["audioBalancePercentage"] = getAudioBalancePercentage()
            
            // Get equalizer bands
            val eqBands = mutableListOf<Short>()
            equalizer?.let { eq ->
                for (i in 0 until eq.numberOfBands) {
                    eqBands.add(eq.getBandLevel(i.toShort()))
                }
            }
            settings["equalizerBands"] = eqBands
            
            // Get supported effects
            val supportedEffects = mutableMapOf<String, Boolean>()
            listOf("BassBoost", "Equalizer", "EnvironmentalReverb", "LoudnessEnhancer", 
                   "DynamicsProcessing", "AudioBalance").forEach { effect ->
                supportedEffects[effect] = isEffectSupported(effect)
            }
            settings["supportedEffects"] = supportedEffects
            
            // Convert to simple string format
            settings.toString()
        } catch (e: Exception) {
            Log.e(TAG, "Error getting current settings: ${e.message}")
            "{}"
        }
    }
    
    // Update MediaPlayer reference (useful when MediaPlayer is recreated)
    fun updateMediaPlayer(player: MediaPlayer?) {
        mediaPlayer = player
        // Reapply current audio balance
        setAudioBalance(audioBalance)
    }
    
    // Warning toast helper
    private fun showWarningToast(message: String) {
        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
    }
    
    private fun showDangerToast(message: String) {
        Toast.makeText(context, message, Toast.LENGTH_LONG).show()
    }
    
    // Cleanup
    fun release() {
        try {
            bassBoost?.release()
            equalizer?.release()
            environmentalReverb?.release()
            loudnessEnhancer?.release()
            dynamicsProcessing?.release()
            mediaPlayer = null
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing effects: ${e.message}")
        }
    }
}