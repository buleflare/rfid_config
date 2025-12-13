package com.mm.ylp.rfid.rfid_v1

import android.app.Activity
import android.content.Intent
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.MifareClassic
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private lateinit var nfcAdapter: NfcAdapter

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize NFC adapter
        nfcAdapter = NfcAdapter.getDefaultAdapter(this)

        // Set up the plugin
        MifareClassicPlugin.setup(flutterEngine, this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        println("DEBUG: MainActivity onNewIntent: ${intent.action}")

        if (intent.action == NfcAdapter.ACTION_TECH_DISCOVERED ||
            intent.action == NfcAdapter.ACTION_TAG_DISCOVERED) {
            println("DEBUG: NFC tech discovered in MainActivity")

            // Get the tag
            val tag: Tag? = intent.getParcelableExtra(NfcAdapter.EXTRA_TAG)
            if (tag != null) {
                // Process the tag in the plugin
                MifareClassicPlugin.onNewIntent(this, intent)
            }
        }
    }

    override fun onResume() {
        super.onResume()
        // Enable NFC foreground dispatch when activity is in foreground
        enableNfcForegroundDispatch()
    }

    override fun onPause() {
        super.onPause()
        // Disable NFC foreground dispatch when activity is not in foreground
        disableNfcForegroundDispatch()
    }

    private fun enableNfcForegroundDispatch() {
        try {
            if (nfcAdapter != null) {
                val intent = Intent(this, javaClass).apply {
                    addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                }
                val pendingIntent = android.app.PendingIntent.getActivity(
                    this, 0, intent,
                    android.app.PendingIntent.FLAG_MUTABLE or android.app.PendingIntent.FLAG_UPDATE_CURRENT
                )

                val techLists = arrayOf(
                    arrayOf(MifareClassic::class.java.name),
                    arrayOf(android.nfc.tech.NfcA::class.java.name),
                    arrayOf(android.nfc.tech.NfcB::class.java.name),
                    arrayOf(android.nfc.tech.NfcF::class.java.name),
                    arrayOf(android.nfc.tech.NfcV::class.java.name),
                    arrayOf(android.nfc.tech.IsoDep::class.java.name),
                    arrayOf(android.nfc.tech.Ndef::class.java.name),
                    arrayOf(android.nfc.tech.NdefFormatable::class.java.name),
                    arrayOf(android.nfc.tech.MifareUltralight::class.java.name)
                )

                nfcAdapter.enableForegroundDispatch(this, pendingIntent, null, techLists)
                println("DEBUG: NFC foreground dispatch enabled")
            }
        } catch (e: Exception) {
            println("DEBUG: Error enabling NFC foreground dispatch: ${e.message}")
        }
    }

    private fun disableNfcForegroundDispatch() {
        try {
            if (nfcAdapter != null) {
                nfcAdapter.disableForegroundDispatch(this)
                println("DEBUG: NFC foreground dispatch disabled")
            }
        } catch (e: Exception) {
            println("DEBUG: Error disabling NFC foreground dispatch: ${e.message}")
        }
    }
}