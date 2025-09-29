package com.example.nfcr

import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import android.util.Log
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class HceService : HostApduService() {
    
    companion object {
        private const val TAG = "HceService"
        
        // Commandes APDU standard
        private val SELECT_AID_COMMAND = byteArrayOf(0x00, 0xA4.toByte(), 0x04, 0x00)
        private val SUCCESS_SW = byteArrayOf(0x90.toByte(), 0x00)
        private val UNKNOWN_COMMAND_SW = byteArrayOf(0x6D, 0x00)
        private val UNKNOWN_AID_SW = byteArrayOf(0x6A, 0x82.toByte())
        
        // Données de la carte en cours d'émulation
        var currentCardData: ByteArray? = null
        var currentCardUid: String? = null
        var isEmulating = false
        
        // Callback pour notifier Flutter
        var eventSink: EventChannel.EventSink? = null
    }
    
    override fun processCommandApdu(commandApdu: ByteArray?, extras: Bundle?): ByteArray {
        Log.d(TAG, "Received APDU: ${commandApdu?.let { bytesToHex(it) }}")
        
        if (commandApdu == null) {
            return UNKNOWN_COMMAND_SW
        }
        
        // Vérification de la commande SELECT AID
        if (commandApdu.size >= 4 && 
            commandApdu[0] == SELECT_AID_COMMAND[0] &&
            commandApdu[1] == SELECT_AID_COMMAND[1] &&
            commandApdu[2] == SELECT_AID_COMMAND[2] &&
            commandApdu[3] == SELECT_AID_COMMAND[3]) {
            
            Log.d(TAG, "SELECT AID command received")
            
            // Vérifier si nous avons des données de carte à émuler
            return if (currentCardData != null) {
                Log.d(TAG, "Responding with card data")
                // Envoyer les données de la carte + code de succès
                currentCardData!! + SUCCESS_SW
            } else {
                Log.d(TAG, "No card data available")
                SUCCESS_SW
            }
        }
        
        // Commande de lecture de données
        if (commandApdu.size >= 2 && commandApdu[0] == 0x00.toByte() && commandApdu[1] == 0xB0.toByte()) {
            Log.d(TAG, "READ BINARY command received")
            
            return if (currentCardData != null) {
                // Retourner les données de la carte
                currentCardData!! + SUCCESS_SW
            } else {
                SUCCESS_SW
            }
        }
        
        // Commande de lecture UID
        if (commandApdu.size >= 2 && commandApdu[0] == 0xFF.toByte() && commandApdu[1] == 0xCA.toByte()) {
            Log.d(TAG, "GET UID command received")
            
            return if (currentCardUid != null) {
                // Convertir l'UID en bytes et l'envoyer
                val uidBytes = hexToBytes(currentCardUid!!)
                uidBytes + SUCCESS_SW
            } else {
                SUCCESS_SW
            }
        }
        
        Log.d(TAG, "Unknown command, returning error")
        return UNKNOWN_COMMAND_SW
    }
    
    override fun onDeactivated(reason: Int) {
        Log.d(TAG, "Service deactivated, reason: $reason")
        isEmulating = false
        
        // Notifier Flutter que l'émulation s'est arrêtée
        eventSink?.success(mapOf(
            "event" to "emulation_stopped",
            "reason" to reason
        ))
    }
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "HCE Service created")
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "HCE Service destroyed")
        isEmulating = false
    }
    
    // Méthodes utilitaires pour la conversion hex/bytes
    private fun bytesToHex(bytes: ByteArray): String {
        return bytes.joinToString("") { "%02x".format(it) }
    }
    
    private fun hexToBytes(hex: String): ByteArray {
        val cleanHex = hex.replace(":", "").replace(" ", "")
        return cleanHex.chunked(2).map { it.toInt(16).toByte() }.toByteArray()
    }
    
    // Méthodes pour gérer les données d'émulation
    fun startEmulation(cardData: ByteArray?, cardUid: String?) {
        Log.d(TAG, "Starting emulation with UID: $cardUid")
        currentCardData = cardData
        currentCardUid = cardUid
        isEmulating = true
        
        // Notifier Flutter que l'émulation a commencé
        eventSink?.success(mapOf(
            "event" to "emulation_started",
            "uid" to cardUid
        ))
    }
    
    fun stopEmulation() {
        Log.d(TAG, "Stopping emulation")
        currentCardData = null
        currentCardUid = null
        isEmulating = false
        
        // Notifier Flutter que l'émulation s'est arrêtée
        eventSink?.success(mapOf(
            "event" to "emulation_stopped",
            "reason" to "manual"
        ))
    }
}