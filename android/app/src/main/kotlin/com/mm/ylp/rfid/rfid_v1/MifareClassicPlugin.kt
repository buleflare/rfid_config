package com.mm.ylp.rfid.rfid_v1

import android.annotation.SuppressLint
import android.content.Context
import android.content.SharedPreferences
import org.json.JSONObject
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import android.app.Activity
import android.content.Intent
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.MifareClassic
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.os.Handler
import android.os.Looper
import java.io.IOException

object MifareClassicPlugin {

    private var eventSink: EventChannel.EventSink? = null
    private var currentTag: Tag? = null
    private var isReading = false

    // Storage for custom keys per sector
    private val customKeysA = mutableMapOf<Int, ByteArray>()
    private val customKeysB = mutableMapOf<Int, ByteArray>()

    // Track which key was used for each sector
    private val lastUsedKeyType = mutableMapOf<Int, String>()
    private val lastUsedKeyHex = mutableMapOf<Int, String>()

    // Storage for card-specific keys
    private val cardKeys = mutableMapOf<String, MutableMap<String, String>>()

    // Context for storage operations
    private var applicationContext: Context? = null

    // Common default keys (fallback)
    private val commonKeys = arrayOf(
        byteArrayOf(0xFF.toByte(), 0xFF.toByte(), 0xFF.toByte(), 0xFF.toByte(), 0xFF.toByte(), 0xFF.toByte()),
        byteArrayOf(0xD3.toByte(), 0xF7.toByte(), 0xD3.toByte(), 0xF7.toByte(), 0xD3.toByte(), 0xF7.toByte()),
        byteArrayOf(0xA0.toByte(), 0xA1.toByte(), 0xA2.toByte(), 0xA3.toByte(), 0xA4.toByte(), 0xA5.toByte()),
        byteArrayOf(0x00.toByte(), 0x00.toByte(), 0x00.toByte(), 0x00.toByte(), 0x00.toByte(), 0x00.toByte())
    )

    fun clearCurrentTag() {
        currentTag = null
        isReading = false
        println("DEBUG: Cleared current tag and reading state")
    }

    @SuppressLint("StaticFieldLeak")
    fun setup(flutterEngine: FlutterEngine, activity: Activity) {
        applicationContext = activity.applicationContext

        val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mifare_classic/method")
        val eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "mifare_classic/events")

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startScan" -> {
                    println("DEBUG: Flutter called startScan")
                    result.success(true)
                    // If we have a tag, read it
                    currentTag?.let {
                        if (!isReading) {
                            isReading = true
                            readAllBlocks(it, false)
                        }
                    }
                }

                "setSectorKey" -> {
                    val sector = call.argument<Int>("sector") ?: -1
                    val keyType = call.argument<String>("keyType") ?: "A"
                    val keyHex = call.argument<String>("key") ?: ""

                    if (sector < 0) {
                        result.error("INVALID_SECTOR", "Invalid sector", null)
                        return@setMethodCallHandler
                    }

                    if (keyHex.isEmpty()) {
                        result.error("INVALID_KEY", "Key cannot be empty", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val keyBytes = hexStringToByteArray(keyHex)
                        if (keyBytes.size != 6) {
                            result.error("INVALID_KEY", "Key must be 6 bytes (12 hex characters)", null)
                            return@setMethodCallHandler
                        }

                        if (keyType.uppercase() == "A") {
                            customKeysA[sector] = keyBytes
                            println("DEBUG: Set custom Key A for sector $sector: $keyHex")
                        } else {
                            customKeysB[sector] = keyBytes
                            println("DEBUG: Set custom Key B for sector $sector: $keyHex")
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INVALID_KEY", "Failed to parse key: ${e.message}", null)
                    }
                }

                "clearCustomKeys" -> {
                    customKeysA.clear()
                    customKeysB.clear()
                    lastUsedKeyType.clear()
                    lastUsedKeyHex.clear()
                    result.success(true)
                }

                "getCustomKeys" -> {
                    val keysMap = mutableMapOf<String, String>()
                    customKeysA.forEach { (sector, key) ->
                        keysMap["A_$sector"] = bytesToHex(key)
                    }
                    customKeysB.forEach { (sector, key) ->
                        keysMap["B_$sector"] = bytesToHex(key)
                    }
                    result.success(keysMap)
                }

                "readWithKeys" -> {
                    val keyMap = call.argument<Map<String, String>>("keys") ?: emptyMap()
                    val tag = currentTag ?: run {
                        result.error("NO_TAG", "No tag detected", null)
                        return@setMethodCallHandler
                    }

                    // Parse and set keys from Flutter
                    parseAndSetKeys(keyMap)

                    if (!isReading) {
                        isReading = true
                        readAllBlocks(tag, true) // Read with custom keys
                    }
                    result.success(true)
                }

                "writeData" -> {
                    val data = call.argument<String>("data") ?: ""
                    val isHex = call.argument<Boolean>("isHex") ?: false
                    val sector = call.argument<Int>("sector")
                    val block = call.argument<Int>("block")
                    val keyMap = call.argument<Map<String, String>>("keys") // Optional: keys for this write

                    // If keys provided, use them for this operation only
                    keyMap?.let { parseAndSetKeys(it) }

                    if (sector != null && block != null) {
                        writeToSpecificBlock(data, isHex, sector, block, result)
                    } else {
                        // Call the writeNormalData function directly
                        writeNormalData(data, isHex, result)
                    }
                }

                "configureSector" -> {
                    val sector = call.argument<Int>("sector") ?: -1
                    val currentKey = call.argument<String>("currentKey") ?: ""
                    val keyType = call.argument<String>("keyType") ?: "A"
                    val newKeyA = call.argument<String>("newKeyA") ?: ""
                    val newKeyB = call.argument<String>("newKeyB") ?: ""
                    val accessBits = call.argument<String>("accessBits") ?: ""

                    if (sector < 0 || sector > 15) {
                        result.error("INVALID_SECTOR", "Sector must be 0-15", null)
                        return@setMethodCallHandler
                    }

                    try {
                        configureSectorTrailer(
                            sector = sector,
                            currentKey = currentKey,
                            keyType = keyType,
                            newKeyA = newKeyA,
                            newKeyB = newKeyB,
                            accessBits = accessBits,
                            result = result
                        )
                    } catch (e: Exception) {
                        result.error("CONFIG_ERROR", "Configuration failed: ${e.message}", null)
                    }
                }
                "saveCardKeysToStorage" -> saveCardKeysToStorage(call, result)
                "loadCardKeysFromStorage" -> loadCardKeysFromStorage(call, result)
                "setSectorKeyBatch" -> setSectorKeyBatch(call, result)
                "removeKeyForCard" -> removeKeyForCard(call, result)
                "clearAllCardKeys" -> clearAllCardKeys(result)
                "setCustomKeys" -> setCustomKeys(call, result)
                else -> result.notImplemented()
            }
        }

        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                println("DEBUG: Event channel listener set")
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
                println("DEBUG: Event channel listener removed")
            }
        })

        // Load saved keys on setup
        loadSavedKeysFromStorage()
    }

    private fun configureSectorTrailer(
        sector: Int,
        currentKey: String,
        keyType: String,
        newKeyA: String,
        newKeyB: String,
        accessBits: String,
        result: MethodChannel.Result
    ) {
        try {
            val tag = currentTag ?: run {
                result.error("NO_TAG", "No tag detected", null)
                return
            }

            println("DEBUG: Starting sector configuration for sector $sector")

            val mifare = MifareClassic.get(tag) ?: throw Exception("Not a Mifare Classic tag")

            try {
                mifare.connect()

                // Validate inputs
                val currentKeyBytes = hexStringToByteArray(currentKey)
                val newKeyABytes = hexStringToByteArray(newKeyA)
                val newKeyBBytes = hexStringToByteArray(newKeyB)
                val accessBitsBytes = hexStringToByteArray(accessBits)

                // Authenticate with current key
                val authenticated = if (keyType.uppercase() == "A") {
                    mifare.authenticateSectorWithKeyA(sector, currentKeyBytes)
                } else {
                    mifare.authenticateSectorWithKeyB(sector, currentKeyBytes)
                }

                if (!authenticated) {
                    throw Exception("Authentication failed. Check your current key.")
                }

                // Calculate trailer block number
                val trailerBlock = if (sector >= 0 && sector <= 4) {
                    3
                } else if (sector >= 5 && sector <= 15) {
                    val blocksPerSector = mifare.getBlockCountInSector(sector)
                    blocksPerSector - 1
                } else {
                    throw Exception("Invalid sector: $sector")
                }

                // Construct trailer block (16 bytes)
                val trailerData = ByteArray(16)
                System.arraycopy(newKeyABytes, 0, trailerData, 0, 6)
                System.arraycopy(accessBitsBytes, 0, trailerData, 6, 3)
                trailerData[9] = 0x69.toByte()
                System.arraycopy(newKeyBBytes, 0, trailerData, 10, 6)

                println("DEBUG: Writing trailer: ${bytesToHex(trailerData)}")

                // Calculate absolute block number and write
                val startBlock = mifare.sectorToBlock(sector)
                val absBlock = startBlock + trailerBlock
                mifare.writeBlock(absBlock, trailerData)

                // Skip verification to avoid issues with hidden Key A
                println("DEBUG: Configuration written to sector $sector")

                // Update custom keys
                customKeysA[sector] = newKeyABytes

                // Re-read the card
                currentTag?.let {
                    readAllBlocks(it, false)
                }

                result.success(true)

            } catch (e: Exception) {
                mifare.close()
                throw Exception("Configuration failed: ${e.message}")
            }

        } catch (e: Exception) {
            println("DEBUG: Configuration error: ${e.message}")
            result.error("CONFIG_ERROR", e.message, null)
        }
    }

    private fun writeNormalData(data: String, isHex: Boolean, result: MethodChannel.Result) {
        try {
            val tag = currentTag ?: run {
                result.error("NO_TAG", "No tag detected", null)
                return
            }

            println("DEBUG: Starting writeNormalData operation")
            println("DEBUG:   isHex: $isHex")
            println("DEBUG:   data length: ${data.length}")
            println("DEBUG:   first 20 chars: ${data.take(20)}")

            val mifare = MifareClassic.get(tag) ?: throw Exception("Not a Mifare Classic tag")

            try {
                mifare.connect()
                println("DEBUG: Connected to Mifare Classic tag")

                // Convert data to bytes
                val bytes = if (isHex) {
                    // Validate hex string
                    val cleanHex = data.replace("\\s".toRegex(), "").uppercase()

                    // Check if string contains only hex characters
                    if (!cleanHex.matches(Regex("[0-9A-F]+"))) {
                        throw Exception("Invalid hex characters. Use only 0-9, A-F.")
                    }

                    if (cleanHex.length % 2 != 0) {
                        throw Exception("Invalid hex string length. Must be even number of characters.")
                    }

                    try {
                        ByteArray(cleanHex.length / 2) { i ->
                            cleanHex.substring(i * 2, i * 2 + 2).toInt(16).toByte()
                        }
                    } catch (e: Exception) {
                        throw Exception("Invalid hex format: ${e.message}")
                    }
                } else {
                    data.toByteArray(Charsets.UTF_8)
                }

                // Check if bytes array is empty
                if (bytes.isEmpty()) {
                    throw Exception("No data to write")
                }

                println("DEBUG: Data to write (${bytes.size} bytes): ${bytesToHex(bytes.take(32).toByteArray())}...")

                val sectorCount = mifare.sectorCount
                println("DEBUG: Total sectors: $sectorCount")

                // Track writing progress
                var totalBytesWritten = 0
                var totalBlocksWritten = 0
                val maxWritableBytes = 768 // Mifare Classic 1K capacity (48 blocks * 16 bytes)

                // If data is longer than capacity, truncate it
                val dataToWrite = if (bytes.size > maxWritableBytes) {
                    println("DEBUG: Data too long (${bytes.size} > $maxWritableBytes bytes), truncating")
                    bytes.copyOf(maxWritableBytes)
                } else {
                    bytes
                }

                println("DEBUG: Will write ${dataToWrite.size} bytes to card")
                println("DEBUG: Need ${(dataToWrite.size + 15) / 16} blocks")

                // Write data across ALL writable sectors and blocks
                var dataIndex = 0

                // Start from sector 1 (skip sector 0 which is manufacturer)
                for (sector in 1 until sectorCount) {
                    // Check if we have more data to write
                    if (dataIndex >= dataToWrite.size) {
                        println("DEBUG: All data written (stopping at sector $sector)")
                        break
                    }

                    println("DEBUG: === Processing sector $sector ===")

                    // Try to authenticate sector with custom keys first, then common keys
                    val authenticationResult = authenticateSectorWithTracking(mifare, sector)

                    if (!authenticationResult.first) {
                        println("DEBUG: Could not authenticate sector $sector, moving to next sector")
                        continue
                    }

                    // Get sector information
                    val startBlock = mifare.sectorToBlock(sector)
                    val blockCount = mifare.getBlockCountInSector(sector)
                    val dataBlocks = blockCount - 1 // Exclude trailer block

                    println("DEBUG: Sector $sector - startBlock: $startBlock, total blocks: $blockCount, data blocks: $dataBlocks")

                    // Write to all data blocks in this sector
                    for (blockOffset in 0 until dataBlocks) {
                        // Check if we have more data to write
                        if (dataIndex >= dataToWrite.size) {
                            println("DEBUG: All data written (stopping at block $blockOffset)")
                            break
                        }

                        val absBlock = startBlock + blockOffset
                        val blockData = ByteArray(16) { 0x00 }
                        val bytesToCopy = minOf(16, dataToWrite.size - dataIndex)

                        // Copy data to block
                        System.arraycopy(dataToWrite, dataIndex, blockData, 0, bytesToCopy)

                        try {
                            println("DEBUG: Writing to block $absBlock (sector $sector, block $blockOffset)")
                            println("DEBUG:   Data: ${bytesToHex(blockData)}")
                            mifare.writeBlock(absBlock, blockData)

                            // Verify write
                            val verifyData = mifare.readBlock(absBlock)
                            if (!verifyData.contentEquals(blockData)) {
                                println("DEBUG:   Verification FAILED for block $absBlock")
                                println("DEBUG:   Expected: ${bytesToHex(blockData)}")
                                println("DEBUG:   Got: ${bytesToHex(verifyData)}")
                                // Continue anyway, but note the failure
                            } else {
                                println("DEBUG:   Verification OK")
                            }

                            dataIndex += bytesToCopy
                            totalBytesWritten += bytesToCopy
                            totalBlocksWritten++

                            println("DEBUG:   Successfully wrote $bytesToCopy bytes")
                            println("DEBUG:   Total so far: $totalBytesWritten bytes in $totalBlocksWritten blocks")

                        } catch (e: Exception) {
                            println("DEBUG: Failed to write block $absBlock: ${e.message}")
                            // Continue with next block instead of failing completely
                        }
                    }

                    println("DEBUG: === Finished sector $sector ===")
                    println("DEBUG: Bytes written so far: $totalBytesWritten/${dataToWrite.size}")
                }

                mifare.close()

                println("DEBUG: ===== WRITE COMPLETED =====")
                println("DEBUG: Total bytes written: $totalBytesWritten/${dataToWrite.size}")
                println("DEBUG: Total blocks written: $totalBlocksWritten")
                println("DEBUG: Remaining data not written: ${dataToWrite.size - totalBytesWritten} bytes")

                if (totalBytesWritten == 0) {
                    throw Exception("Could not write any data. Card may be locked or authentication failed.")
                }
                if (totalBytesWritten < dataToWrite.size) {
                    println("DEBUG: Warning: Only wrote $totalBytesWritten of ${dataToWrite.size} bytes")
                }

                // Read the card again to show updated data
                currentTag?.let {
                    println("DEBUG: Re-reading card to verify write...")
                    readAllBlocks(it, false)
                }
                result.success(true)

            } catch (connectError: Exception) {
                throw Exception("Failed to connect to tag: ${connectError.message}")
            }

        } catch (e: Exception) {
            println("DEBUG: Write error: ${e.message}")
            e.printStackTrace()
            result.error("WRITE_ERROR", e.message, null)
        }
    }

    private fun parseAndSetKeys(keyMap: Map<String, String>) {
        keyMap.forEach { (keyString, hexKey) ->
            try {
                // Key format: "A_0" or "B_3" (type_sector)
                val parts = keyString.split("_")
                if (parts.size == 2) {
                    val keyType = parts[0].uppercase()
                    val sector = try {
                        parts[1].toInt()
                    } catch (e: NumberFormatException) {
                        println("DEBUG: Invalid sector in key string: $keyString")
                        return@forEach
                    }

                    // Clean the hex key
                    val cleanHex = hexKey.replace("\\s".toRegex(), "").uppercase()

                    // Validate hex key length
                    if (cleanHex.length != 12) {
                        println("DEBUG: Invalid key length for $keyString: $cleanHex (expected 12 hex chars)")
                        return@forEach
                    }

                    // Validate hex characters
                    if (!cleanHex.matches(Regex("[0-9A-F]+"))) {
                        println("DEBUG: Invalid hex characters in key: $cleanHex")
                        return@forEach
                    }

                    val keyBytes = hexStringToByteArray(cleanHex)

                    if (keyType == "A") {
                        customKeysA[sector] = keyBytes
                        println("DEBUG: Set custom Key A for sector $sector: $cleanHex")
                    } else if (keyType == "B") {
                        customKeysB[sector] = keyBytes
                        println("DEBUG: Set custom Key B for sector $sector: $cleanHex")
                    } else {
                        println("DEBUG: Unknown key type: $keyType")
                    }
                } else {
                    println("DEBUG: Invalid key format: $keyString (expected format: TYPE_SECTOR)")
                }
            } catch (e: Exception) {
                println("DEBUG: Failed to parse key $keyString: ${e.message}")
            }
        }
    }

    private fun writeToSpecificBlock(data: String, isHex: Boolean, sector: Int, block: Int, result: MethodChannel.Result) {
        try {
            val tag = currentTag ?: run {
                result.error("NO_TAG", "No tag detected", null)
                return
            }

            println("DEBUG: Starting writeToSpecificBlock operation")
            println("DEBUG:   Sector: $sector, Block: $block")
            println("DEBUG:   isHex: $isHex")
            println("DEBUG:   data length: ${data.length}")

            // Get mifare instance BEFORE clearing tag
            val mifare = MifareClassic.get(tag) ?: throw Exception("Not a Mifare Classic tag")

            try {
                mifare.connect()
                println("DEBUG: Connected to Mifare Classic tag")

                // Validate sector and block
                if (sector < 0 || sector >= mifare.sectorCount) {
                    throw Exception("Invalid sector: $sector. Must be 0-${mifare.sectorCount - 1}")
                }

                val blocksPerSector = mifare.getBlockCountInSector(sector)
                if (block < 0 || block >= blocksPerSector) {
                    throw Exception("Invalid block: $block. Sector $sector has blocks 0-${blocksPerSector - 1}")
                }

                // Check if trying to write to manufacturer block
                if (sector == 0 && block == 0) {
                    throw Exception("Cannot write to manufacturer block (Sector 0, Block 0)")
                }

                // Convert data to bytes
                val bytes = if (isHex) {
                    val cleanHex = data.replace("\\s".toRegex(), "").uppercase()
                    if (!cleanHex.matches(Regex("[0-9A-F]+"))) {
                        throw Exception("Invalid hex characters. Use only 0-9, A-F.")
                    }
                    if (cleanHex.length % 2 != 0) {
                        throw Exception("Invalid hex string length. Must be even number of characters.")
                    }
                    if (cleanHex.length > 32) {
                        throw Exception("Hex data too long (max 32 chars = 16 bytes)")
                    }
                    try {
                        ByteArray(cleanHex.length / 2) { i ->
                            cleanHex.substring(i * 2, i * 2 + 2).toInt(16).toByte()
                        }
                    } catch (e: Exception) {
                        throw Exception("Invalid hex format: ${e.message}")
                    }
                } else {
                    if (data.length > 16) {
                        throw Exception("Text too long (max 16 characters)")
                    }
                    data.toByteArray(Charsets.UTF_8)
                }

                if (bytes.isEmpty()) {
                    throw Exception("No data to write")
                }

                println("DEBUG: Data to write (${bytes.size} bytes): ${bytesToHex(bytes)}")

                // Prepare block data (16 bytes)
                val blockData = ByteArray(16) { 0x00 }
                val bytesToCopy = minOf(16, bytes.size)
                System.arraycopy(bytes, 0, blockData, 0, bytesToCopy)

                println("DEBUG: Will write to Sector $sector, Block $block")
                println("DEBUG: Block data: ${bytesToHex(blockData)}")

                // Authenticate sector
                println("DEBUG: Attempting to authenticate sector $sector for write")

                var authenticated = false
                var usedKeyHex = ""

                // Try custom Key A
                customKeysA[sector]?.let { key ->
                    try {
                        if (mifare.authenticateSectorWithKeyA(sector, key)) {
                            authenticated = true
                            usedKeyHex = bytesToHex(key)
                            println("DEBUG: Sector $sector authenticated with custom Key A: $usedKeyHex")
                        }
                    } catch (e: Exception) {
                        println("DEBUG: Custom Key A failed: ${e.message}")
                    }
                }

                // Try custom Key B
                if (!authenticated) {
                    customKeysB[sector]?.let { key ->
                        try {
                            if (mifare.authenticateSectorWithKeyB(sector, key)) {
                                authenticated = true
                                usedKeyHex = bytesToHex(key)
                                println("DEBUG: Sector $sector authenticated with custom Key B: $usedKeyHex")
                            }
                        } catch (e: Exception) {
                            println("DEBUG: Custom Key B failed: ${e.message}")
                        }
                    }
                }

                // Try common keys
                if (!authenticated) {
                    for (commonKey in commonKeys) {
                        try {
                            if (mifare.authenticateSectorWithKeyA(sector, commonKey)) {
                                authenticated = true
                                usedKeyHex = bytesToHex(commonKey)
                                println("DEBUG: Sector $sector authenticated with common Key A: $usedKeyHex")
                                break
                            }
                        } catch (e: Exception) {
                            // Continue
                        }
                    }
                }

                if (!authenticated) {
                    throw Exception("Could not authenticate Sector $sector. Invalid key.")
                }

                // Calculate absolute block number
                val startBlock = mifare.sectorToBlock(sector)
                val absBlock = startBlock + block

                println("DEBUG: Writing to absolute block: $absBlock")

                try {
                    // Write the block
                    mifare.writeBlock(absBlock, blockData)
                    println("DEBUG: Write successful")

                    // Simple verification
                    val verifyData = mifare.readBlock(absBlock)
                    val isTrailerBlock = (block == blocksPerSector - 1)

                    if (!isTrailerBlock) {
                        if (!verifyData.contentEquals(blockData)) {
                            println("DEBUG: Verification failed")
                            println("DEBUG: Expected: ${bytesToHex(blockData)}")
                            println("DEBUG: Got: ${bytesToHex(verifyData)}")
                        } else {
                            println("DEBUG: Verification OK")
                        }
                    } else {
                        println("DEBUG: Trailer block written - skipping full verification")
                    }

                    // Close connection
                    mifare.close()

                    println("DEBUG: Write completed successfully")

                    // Send success immediately
                    result.success(true)

                    // Re-read the card in background
                    Handler(Looper.getMainLooper()).postDelayed({
                        try {
                            // The tag should still be valid after write
                            if (tag != null) {
                                println("DEBUG: Re-reading card after write...")
                                readAllBlocks(tag, false)
                            }
                        } catch (e: Exception) {
                            println("DEBUG: Error in post-write read: ${e.message}")
                        }
                    }, 500)

                } catch (e: Exception) {
                    mifare.close()
                    throw Exception("Failed to write block: ${e.message}")
                }

            } catch (connectError: Exception) {
                throw Exception("Failed to connect to tag: ${connectError.message}")
            }

        } catch (e: Exception) {
            println("DEBUG: Write error: ${e.message}")
            e.printStackTrace()
            result.error("WRITE_ERROR", e.message, null)
        }
    }

    // New method for write authentication that uses temporary key maps
    private fun authenticateSectorForWrite(
        mifare: MifareClassic,
        sector: Int,
        tempKeysA: Map<Int, ByteArray>,
        tempKeysB: Map<Int, ByteArray>
    ): Pair<Boolean, String> {
        println("DEBUG: Attempting to authenticate sector $sector for write")

        // Try custom Key A from temp map
        tempKeysA[sector]?.let { key ->
            try {
                if (mifare.authenticateSectorWithKeyA(sector, key)) {
                    val keyHex = bytesToHex(key)
                    println("DEBUG: Sector $sector authenticated with custom Key A: $keyHex")
                    return Pair(true, keyHex)
                }
            } catch (e: Exception) {
                println("DEBUG: Custom Key A failed: ${e.message}")
            }
        }

        // Try custom Key B from temp map
        tempKeysB[sector]?.let { key ->
            try {
                if (mifare.authenticateSectorWithKeyB(sector, key)) {
                    val keyHex = bytesToHex(key)
                    println("DEBUG: Sector $sector authenticated with custom Key B: $keyHex")
                    return Pair(true, keyHex)
                }
            } catch (e: Exception) {
                println("DEBUG: Custom Key B failed: ${e.message}")
            }
        }

        // Try common keys for Key A
        for (key in commonKeys) {
            try {
                if (mifare.authenticateSectorWithKeyA(sector, key)) {
                    val keyHex = bytesToHex(key)
                    println("DEBUG: Sector $sector authenticated with common Key A: $keyHex")
                    return Pair(true, keyHex)
                }
            } catch (e: Exception) {
                // Continue to next key
            }
        }

        // Try common keys for Key B
        for (key in commonKeys) {
            try {
                if (mifare.authenticateSectorWithKeyB(sector, key)) {
                    val keyHex = bytesToHex(key)
                    println("DEBUG: Sector $sector authenticated with common Key B: $keyHex")
                    return Pair(true, keyHex)
                }
            } catch (e: Exception) {
                // Continue to next key
            }
        }

        println("DEBUG: All authentication attempts failed for sector $sector")
        return Pair(false, "")
    }

    fun onNewIntent(activity: Activity, intent: Intent) {
        val action = intent.action
        println("DEBUG: Plugin onNewIntent called with action: $action")

        if (action == NfcAdapter.ACTION_TECH_DISCOVERED || action == NfcAdapter.ACTION_TAG_DISCOVERED) {
            val tag: Tag? = intent.getParcelableExtra(NfcAdapter.EXTRA_TAG)
            tag?.let {
                currentTag = it
                val uid = bytesToHex(it.id)
                println("DEBUG: New tag detected, UID: $uid")

                // Auto-start reading when a new tag is detected
                if (!isReading) {
                    isReading = true
                    readAllBlocks(it, false)
                }
            }
        }
    }

    private fun Tag?.isConnected(): Boolean {
        return try {
            this?.let {
                val mifare = MifareClassic.get(it)
                mifare?.isConnected ?: false
            } ?: false
        } catch (e: Exception) {
            false
        }
    }

    private fun authenticateSectorWithTracking(mifare: MifareClassic, sector: Int): Pair<Boolean, String> {
        println("DEBUG: Attempting to authenticate sector $sector")

        // Try custom Key A
        customKeysA[sector]?.let { key ->
            try {
                if (mifare.authenticateSectorWithKeyA(sector, key)) {
                    val keyHex = bytesToHex(key)
                    lastUsedKeyType[sector] = "A"
                    lastUsedKeyHex[sector] = keyHex
                    println("DEBUG: Sector $sector authenticated with custom Key A: $keyHex")
                    return Pair(true, keyHex)
                }
            } catch (e: Exception) {
                println("DEBUG: Custom Key A failed: ${e.message}")
            }
        }

        // Try custom Key B
        customKeysB[sector]?.let { key ->
            try {
                if (mifare.authenticateSectorWithKeyB(sector, key)) {
                    val keyHex = bytesToHex(key)
                    lastUsedKeyType[sector] = "B"
                    lastUsedKeyHex[sector] = keyHex
                    println("DEBUG: Sector $sector authenticated with custom Key B: $keyHex")
                    return Pair(true, keyHex)
                }
            } catch (e: Exception) {
                println("DEBUG: Custom Key B failed: ${e.message}")
            }
        }

        // Try common keys for Key A
        for (key in commonKeys) {
            try {
                if (mifare.authenticateSectorWithKeyA(sector, key)) {
                    val keyHex = bytesToHex(key)
                    lastUsedKeyType[sector] = "A"
                    lastUsedKeyHex[sector] = keyHex
                    println("DEBUG: Sector $sector authenticated with common Key A: $keyHex")
                    return Pair(true, keyHex)
                }
            } catch (e: Exception) {
                // Continue to next key
            }
        }

        // Try common keys for Key B
        for (key in commonKeys) {
            try {
                if (mifare.authenticateSectorWithKeyB(sector, key)) {
                    val keyHex = bytesToHex(key)
                    lastUsedKeyType[sector] = "B"
                    lastUsedKeyHex[sector] = keyHex
                    println("DEBUG: Sector $sector authenticated with common Key B: $keyHex")
                    return Pair(true, keyHex)
                }
            } catch (e: Exception) {
                // Continue to next key
            }
        }

        println("DEBUG: All authentication attempts failed for sector $sector")
        return Pair(false, "")
    }

    private fun readAllBlocks(tag: Tag, useCustomKeysOnly: Boolean = false) {
        try {
            println("DEBUG: Starting readAllBlocks (useCustomKeysOnly: $useCustomKeysOnly)")

            val mifare = MifareClassic.get(tag) ?: return

            try {
                val fullUidBytes = tag.id
                val fullUidHex = bytesToHex(fullUidBytes)
                val uidToSend = if (fullUidBytes.size >= 7) {
                    bytesToHex(fullUidBytes.copyOfRange(0, 7))
                } else {
                    fullUidHex
                }

                println("DEBUG: Tag UID: $uidToSend")

                // Try to connect with retry
                var connected = false
                var retryCount = 0
                while (!connected && retryCount < 3) {
                    try {
                        mifare.connect()
                        connected = true
                        println("DEBUG: Connected to tag (attempt ${retryCount + 1})")
                    } catch (e: IOException) {
                        retryCount++
                        println("DEBUG: Connection attempt $retryCount failed: ${e.message}")
                        if (retryCount >= 3) {
                            throw e
                        }
                        Thread.sleep(100) // Wait before retry
                    }
                }

                val resultList = mutableListOf<Map<String, Any>>()
                val keyInfoList = mutableListOf<Map<String, Any>>()
                var successfulSectors = 0

                for (sector in 0 until mifare.sectorCount) {
                    println("DEBUG: Processing sector $sector")

                    var authenticated = false
                    var usedKeyType = ""
                    var usedKeyHex = ""

                    if (!useCustomKeysOnly) {
                        val authResult = authenticateSectorWithTracking(mifare, sector)
                        authenticated = authResult.first
                        usedKeyHex = authResult.second
                        usedKeyType = lastUsedKeyType[sector] ?: ""
                    } else {
                        var tempAuthenticated = false

                        customKeysA[sector]?.let { key ->
                            try {
                                tempAuthenticated = mifare.authenticateSectorWithKeyA(sector, key)
                                if (tempAuthenticated) {
                                    usedKeyType = "A"
                                    usedKeyHex = bytesToHex(key)
                                    lastUsedKeyType[sector] = "A"
                                    lastUsedKeyHex[sector] = usedKeyHex
                                }
                            } catch (e: Exception) { }
                        }

                        if (!tempAuthenticated) {
                            customKeysB[sector]?.let { key ->
                                try {
                                    tempAuthenticated = mifare.authenticateSectorWithKeyB(sector, key)
                                    if (tempAuthenticated) {
                                        usedKeyType = "B"
                                        usedKeyHex = bytesToHex(key)
                                        lastUsedKeyType[sector] = "B"
                                        lastUsedKeyHex[sector] = usedKeyHex
                                    }
                                } catch (e: Exception) { }
                            }
                        }

                        authenticated = tempAuthenticated
                    }

                    if (authenticated) {
                        successfulSectors++

                        keyInfoList.add(hashMapOf(
                            "sector" to sector,
                            "keyType" to usedKeyType,
                            "key" to usedKeyHex,
                            "authenticated" to true
                        ))

                        val startBlock = mifare.sectorToBlock(sector)
                        val blockCount = mifare.getBlockCountInSector(sector)

                        for (block in 0 until blockCount) {
                            val absBlock = startBlock + block
                            val isTrailer = (block == blockCount - 1)

                            try {
                                val data = mifare.readBlock(absBlock)
                                val hexStr = bytesToHex(data)
                                val textStr = data.map { if (it in 32..126) it.toChar() else '.' }.joinToString("")

                                resultList.add(
                                    hashMapOf<String, Any>(
                                        "sector" to sector,
                                        "block" to block,
                                        "absBlock" to absBlock,
                                        "hex" to hexStr,
                                        "text" to textStr,
                                        "isTrailer" to isTrailer,
                                        "keyType" to usedKeyType,
                                        "key" to usedKeyHex
                                    )
                                )

                            } catch (e: Exception) {
                                resultList.add(
                                    hashMapOf<String, Any>(
                                        "sector" to sector,
                                        "block" to block,
                                        "absBlock" to absBlock,
                                        "hex" to "READ ERROR",
                                        "text" to "READ ERROR",
                                        "isTrailer" to isTrailer,
                                        "keyType" to usedKeyType,
                                        "key" to usedKeyHex
                                    )
                                )
                            }
                        }
                    } else {
                        keyInfoList.add(hashMapOf(
                            "sector" to sector,
                            "keyType" to "",
                            "key" to "",
                            "authenticated" to false
                        ))

                        val startBlock = mifare.sectorToBlock(sector)
                        val blockCount = mifare.getBlockCountInSector(sector)

                        for (block in 0 until blockCount) {
                            val absBlock = startBlock + block
                            val isTrailer = (block == blockCount - 1)

                            resultList.add(
                                hashMapOf<String, Any>(
                                    "sector" to sector,
                                    "block" to block,
                                    "absBlock" to absBlock,
                                    "hex" to "AUTH ERROR",
                                    "text" to "AUTH ERROR",
                                    "isTrailer" to isTrailer,
                                    "keyType" to "",
                                    "key" to ""
                                )
                            )
                        }
                    }
                }

                mifare.close()

                println("DEBUG: Read completed. Successful sectors: $successfulSectors/${mifare.sectorCount}")

                isReading = false

                eventSink?.success(
                    hashMapOf<String, Any>(
                        "uid" to uidToSend,
                        "blocks" to resultList,
                        "keyInfo" to keyInfoList,
                        "type" to mifare.type.toString(),
                        "size" to mifare.size,
                        "sectorCount" to mifare.sectorCount,
                        "successfulSectors" to successfulSectors,
                        "fullUid" to uidToSend
                    )
                )

            } catch (e: IOException) {
                println("DEBUG: IO Exception during read: ${e.message}")
                eventSink?.success(hashMapOf<String, Any>("error" to "Tag disconnected. Please tap card again."))
                // Clear current tag to force fresh detection
                clearCurrentTag()
            } catch (e: Exception) {
                println("DEBUG: Error in readAllBlocks: ${e.message}")
                e.printStackTrace()
                eventSink?.success(hashMapOf<String, Any>("error" to "Read error: ${e.message}"))
                isReading = false
            }

        } catch (e: Exception) {
            println("DEBUG: Outer error in readAllBlocks: ${e.message}")
            eventSink?.success(hashMapOf<String, Any>("error" to "Tag error: ${e.message}"))
            isReading = false
        }
    }


    private fun hexStringToByteArray(hex: String): ByteArray {
        val cleanHex = hex.replace("\\s".toRegex(), "").uppercase()
        require(cleanHex.length % 2 == 0) { "Invalid hex string length" }
        return ByteArray(cleanHex.length / 2) { i ->
            cleanHex.substring(i * 2, i * 2 + 2).toInt(16).toByte()
        }
    }

    private fun bytesToHex(bytes: ByteArray): String {
        if (bytes.isEmpty()) return ""
        val hexChars = CharArray(bytes.size * 2)
        for (i in bytes.indices) {
            val v = bytes[i].toInt() and 0xFF
            hexChars[i * 2] = "0123456789ABCDEF"[v ushr 4]
            hexChars[i * 2 + 1] = "0123456789ABCDEF"[v and 0x0F]
        }
        return String(hexChars)
    }

    // Storage methods
    private fun saveCardKeysToStorage(call: MethodCall, result: Result) {
        try {
            val keysJson = call.argument<String>("keysJson")
            val context = applicationContext ?: return
            val sharedPref = context.getSharedPreferences("mifare_keys", Context.MODE_PRIVATE)
            sharedPref.edit().putString("saved_card_keys", keysJson).apply()
            println("DEBUG: Saved card keys to storage")
            result.success(true)
        } catch (e: Exception) {
            println("DEBUG: Error saving card keys to storage: ${e.message}")
            result.error("SAVE_KEYS_ERROR", "Failed to save keys", e.message)
        }
    }

    private fun loadCardKeysFromStorage(call: MethodCall, result: Result) {
        try {
            val context = applicationContext ?: return
            val sharedPref = context.getSharedPreferences("mifare_keys", Context.MODE_PRIVATE)
            val keysJson = sharedPref.getString("saved_card_keys", "")
            println("DEBUG: Loaded card keys from storage: ${keysJson?.length ?: 0} chars")
            result.success(keysJson)
        } catch (e: Exception) {
            println("DEBUG: Error loading card keys from storage: ${e.message}")
            result.error("LOAD_KEYS_ERROR", "Failed to load keys", e.message)
        }
    }

    private fun setSectorKeyBatch(call: MethodCall, result: Result) {
        try {
            val uid = call.argument<String>("uid")
            val keyType = call.argument<String>("keyType")
            val key = call.argument<String>("key")

            if (uid == null || keyType == null || key == null) {
                result.error("INVALID_ARGS", "Missing arguments", null)
                return
            }

            // Store in card keys map
            if (!cardKeys.containsKey(uid)) {
                cardKeys[uid] = mutableMapOf()
            }
            cardKeys[uid]!![keyType] = key

            // Also set as custom key for all sectors (for immediate use)
            val keyBytes = hexStringToByteArray(key)
            for (sector in 0..15) {
                if (keyType == "A") {
                    customKeysA[sector] = keyBytes
                } else {
                    customKeysB[sector] = keyBytes
                }
            }

            println("DEBUG: Set $keyType=$key for all sectors for card $uid")
            result.success(true)
        } catch (e: Exception) {
            println("DEBUG: Error setting sector key batch: ${e.message}")
            result.error("SET_KEY_BATCH_ERROR", "Failed to set keys", e.message)
        }
    }

    private fun removeKeyForCard(call: MethodCall, result: Result) {
        try {
            val uid = call.argument<String>("uid")
            val keyType = call.argument<String>("keyType")

            if (uid == null || keyType == null) {
                result.error("INVALID_ARGS", "Missing arguments", null)
                return
            }

            // Remove from card keys map
            if (cardKeys.containsKey(uid)) {
                cardKeys[uid]!!.remove(keyType)
                if (cardKeys[uid]!!.isEmpty()) {
                    cardKeys.remove(uid)
                }
            }

            println("DEBUG: Removed $keyType key for card $uid")
            result.success(true)
        } catch (e: Exception) {
            println("DEBUG: Error removing key for card: ${e.message}")
            result.error("REMOVE_KEY_ERROR", "Failed to remove key", e.message)
        }
    }

    private fun clearAllCardKeys(result: Result) {
        try {
            // Clear from memory
            cardKeys.clear()

            // Clear from storage
            val context = applicationContext ?: return
            val sharedPref = context.getSharedPreferences("mifare_keys", Context.MODE_PRIVATE)
            sharedPref.edit().remove("saved_card_keys").apply()

            println("DEBUG: All card keys cleared")
            result.success(true)
        } catch (e: Exception) {
            println("DEBUG: Error clearing all card keys: ${e.message}")
            result.error("CLEAR_KEYS_ERROR", "Failed to clear keys", e.message)
        }
    }

    // Helper method to load saved keys on startup
    private fun loadSavedKeysFromStorage() {
        try {
            val context = applicationContext ?: return
            val sharedPref = context.getSharedPreferences("mifare_keys", Context.MODE_PRIVATE)
            val keysJson = sharedPref.getString("saved_card_keys", "")

            if (!keysJson.isNullOrEmpty()) {
                val jsonObject = JSONObject(keysJson)
                val keys = jsonObject.keys()
                while (keys.hasNext()) {
                    val uid = keys.next()
                    val cardKeyObject = jsonObject.getJSONObject(uid)
                    cardKeys[uid] = mutableMapOf()

                    val keyTypes = cardKeyObject.keys()
                    while (keyTypes.hasNext()) {
                        val keyType = keyTypes.next()
                        val key = cardKeyObject.getString(keyType)
                        cardKeys[uid]!![keyType] = key
                    }
                }
                println("DEBUG: Loaded ${cardKeys.size} cards with saved keys from storage")
            }
        } catch (e: Exception) {
            println("DEBUG: Error loading saved keys from storage: ${e.message}")
        }
    }
    private fun setCustomKeys(call: MethodCall, result: Result) {
        try {
            val keysMap = call.argument<Map<String, String>>("keys")

            if (keysMap != null) {
                println("DEBUG: Setting custom keys from Flutter")

                // Clear existing custom keys first
                customKeysA.clear()
                customKeysB.clear()

                // Parse and set the keys
                keysMap.forEach { (keyString, hexKey) ->
                    try {
                        // Key format: "A_0" or "B_3" (type_sector)
                        val parts = keyString.split("_")
                        if (parts.size == 2) {
                            val keyType = parts[0].uppercase()
                            val sector = try {
                                parts[1].toInt()
                            } catch (e: NumberFormatException) {
                                println("DEBUG: Invalid sector in key string: $keyString")
                                return@forEach
                            }

                            // Clean the hex key
                            val cleanHex = hexKey.replace("\\s".toRegex(), "").uppercase()

                            // Validate hex key length
                            if (cleanHex.length != 12) {
                                println("DEBUG: Invalid key length for $keyString: $cleanHex (expected 12 hex chars)")
                                return@forEach
                            }

                            val keyBytes = hexStringToByteArray(cleanHex)

                            if (keyType == "A") {
                                customKeysA[sector] = keyBytes
                                println("DEBUG: Set custom Key A for sector $sector: $cleanHex")
                            } else if (keyType == "B") {
                                customKeysB[sector] = keyBytes
                                println("DEBUG: Set custom Key B for sector $sector: $cleanHex")
                            }
                        }
                    } catch (e: Exception) {
                        println("DEBUG: Failed to parse key $keyString: ${e.message}")
                    }
                }

                println("DEBUG: Successfully set ${customKeysA.size} Key A and ${customKeysB.size} Key B")
                result.success(true)
            } else {
                result.error("INVALID_ARGS", "No keys provided", null)
            }
        } catch (e: Exception) {
            println("DEBUG: Error in setCustomKeys: ${e.message}")
            result.error("SET_CUSTOM_KEYS_ERROR", "Failed to set custom keys", e.message)
        }
    }
}