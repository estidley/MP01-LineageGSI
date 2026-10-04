package com.lmqr.hMP01_comp_service

import android.app.UiModeManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.SystemProperties
import android.provider.Settings
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("MP01BootReceiver", "Boot receiver triggered with action: ${intent.action}")
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            applyFirstBootDefaults(context)
        }
        // Get the intended service from system property
        val propertyValue = SystemProperties.get(
            "persist.accessibility.enabled_service", "")
            
        // Check if service is already enabled
        val serviceName = context.packageName + "/" + 
            MP01AccessibilityService::class.java.canonicalName
        var enabledServices = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
            
        if (enabledServices == null) enabledServices = ""
        
        // Enable if needed and matching our property
        if (!enabledServices.contains(serviceName) && 
            (propertyValue == serviceName || propertyValue.isEmpty())) {
            
            if (!enabledServices.isEmpty()) {
                enabledServices += ":"
            }
            enabledServices += serviceName
            
            try {
                Settings.Secure.putString(
                    context.contentResolver,
                    Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
                    enabledServices)
                Log.d("MP01BootReceiver", "Successfully enabled accessibility service")
            } catch (e: Exception) {
                Log.e("MP01BootReceiver", "Failed to enable accessibility service", e)
            }
                
            Settings.Secure.putInt(
                context.contentResolver,
                Settings.Secure.ACCESSIBILITY_ENABLED, 1)
        }
    }

    private fun applyFirstBootDefaults(context: Context) {
        val preferences = context.getSharedPreferences("mp01_defaults", Context.MODE_PRIVATE)
        if (preferences.getBoolean("eink_defaults_applied", false)) return

        val resolver = context.contentResolver
        // Preserve choices when installing this service onto a configured device.
        if (Settings.Secure.getInt(resolver, Settings.Secure.USER_SETUP_COMPLETE, 0) != 0) {
            preferences.edit().putBoolean("eink_defaults_applied", true).apply()
            return
        }
        try {
            val uiModeManager = context.getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
            uiModeManager.setNightMode(UiModeManager.MODE_NIGHT_NO)
            val applied = listOf(
                Settings.Global.putFloat(resolver, Settings.Global.WINDOW_ANIMATION_SCALE, 0f),
                Settings.Global.putFloat(resolver, Settings.Global.TRANSITION_ANIMATION_SCALE, 0f),
                Settings.Global.putFloat(resolver, Settings.Global.ANIMATOR_DURATION_SCALE, 0f)
            ).all { it }
            if (applied) {
                preferences.edit().putBoolean("eink_defaults_applied", true).apply()
                Log.i("MP01BootReceiver", "Applied light theme and disabled animations for first setup")
            } else {
                Log.w("MP01BootReceiver", "First-boot animation settings were not fully applied")
            }
        } catch (exception: Exception) {
            Log.e("MP01BootReceiver", "Unable to apply first-boot e-paper defaults", exception)
        }
    }
}
