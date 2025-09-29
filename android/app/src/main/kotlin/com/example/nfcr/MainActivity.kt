package com.example.nfcr

import android.content.Context
import android.nfc.NfcAdapter
import android.nfc.cardemulation.CardEmulation
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    
    companion object {
        private const val TAG = "MainActivity"
        private const val HCE_CHANNEL = "com.example.nfcr/hce"
        private const val HCE_EVENTS = "com.example.nfcr/hce_events"
    }
    
    private var nfcAdapter: NfcAdapter? = null
    private var cardEmulation: CardEmulation? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialiser NFC
        nfcAdapter = NfcAdapter.getDefaultAdapter(this)
        cardEmulation = CardEmulation.getInstance(nfcAdapter)
        
        // Configuration du MethodChannel pour HCE
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HCE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isHceSupported" -> {
                    result.success(isHceSupported())
                }
                "isHceEnabled" -> {
                    result.success(isHceEnabled())
                }
                "startEmulation" -> {
                    val cardUid = call.argument<String>("uid")
                    val cardData = call.argument<String>("data")
                    val cardTechnology = call.argument<String>("technology")
                    
                    if (cardUid != null) {
                        startEmulation(cardUid, cardData, cardTechnology)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENTS", "UID is required", null)
                    }
                }
                "stopEmulation" -> {
                    stopEmulation()
                    result.success(true)
                }
                "isEmulating" -> {
                    result.success(HceService.isEmulating)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Configuration de l'EventChannel pour les événements HCE
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, HCE_EVENTS).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    HceService.eventSink = events
                }
                
                override fun onCancel(arguments: Any?) {
                    HceService.eventSink = null
                }
            }
        )
    }
    
    private fun isHceSupported(): Boolean {
        return try {
            nfcAdapter != null && packageManager.hasSystemFeature("android.hardware.nfc.hce")
        } catch (e: Exception) {
            Log.e(TAG, "Error checking HCE support", e)
            false
        }
    }
    
    private fun isHceEnabled(): Boolean {
        return try {
            nfcAdapter?.isEnabled == true && cardEmulation != null
        } catch (e: Exception) {
            Log.e(TAG, "Error checking HCE status", e)
            false
        }
    }
    
    private fun startEmulation(uid: String, data: String?, technology: String?) {
        try {
            Log.d(TAG, "Starting HCE emulation for UID: $uid")
            
            // Convertir les données hexadécimales en ByteArray si présentes
            val cardData = data?.let { hexToBytes(it) }
            
            // Démarrer le service d'émulation
            val hceService = HceService()
            hceService.startEmulation(cardData, uid)
            
            Log.d(TAG, "HCE emulation started successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting HCE emulation", e)
        }
    }
    
    private fun stopEmulation() {
        try {
            Log.d(TAG, "Stopping HCE emulation")
            val hceService = HceService()
            hceService.stopEmulation()
            Log.d(TAG, "HCE emulation stopped successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping HCE emulation", e)
        }
    }
    
    private fun hexToBytes(hex: String): ByteArray {
        val cleanHex = hex.replace(":", "").replace(" ", "")
        return cleanHex.chunked(2).map { it.toInt(16).toByte() }.toByteArray()
    }
}
