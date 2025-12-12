package com.mm.ylp.rfid.rfid_v1

import android.app.Activity
import android.content.Intent
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.MifareClassic
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

object MifareClassicPlugin {

    private var eventSink: EventChannel.EventSink? = null
    private var currentTag: Tag? = null

    fun setup(flutterEngine: FlutterEngine, activity: Activity) {
        val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mifare_classic/method")
        val eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "mifare_classic/events")

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startScan" -> result.success(true)
                "writeData" -> {
                    val data = call.argument<String>("data") ?: ""
                    val isHex = call.argument<Boolean>("isHex") ?: false
                    val sector = call.argument<Int>("sector")
                    val block = call.argument<Int>("block")

                    if (sector != null && block != null) {
                        // Use specific block writing
                        writeToSpecificBlock(data, isHex, sector, block, result)
                    } else {
                        // Use original multi-block writing
                        val dataString = call.argument<String>("data") ?: ""
                        val isHexParam = call.argument<Boolean>("isHex") ?: false

                        val tag = currentTag ?: run {
                            result.error("NO_TAG", "No tag detected. Please bring card closer.", null)
                            return@setMethodCallHandler
                        }

                        println("DEBUG: Starting writeData (multi-block) operation")
                        println("DEBUG:   isHex: $isHexParam")

                        val mifare = MifareClassic.get(tag) ?: run {
                            result.error("NOT_MIFARE", "Not a Mifare Classic tag", null)
                            return@setMethodCallHandler
                        }

                        try {
                            mifare.connect()
                            println("DEBUG: Connected to Mifare Classic tag")
                            _writeNormalData(mifare, dataString, isHexParam, result)
                        } catch (connectError: Exception) {
                            result.error("CONNECT_ERROR", "Failed to connect to tag: ${connectError.message}", null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    private fun writeToSpecificBlock(data: String, isHex: Boolean, sector: Int, block: Int, result: MethodChannel.Result) {
        try {
            val tag = currentTag ?: run {
                result.error("NO_TAG", "No tag detected. Please bring card closer.", null)
                return
            }

            println("DEBUG: Starting writeToSpecificBlock operation")
            println("DEBUG:   Sector: $sector, Block: $block")
            println("DEBUG:   isHex: $isHex")
            println("DEBUG:   data length: ${data.length}")
            println("DEBUG:   first 20 chars: ${data.take(20)}")

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

                // Check if trying to write to trailer block
                val isTrailerBlock = (block == blocksPerSector - 1)
                if (isTrailerBlock) {
                    throw Exception("Cannot write to trailer block directly. Use configuration instead.")
                }

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

                // Check if bytes array is empty
                if (bytes.isEmpty()) {
                    throw Exception("No data to write")
                }

                println("DEBUG: Data to write (${bytes.size} bytes): ${bytesToHex(bytes.take(32).toByteArray())}")

                // Prepare block data (16 bytes)
                val blockData = ByteArray(16) { 0x00 }
                val bytesToCopy = minOf(16, bytes.size)

                // Copy data to block
                System.arraycopy(bytes, 0, blockData, 0, bytesToCopy)

                println("DEBUG: Will write to Sector $sector, Block $block")
                println("DEBUG: Block data: ${bytesToHex(blockData)}")

                // Define common keys to try for authentication
                val commonKeys = arrayOf(
                    byteArrayOf(0xD3.toByte(), 0xF7.toByte(), 0xD3.toByte(), 0xF7.toByte(), 0xD3.toByte(), 0xF7.toByte()),
                    byteArrayOf(0xFF.toByte(), 0xFF.toByte(), 0xFF.toByte(), 0xFF.toByte(), 0xFF.toByte(), 0xFF.toByte()),
                    byteArrayOf(0xA0.toByte(), 0xA1.toByte(), 0xA2.toByte(), 0xA3.toByte(), 0xA4.toByte(), 0xA5.toByte()),
                    byteArrayOf(0x00.toByte(), 0x00.toByte(), 0x00.toByte(), 0x00.toByte(), 0x00.toByte(), 0x00.toByte())
                )

                // Try to authenticate sector
                var authenticated = false
                var authKey: ByteArray? = null

                for (key in commonKeys) {
                    try {
                        authenticated = mifare.authenticateSectorWithKeyA(sector, key)
                        if (authenticated) {
                            authKey = key
                            println("DEBUG: Sector $sector authenticated with Key A: ${bytesToHex(key)}")
                            break
                        }
                    } catch (e: Exception) {
                        println("DEBUG: Key A failed for sector $sector: ${e.message}")
                    }

                    if (!authenticated) {
                        try {
                            authenticated = mifare.authenticateSectorWithKeyB(sector, key)
                            if (authenticated) {
                                authKey = key
                                println("DEBUG: Sector $sector authenticated with Key B: ${bytesToHex(key)}")
                                break
                            }
                        } catch (e: Exception) {
                            println("DEBUG: Key B failed for sector $sector: ${e.message}")
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

                    // Verify the write
                    val verifyData = mifare.readBlock(absBlock)
                    if (!verifyData.contentEquals(blockData)) {
                        println("DEBUG: Verification FAILED")
                        println("DEBUG:   Expected: ${bytesToHex(blockData)}")
                        println("DEBUG:   Got: ${bytesToHex(verifyData)}")
                        throw Exception("Write verification failed")
                    } else {
                        println("DEBUG: Verification OK")
                    }

                    mifare.close()

                    // Read the card again to show updated data
                    currentTag?.let {
                        println("DEBUG: Re-reading card to verify write...")
                        readAllBlocks(it)
                    }

                    result.success(true)

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

    fun onNewIntent(activity: Activity, intent: Intent) {
        val action = intent.action
        if (action == NfcAdapter.ACTION_TAG_DISCOVERED || action == NfcAdapter.ACTION_TECH_DISCOVERED) {
            val tag: Tag? = intent.getParcelableExtra(NfcAdapter.EXTRA_TAG)
            tag?.let {
                currentTag = it
                readAllBlocks(it)
            }
        }
    }

    private fun readAllBlocks(tag: Tag) {
        try {
            println("DEBUG: Starting readAllBlocks")
            val mifare = MifareClassic.get(tag) ?: return

            // Get the FULL UID from the tag
            val fullUidBytes = tag.id
            val fullUidHex = bytesToHex(fullUidBytes)
            println("DEBUG: Full UID bytes: ${fullUidBytes.size} - Hex: $fullUidHex")

            // For Mifare Classic, UID should be 4 or 7 bytes
            val uidToSend = if (fullUidBytes.size >= 7) {
                // Take first 7 bytes for extended UID
                bytesToHex(fullUidBytes.copyOfRange(0, 7))
            } else {
                // Use whatever we have
                fullUidHex
            }

            println("DEBUG: UID to send: $uidToSend")

            val type = mifare.type
            val size = mifare.size
            val sectorCount = mifare.sectorCount
            println("DEBUG: Card type: $type, size: $size, sectors: $sectorCount")

            mifare.connect()
            println("DEBUG: Connected to tag")

            val resultList = mutableListOf<Map<String, Any>>()

            var successfulSectors = 0

            // Define possible keys to try
            val commonKeys = arrayOf(
                byteArrayOf(0xFF.toByte(), 0xFF.toByte(), 0xFF.toByte(), 0xFF.toByte(), 0xFF.toByte(), 0xFF.toByte()),
                byteArrayOf(0xA0.toByte(), 0xA1.toByte(), 0xA2.toByte(), 0xA3.toByte(), 0xA4.toByte(), 0xA5.toByte()),
                byteArrayOf(0xD3.toByte(), 0xF7.toByte(), 0xD3.toByte(), 0xF7.toByte(), 0xD3.toByte(), 0xF7.toByte()),
                byteArrayOf(0x00.toByte(), 0x00.toByte(), 0x00.toByte(), 0x00.toByte(), 0x00.toByte(), 0x00.toByte())
            )

            for (sector in 0 until sectorCount) {
                println("DEBUG: Trying sector $sector")
                var authenticated = false
                var usedKey: ByteArray? = null

                // Try key A first
                for (key in commonKeys) {
                    try {
                        authenticated = mifare.authenticateSectorWithKeyA(sector, key)
                        if (authenticated) {
                            usedKey = key
                            println("DEBUG: Sector $sector authenticated with key A: ${bytesToHex(key)}")
                            break
                        }
                    } catch (e: Exception) {
                        // Continue to next key
                    }
                }

                // Try key B if key A fails
                if (!authenticated) {
                    for (key in commonKeys) {
                        try {
                            authenticated = mifare.authenticateSectorWithKeyB(sector, key)
                            if (authenticated) {
                                usedKey = key
                                println("DEBUG: Sector $sector authenticated with key B: ${bytesToHex(key)}")
                                break
                            }
                        } catch (e: Exception) {
                            // Continue to next key
                        }
                    }
                }

                if (authenticated) {
                    successfulSectors++
                    val startBlock = mifare.sectorToBlock(sector)
                    val blockCount = mifare.getBlockCountInSector(sector)
                    println("DEBUG: Sector $sector - startBlock: $startBlock, blockCount: $blockCount")

                    for (block in 0 until blockCount) {
                        val absBlock = startBlock + block

                        // Check if this is a trailer block (last block in sector)
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
                                    "isTrailer" to isTrailer
                                )
                            )

                            println("DEBUG: Read block $absBlock (sector $sector, block $block): $hexStr")
                        } catch (e: Exception) {
                            println("DEBUG: Failed to read block $absBlock: ${e.message}")
                            resultList.add(
                                hashMapOf<String, Any>(
                                    "sector" to sector,
                                    "block" to block,
                                    "absBlock" to absBlock,
                                    "hex" to "READ ERROR",
                                    "text" to "READ ERROR",
                                    "isTrailer" to isTrailer
                                )
                            )
                        }
                    }
                } else {
                    println("DEBUG: Failed to authenticate sector $sector")
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
                                "isTrailer" to isTrailer
                            )
                        )
                    }
                }
            }

            mifare.close()
            println("DEBUG: Successfully read $successfulSectors sectors, ${resultList.size} blocks total")

            eventSink?.success(
                hashMapOf<String, Any>(
                    "uid" to uidToSend,
                    "blocks" to resultList,
                    "type" to type.toString(),
                    "size" to size,
                    "sectorCount" to sectorCount,
                    "successfulSectors" to successfulSectors,
                    "fullUid" to uidToSend
                )
            )

        } catch (e: Exception) {
            println("DEBUG: Error in readAllBlocks: ${e.message}")
            e.printStackTrace()
            eventSink?.success(hashMapOf<String, Any>("error" to "Read error: ${e.message}"))
        }
    }

    private fun writeData(call: MethodCall, result: MethodChannel.Result) {
        try {
            val dataString = call.argument<String>("data") ?: ""
            val isHex = call.argument<Boolean>("isHex") ?: false

            val tag = currentTag ?: run {
                result.error("NO_TAG", "No tag detected. Please bring card closer.", null)
                return
            }

            println("DEBUG: Starting writeData operation")
            println("DEBUG:   isHex: $isHex")
            println("DEBUG:   data length: ${dataString.length}")
            println("DEBUG:   first 20 chars: ${dataString.take(20)}")

            val mifare = MifareClassic.get(tag) ?: throw Exception("Not a Mifare Classic tag")

            try {
                mifare.connect()
                println("DEBUG: Connected to Mifare Classic tag")

                // Call the write function that actually exists
                _writeNormalData(mifare, dataString, isHex, result)
            } catch (connectError: Exception) {
                throw Exception("Failed to connect to tag: ${connectError.message}")
            }

        } catch (e: Exception) {
            println("DEBUG: Write error: ${e.message}")
            e.printStackTrace()
            result.error("WRITE_ERROR", e.message, null)
        }
    }

    private fun _writeNormalData(mifare: MifareClassic, dataString: String, isHex: Boolean, result: MethodChannel.Result) {
        // Convert data to bytes
        val bytes = if (isHex) {
            // Validate hex string
            val cleanHex = dataString.replace("\\s".toRegex(), "").uppercase()

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
            dataString.toByteArray(Charsets.UTF_8)
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

        // Define common keys to try for authentication
        val commonKeys = arrayOf(
            byteArrayOf(0xD3.toByte(), 0xF7.toByte(), 0xD3.toByte(), 0xF7.toByte(), 0xD3.toByte(), 0xF7.toByte()),
            byteArrayOf(0xFF.toByte(), 0xFF.toByte(), 0xFF.toByte(), 0xFF.toByte(), 0xFF.toByte(), 0xFF.toByte()),
            byteArrayOf(0xA0.toByte(), 0xA1.toByte(), 0xA2.toByte(), 0xA3.toByte(), 0xA4.toByte(), 0xA5.toByte()),
            byteArrayOf(0x00.toByte(), 0x00.toByte(), 0x00.toByte(), 0x00.toByte(), 0x00.toByte(), 0x00.toByte())
        )

        // Start from sector 1 (skip sector 0 which is manufacturer)
        for (sector in 1 until sectorCount) {
            // Check if we have more data to write
            if (dataIndex >= dataToWrite.size) {
                println("DEBUG: All data written (stopping at sector $sector)")
                break
            }

            println("DEBUG: === Processing sector $sector ===")

            // Try to authenticate sector
            var authenticated = false
            var authKey: ByteArray? = null

            for (key in commonKeys) {
                try {
                    authenticated = mifare.authenticateSectorWithKeyA(sector, key)
                    if (authenticated) {
                        authKey = key
                        println("DEBUG: Sector $sector authenticated with Key A: ${bytesToHex(key)}")
                        break
                    }
                } catch (e: Exception) {
                    println("DEBUG: Key A failed for sector $sector: ${e.message}")
                }

                if (!authenticated) {
                    try {
                        authenticated = mifare.authenticateSectorWithKeyB(sector, key)
                        if (authenticated) {
                            authKey = key
                            println("DEBUG: Sector $sector authenticated with Key B: ${bytesToHex(key)}")
                            break
                        }
                    } catch (e: Exception) {
                        println("DEBUG: Key B failed for sector $sector: ${e.message}")
                    }
                }
            }

            if (!authenticated) {
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
            readAllBlocks(it)
        }
        result.success(true)
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
}