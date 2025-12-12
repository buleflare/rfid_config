package com.mm.ylp.rfid.rfid_v1

import android.app.PendingIntent
import android.content.Intent
import android.content.IntentFilter
import android.nfc.NfcAdapter
import android.nfc.tech.MifareClassic
import android.nfc.tech.NfcA
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var nfcAdapter: NfcAdapter? = null
    private var nfcPendingIntent: PendingIntent? = null
    private var nfcIntentFilters: Array<IntentFilter>? = null
    private var nfcTechLists: Array<Array<String>>? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        initializeNfcForegroundDispatch()
    }

    private fun initializeNfcForegroundDispatch() {
        nfcAdapter = NfcAdapter.getDefaultAdapter(this)

        // Create a PendingIntent for NFC events
        val intent = Intent(this, javaClass).apply {
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_MUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        nfcPendingIntent = PendingIntent.getActivity(this, 0, intent, flags)

        // Setup intent filters for NFC
        nfcIntentFilters = arrayOf(
            IntentFilter(NfcAdapter.ACTION_TECH_DISCOVERED).apply {
                try {
                    addDataType("*/*")
                } catch (e: IntentFilter.MalformedMimeTypeException) {
                    throw RuntimeException("Fail", e)
                }
            }
        )

        // Setup tech lists for Mifare Classic
        nfcTechLists = arrayOf(
            arrayOf(MifareClassic::class.java.name),
            arrayOf(NfcA::class.java.name)
        )
    }

    override fun onResume() {
        super.onResume()
        // Enable NFC foreground dispatch when activity is in foreground
        nfcAdapter?.enableForegroundDispatch(
            this,
            nfcPendingIntent,
            nfcIntentFilters,
            nfcTechLists
        )
    }

    override fun onPause() {
        super.onPause()
        // Disable NFC foreground dispatch when activity is in background
        nfcAdapter?.disableForegroundDispatch(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MifareClassicPlugin.setup(flutterEngine, this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        println("DEBUG: MainActivity onNewIntent: ${intent.action}")

        // Check if this is an NFC intent
        if (intent.action == NfcAdapter.ACTION_TECH_DISCOVERED) {
            println("DEBUG: NFC tech discovered in MainActivity")
            MifareClassicPlugin.onNewIntent(this, intent)
        }
    }
}