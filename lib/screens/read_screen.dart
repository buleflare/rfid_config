import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/nfc_provider.dart';

class ReadScreen extends StatefulWidget {
  const ReadScreen({super.key});

  @override
  State<ReadScreen> createState() => _ReadScreenState();
}

class _ReadScreenState extends State<ReadScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<NfcProvider>(context, listen: false);
      provider.startScan();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Read Mifare Card'),
        backgroundColor: Colors.blue.shade800,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              Provider.of<NfcProvider>(context, listen: false).startScan();
            },
          ),
        ],
      ),
      body: Consumer<NfcProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!provider.isNfcAvailable) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error,
                    color: Colors.red,
                    size: 60,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'NFC not available on this device',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'This app requires NFC hardware to work',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (provider.errorMessage.isNotEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error,
                    color: Colors.orange,
                    size: 60,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    provider.errorMessage,
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => provider.startScan(),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            );
          }

          if (provider.cardData.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.nfc,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Hold your Mifare Classic 1K card\nnear the NFC antenna',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => provider.startScan(),
                    icon: const Icon(Icons.search),
                    label: const Text('Start Scanning'),
                  ),
                ],
              ),
            );
          }

          // Safely get blocks data
          final blocks = _getBlocksFromData(provider.cardData);

          // Safely get readingKey with null check
          final readingKey = _getStringFromData(provider.cardData, 'readingKey', 'Key A (Default)');

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card Info
                  Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Card Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow('UID', _getStringFromData(provider.cardData, 'uid', 'N/A')),
                          _buildInfoRow('Type', _getStringFromData(provider.cardData, 'type', 'N/A')),
                          _buildInfoRow('Size', '${_getIntFromData(provider.cardData, 'size', 0)} bytes'),
                          _buildInfoRow('Sectors', '${_getIntFromData(provider.cardData, 'sectorCount', 0)}'),
                          _buildInfoRow('Successfully Read', '${_getIntFromData(provider.cardData, 'successfulSectors', 0)} sectors'),
                          _buildInfoRow('Reading Key', readingKey),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Reading Status Info
                  Card(
                    elevation: 3,
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info, color: Colors.blue.shade800),
                              const SizedBox(width: 8),
                              const Text(
                                'Reading Information',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• Using $readingKey to read sectors',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            '• Key A is never readable in trailer blocks (by design)',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            '• Key B may be readable depending on access bits',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            '• Access bits control which keys can read/write data',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Blocks List
                  const Text(
                    'Memory Blocks',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (blocks.isNotEmpty) ..._buildSectorViews(blocks, readingKey),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Helper methods for safe data extraction
  List<Map<String, dynamic>> _getBlocksFromData(Map<Object?, Object?> cardData) {
    try {
      final blocks = cardData['blocks'];
      if (blocks is List) {
        return blocks.map((item) {
          if (item is Map<String, dynamic>) {
            return item;
          } else if (item is Map) {
            // Convert Map<Object?, Object?> to Map<String, dynamic>
            return Map<String, dynamic>.fromEntries(
                item.entries.map((e) =>
                    MapEntry(e.key.toString(), e.value)
                )
            );
          }
          return <String, dynamic>{};
        }).toList();
      }
    } catch (e) {
      print('Error getting blocks: $e');
    }
    return [];
  }

  String _getStringFromData(Map<Object?, Object?> cardData, String key, String defaultValue) {
    try {
      final value = cardData[key];
      if (value is String) return value;
      if (value != null) return value.toString();
    } catch (e) {
      print('Error getting string for key $key: $e');
    }
    return defaultValue;
  }

  int _getIntFromData(Map<Object?, Object?> cardData, String key, int defaultValue) {
    try {
      final value = cardData[key];
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? defaultValue;
    } catch (e) {
      print('Error getting int for key $key: $e');
    }
    return defaultValue;
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSectorViews(List<Map<String, dynamic>> blocks, String readingKey) {
    // Group blocks by sector
    Map<int, List<Map<String, dynamic>>> sectors = {};
    for (var block in blocks) {
      final sector = (block['sector'] as int?) ?? 0;
      if (!sectors.containsKey(sector)) {
        sectors[sector] = [];
      }
      sectors[sector]!.add(block);
    }

    // Create sector widgets
    return sectors.entries.map((entry) {
      return _buildSectorCard(entry.key, entry.value, readingKey);
    }).toList();
  }

  Widget _buildSectorCard(int sector, List<Map<String, dynamic>> blocks, String readingKey) {
    // Check if this sector was read successfully
    final hasAuthError = blocks.any((block) {
      final hex = (block['hex'] as String?) ?? '';
      return hex == 'AUTH ERROR' || hex == 'READ ERROR';
    });

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: hasAuthError ? Colors.red.shade100 : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Sector $sector',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: hasAuthError ? Colors.red.shade800 : Colors.blue.shade800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: readingKey.contains('Key A') ? Colors.blue.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: readingKey.contains('Key A') ? Colors.blue.shade200 : Colors.green.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        readingKey.contains('Key A') ? Icons.vpn_key : Icons.key,
                        size: 12,
                        color: readingKey.contains('Key A') ? Colors.blue : Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        readingKey,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: readingKey.contains('Key A') ? Colors.blue : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '${blocks.length} blocks',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...blocks.map((block) {
              final isTrailer = (block['isTrailer'] as bool?) ?? false;
              return isTrailer
                  ? _buildTrailerBlockRow(block, readingKey)
                  : _buildDataBlockRow(block, readingKey);
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildDataBlockRow(Map<String, dynamic> block, String readingKey) {
    final hex = (block['hex'] as String?) ?? '';
    final text = (block['text'] as String?) ?? '';
    final blockNum = (block['block'] as int?) ?? 0;
    final absBlock = (block['absBlock'] as int?) ?? 0;
    final isError = hex == 'AUTH ERROR' || hex == 'READ ERROR';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isError ? Colors.red.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError ? Colors.red.shade200 : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip(
                label: Text(
                  'Block $blockNum',
                  style: TextStyle(
                    fontSize: 12,
                    color: isError ? Colors.red.shade800 : Colors.blue.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: isError ? Colors.red.shade100 : Colors.blue.shade100,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              Text(
                'Abs: $absBlock',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const Spacer(),
              // Show which key was used to read this block
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: readingKey.contains('Key A') ? Colors.blue.shade100 : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      readingKey.contains('Key A') ? Icons.vpn_key : Icons.key,
                      size: 12,
                      color: readingKey.contains('Key A') ? Colors.blue : Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Read with ${readingKey.contains('Key A') ? 'A' : 'B'}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: readingKey.contains('Key A') ? Colors.blue : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (!isError) ...[
            SelectableText(
              'Hex: $hex',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              'Text: "$text"',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ] else ...[
            Row(
              children: [
                Icon(Icons.error, size: 14, color: Colors.red),
                const SizedBox(width: 4),
                Text(
                  hex,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Cannot read with current key',
              style: TextStyle(
                fontSize: 11,
                color: Colors.red.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrailerBlockRow(Map<String, dynamic> block, String readingKey) {
    final hex = (block['hex'] as String?) ?? '';
    final blockNum = (block['block'] as int?) ?? 0;
    final absBlock = (block['absBlock'] as int?) ?? 0;
    final isError = hex == 'AUTH ERROR' || hex == 'READ ERROR';

    // If error, show the error message
    if (isError) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.red.shade200,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(
                    'Block $blockNum (Trailer)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: Colors.red.shade100,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                Text(
                  'Abs: $absBlock',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: readingKey.contains('Key A') ? Colors.blue.shade100 : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        readingKey.contains('Key A') ? Icons.vpn_key : Icons.key,
                        size: 12,
                        color: readingKey.contains('Key A') ? Colors.blue : Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Trying ${readingKey.contains('Key A') ? 'A' : 'B'}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: readingKey.contains('Key A') ? Colors.blue : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.error, size: 14, color: Colors.red),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'AUTHENTICATION ERROR - Cannot read with ${readingKey.contains('Key A') ? 'Key A' : 'Key B'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Trailer block access denied with current key',
              style: TextStyle(
                fontSize: 11,
                color: Colors.red.shade600,
              ),
            ),
          ],
        ),
      );
    }

    // Parse the trailer block (16 bytes = 32 hex characters)
    // Format: Key A (6 bytes) + Access Bits (4 bytes) + Key B (6 bytes)
    String keyAHex = '';
    String accessBitsHex = '';
    String keyBHex = '';

    if (hex.length >= 32) {
      keyAHex = hex.substring(0, 12); // 6 bytes = 12 hex chars
      accessBitsHex = hex.substring(12, 20); // 4 bytes = 8 hex chars (B6,B7,B8 + user byte)
      keyBHex = hex.substring(20, 32); // 6 bytes = 12 hex chars
    }

    // Determine if Key B is readable based on access bits
    final bool isKeyBReadable = _isKeyBReadable(accessBitsHex);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.orange.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip(
                label: Text(
                  'Block $blockNum (Trailer)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: Colors.orange.shade100,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              Text(
                'Abs: $absBlock',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: readingKey.contains('Key A') ? Colors.blue.shade100 : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      readingKey.contains('Key A') ? Icons.vpn_key : Icons.key,
                      size: 12,
                      color: readingKey.contains('Key A') ? Colors.blue : Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Read with ${readingKey.contains('Key A') ? 'A' : 'B'}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: readingKey.contains('Key A') ? Colors.blue : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Key A Section
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.vpn_key, size: 16, color: Colors.blue.shade800),
                    const SizedBox(width: 6),
                    const Text(
                      'Key A (Never Readable)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.visibility_off, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(
                        keyAHex.isNotEmpty ? keyAHex : '????????????',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Key A is never readable (by MIFARE design)',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Access Bits Section
          if (accessBitsHex.isNotEmpty) Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lock, size: 16, color: Colors.purple.shade800),
                    const SizedBox(width: 6),
                    const Text(
                      'Access Bits',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(
                            accessBitsHex.substring(0, 6), // B6,B7,B8
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'B6,B7,B8 (3 bytes)',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(
                            accessBitsHex.substring(6, 8), // User byte
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            'User Byte (0x69 = Key B readable)',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ElevatedButton(
                  onPressed: () {
                    // Navigate to Access Bits Tool with the access bits
                    Navigator.pushNamed(
                      context,
                      '/access-bits-tool',
                      arguments: {'accessBits': accessBitsHex.substring(0, 6)},
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 30),
                    backgroundColor: Colors.purple.shade100,
                    foregroundColor: Colors.purple.shade800,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    'Decode Access Bits',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ) else Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Access bits not available',
              style: TextStyle(fontSize: 12),
            ),
          ),

          const SizedBox(height: 8),

          // Key B Section
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isKeyBReadable ? Colors.green.shade50 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.key, size: 16,
                        color: isKeyBReadable ? Colors.green.shade800 : Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      'Key B ${isKeyBReadable ? '(Readable)' : '(Not Readable)'}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isKeyBReadable ? Colors.green : Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (isKeyBReadable && keyBHex.isNotEmpty) ...[
                  SelectableText(
                    keyBHex,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Key B is readable (access bits allow it)',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green.shade600,
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.visibility_off, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          keyBHex.isNotEmpty ? keyBHex : '????????????',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    isKeyBReadable
                        ? 'Key B not present in data'
                        : 'Key B is not readable (access bits prevent it)',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Full block hex for reference
          if (hex.isNotEmpty) Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Full Block Hex',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  hex,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper function to determine if Key B is readable based on access bits
  bool _isKeyBReadable(String accessBitsHex) {
    if (accessBitsHex.length < 8) return false;

    // User byte is the last byte of access bits (position 6-7)
    final userByte = accessBitsHex.substring(6, 8);

    // User byte 0x69 (or 0x00, 0x01, 0x02, etc.) determines Key B readability
    // According to MIFARE spec, if user byte is 0x69, Key B is readable
    // If user byte is 0x00, Key B is not readable (used as data)
    return userByte == '69';
  }
}