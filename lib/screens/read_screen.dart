import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              _showLastScannedInfo(context);
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

          // Use the new provider methods to get data
          final blocks = provider.getBlocks();
          final keyInfo = provider.getKeyInfo();
          final uid = provider.getCardInfo('uid', 'N/A');
          final type = provider.getCardInfo('type', 'N/A');
          final size = provider.getCardInfoInt('size', 0);
          final sectorCount = provider.getCardInfoInt('sectorCount', 0);
          final successfulSectors = provider.getCardInfoInt('successfulSectors', 0);
          final fullUid = provider.getCardInfo('fullUid', uid);

// In the Consumer builder in ReadScreen
          if (!provider.isLoading && provider.cardData.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.nfc,
                    size: 80,
                    color: Colors.blue.shade400,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Ready to Scan',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Hold your Mifare Classic card near\nthe NFC antenna to read',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: () {
                      print('DEBUG: Manual scan button pressed');
                      provider.startScan();
                    },
                    icon: const Icon(Icons.search),
                    label: const Text('Start Scanning'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (provider.lastScannedUid.isNotEmpty) ...[
                    const Text('Last detected:'),
                    const SizedBox(height: 10),
                    Text(
                      provider.lastScannedUid,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Card Info with last scanned history
                  Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Card Information',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              // Show UID copy button
                              IconButton(
                                icon: const Icon(Icons.copy, size: 20),
                                onPressed: () {
                                  _copyToClipboard(context, uid);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow('UID', uid),
                          _buildInfoRow('Type', type),
                          _buildInfoRow('Size', '$size bytes'),
                          _buildInfoRow('Sectors', '$sectorCount'),
                          _buildInfoRow('Successfully Read', '$successfulSectors sectors'),

                          // Show saved custom keys
                          if (provider.customKeys.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            const Divider(),
                            const SizedBox(height: 8),
                            const Text(
                              'Saved Keys',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: provider.customKeys.entries.map((entry) {
                                final parts = entry.key.split('_');
                                final keyType = parts[0];
                                final sector = parts.length > 1 ? parts[1] : '?';
                                return Chip(
                                  label: Text('S$sector Key$keyType'),
                                  avatar: Icon(keyType == 'A' ? Icons.vpn_key : Icons.key, size: 16),
                                  backgroundColor: Colors.blue.shade100,
                                  deleteIcon: const Icon(Icons.close, size: 16),
                                  onDeleted: () => _removeKey(context, int.parse(sector), keyType),
                                );
                              }).toList(),
                            ),
                          ],

                          // Last scanned info
                          if (provider.lastScannedUid.isNotEmpty &&
                              provider.lastScannedUid != uid) ...[
                            const Divider(height: 30),
                            Row(
                              children: [
                                Icon(Icons.history, color: Colors.grey.shade600, size: 18),
                                const SizedBox(width: 8),
                                const Text(
                                  'Previous Scan:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      provider.lastScannedUid,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 18),
                                    onPressed: () {
                                      _copyToClipboard(context, provider.lastScannedUid);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Authentication Status
                  if (keyInfo.isNotEmpty) Card(
                    elevation: 3,
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.verified_user, color: Colors.blue.shade800),
                              const SizedBox(width: 8),
                              const Text(
                                'Authentication Status',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: keyInfo.map((keyData) {
                              final sector = keyData['sector'] ?? 0;
                              final keyType = keyData['keyType'] ?? '';
                              final authenticated = keyData['authenticated'] ?? false;
                              final key = keyData['key'] ?? '';

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: authenticated ? Colors.green.shade100 : Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: authenticated ? Colors.green.shade300 : Colors.red.shade300,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'S$sector',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: authenticated ? Colors.green.shade800 : Colors.red.shade800,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      keyType == 'A' ? Icons.vpn_key : Icons.key,
                                      size: 14,
                                      color: authenticated ? Colors.green.shade800 : Colors.red.shade800,
                                    ),
                                    if (authenticated && key.isNotEmpty) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        '✓',
                                        style: TextStyle(
                                          color: Colors.green.shade800,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Blocks List
                  const Text(
                    'Memory Blocks',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  if (blocks.isNotEmpty) ..._buildSectorViews(blocks, keyInfo),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _removeKey(BuildContext context, int sector, String keyType) async {
    final provider = Provider.of<NfcProvider>(context, listen: false);
    final success = await provider.removeCustomKey(sector, keyType);

    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Key ${keyType} for sector $sector removed'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // Helper method to copy to clipboard
  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $text'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Dialog to show last scanned info
  void _showLastScannedInfo(BuildContext context) {
    final provider = Provider.of<NfcProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.history),
            SizedBox(width: 10),
            Text('Scan History'),
          ],
        ),
        content: provider.lastScannedUid.isNotEmpty
            ? Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Last scanned card UID:'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                provider.lastScannedUid,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    _copyToClipboard(context, provider.lastScannedUid);
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy'),
                ),
                const SizedBox(width: 10),
                TextButton.icon(
                  onPressed: () async {
                    await provider.clearLastScannedUid();
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Scan history cleared'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text('Clear', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        )
            : const Text('No scan history available.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSectorViews(List<Map<String, dynamic>> blocks, List<Map<String, dynamic>> keyInfo) {
    // Group blocks by sector
    Map<int, List<Map<String, dynamic>>> sectors = {};
    for (var block in blocks) {
      final sector = (block['sector'] as int?) ?? 0;
      sectors.putIfAbsent(sector, () => []).add(block);
    }

    // Create sector widgets
    return sectors.entries.map((entry) {
      final sectorKeyInfo = keyInfo.firstWhere(
            (info) => info['sector'] == entry.key,
        orElse: () => {'keyType': '', 'key': '', 'authenticated': false},
      );
      return _buildSectorCard(entry.key, entry.value, sectorKeyInfo);
    }).toList();
  }

  Widget _buildSectorCard(int sector, List<Map<String, dynamic>> blocks, Map<String, dynamic> keyInfo) {
    final keyType = keyInfo['keyType'] ?? '';
    final keyHex = keyInfo['key'] ?? '';
    final authenticated = keyInfo['authenticated'] ?? false;

    final hasAuthError = blocks.any((block) => block['hex'] == 'AUTH ERROR' || block['hex'] == 'READ ERROR');

    String readingInfo = 'Not authenticated';
    if (authenticated) {
      readingInfo = 'Key $keyType';
      if (keyHex.isNotEmpty) {
        readingInfo += ' ($keyHex)';
      }
    }

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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: authenticated ? Colors.green.shade100 : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Text('Sector $sector', style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: authenticated ? Colors.green.shade800 : Colors.red.shade800,
                      )),
                      const SizedBox(width: 8),
                      Icon(
                        keyType == 'A' ? Icons.vpn_key : Icons.key,
                        size: 16,
                        color: authenticated ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    readingInfo,
                    style: TextStyle(
                      fontSize: 12,
                      color: authenticated ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...blocks.map((block) => _buildBlockRow(block, keyType, authenticated)),
          ],
        ),
      ),
    );
  }


  Widget _buildBlockRow(Map<String, dynamic> block, String keyType, bool sectorAuthenticated) {
    final hex = block['hex'] ?? '';
    final text = block['text'] ?? '';
    final blockNum = block['block'] ?? 0;
    final isTrailer = block['isTrailer'] ?? false;
    final isError = !sectorAuthenticated || hex == 'AUTH ERROR' || hex == 'READ ERROR';
    final absBlock = block['absBlock'] ?? 0;

    // Check if it's a valid trailer block (should be 32 chars for 16 bytes)
    final isValidTrailer = isTrailer && !isError && hex.length >= 32;

    // For trailer blocks, use ExpansionTile for dropdown style
    if (isTrailer && !isError) {
      return _buildTrailerExpansionTile(
        block: block,
        hex: hex,
        blockNum: blockNum,
        absBlock: absBlock,
        keyType: keyType,
        sectorAuthenticated: sectorAuthenticated,
      );
    }

    // For non-trailer blocks or error states, use the normal display
    return _buildNormalBlockRow(
      block: block,
      hex: hex,
      text: text,
      blockNum: blockNum,
      isTrailer: isTrailer,
      isError: isError,
      absBlock: absBlock,
      keyType: keyType,
      sectorAuthenticated: sectorAuthenticated,
    );
  }

  List<Widget> _parseTrailerBlock(String hex) {
    final List<Widget> parts = [];

    // Key A (bytes 0-5 = chars 0-11)
    if (hex.length >= 12) {
      parts.add(_buildTrailerPart(
        label: 'Key A (6 bytes)',
        hexValue: hex.substring(0, 12),
        description: 'Authentication Key A',
        color: Colors.blue,
        startIndex: 0,
        endIndex: 5,
        isHidden: hex.substring(0, 12) == '000000000000',
      ));
      parts.add(const SizedBox(height: 8));
    }

    // Access Bits (bytes 6-8 = chars 12-17) + User Byte (byte 9 = chars 18-19)
    if (hex.length >= 20) {
      final accessBitsHex = hex.substring(12, 18);
      final userByteHex = hex.length >= 20 ? hex.substring(18, 20) : '';

      parts.add(_buildTrailerPart(
        label: 'Access Bits (3 bytes)',
        hexValue: accessBitsHex,
        description: 'Controls sector permissions',
        color: Colors.orange,
        startIndex: 6,
        endIndex: 8,
        note: _getAccessBitsNote(accessBitsHex),
      ));
      parts.add(const SizedBox(height: 8));

      parts.add(_buildTrailerPart(
        label: 'User Byte (1 byte)',
        hexValue: userByteHex,
        description: 'General purpose byte (B9)',
        color: Colors.purple,
        startIndex: 9,
        endIndex: 9,
      ));
      parts.add(const SizedBox(height: 8));
    }

    // Key B (bytes 10-15 = chars 20-31)
    if (hex.length >= 32) {
      final keyBHex = hex.substring(20, 32);
      final accessBitsHex = hex.length >= 18 ? hex.substring(12, 18) : '';

      parts.add(_buildTrailerPart(
        label: 'Key B (6 bytes)',
        hexValue: keyBHex,
        description: 'Authentication Key B',
        color: Colors.green,
        startIndex: 10,
        endIndex: 15,
        note: _getKeyBNote(accessBitsHex, keyBHex),
      ));
    }

    return parts;
  }

// Helper widget for trailer parts (updated)
  Widget _buildTrailerPart({
    required String label,
    required String hexValue,
    required String description,
    required Color color,
    required int startIndex,
    required int endIndex,
    String? note,
    bool isHidden = false,
  }) {
    final isKeyA = label.contains('Key A');
    final isKeyB = label.contains('Key B');

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'B$startIndex-${endIndex}',
                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: color,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '(${hexValue.length ~/ 2} bytes)',
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Hex value
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(
                  isKeyA ? Icons.vpn_key : (isKeyB ? Icons.key : Icons.lock),
                  size: 14,
                  color: isHidden ? Colors.red : color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    hexValue,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isHidden ? Colors.red : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Additional notes/warnings
          if (note != null || isHidden) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isHidden ? Colors.red.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(
                    isHidden ? Icons.warning : Icons.info,
                    size: 12,
                    color: isHidden ? Colors.red : Colors.blue,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      note ?? (isHidden
                          ? 'Key is hidden (reads as zeros). This is normal if access bits restrict key reading.'
                          : ''),
                      style: TextStyle(
                        fontSize: 10,
                        color: isHidden ? Colors.red : Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

// Helper for partial trailer blocks
  Widget _buildPartialTrailerBlock(String hex) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning, size: 14, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Non-standard trailer block length',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            'Hex: $hex',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'Expected 32 characters (16 bytes) but got ${hex.length}',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

// Helper function to decode access bits (6 hex chars = 3 bytes)
  String _getAccessBitsNote(String accessBitsHex) {
    if (accessBitsHex.length < 6) return 'Incomplete access bits';

    final Map<String, String> commonAccessBits = {
      '078069': 'Default: Key A RW, Key B RW, Key B readable',
      '078869': 'Read Only: Key A RO, Key B RO, Key B readable',
      '8F0F07': 'Key A RW, Key B RO, Access RO, Key B readable',
      '8F0F08': 'Key A RW, Key B RO, Access RO, Key B hidden',
      '778F69': 'Key B Required: Key A RW, Key B RW, Key B readable',
      '778F00': 'Fully Locked: Key A NO, Key B NO, Key B hidden',
    };

    final description = commonAccessBits[accessBitsHex] ?? 'Custom configuration';

    // Check for dangerous configurations
    final isDangerous = accessBitsHex == '778F00' ||
        accessBitsHex == '08778F' ||
        accessBitsHex.contains('8F');

    if (isDangerous) {
      return '$description. ⚠️ Warning: This configuration may lock the sector!';
    }

    return description;
  }

// Helper function for Key B notes
  String _getKeyBNote(String accessBitsHex, String keyBHex) {
    if (keyBHex == '000000000000') {
      return 'Key B reads as zeros - may be hidden by access bits or disabled';
    }
    if (keyBHex == 'FFFFFFFFFFFF') {
      return 'Key B is factory default (FFFFFFFFFFFF)';
    }

    // Check if access bits allow Key B to be readable
    if (accessBitsHex.length >= 6) {
      // For Mifare Classic, check C3 bit
      // This is simplified - actual decoding is more complex
      try {
        final byte6 = int.tryParse(accessBitsHex.substring(4, 6), radix: 16) ?? 0;
        // Check if Key B is readable (simplified check)
        if ((byte6 & 0xF0) == 0x80) { // Common pattern for hidden Key B
          return 'Key B is configured as NOT readable (hidden) by access bits';
        }
      } catch (e) {
        // Ignore parse errors
      }
    }

    return 'Custom Key B configured';
  }

// Build expandable trailer block
  Widget _buildTrailerExpansionTile({
    required Map<String, dynamic> block,
    required String hex,
    required int blockNum,
    required int absBlock,
    required String keyType,
    required bool sectorAuthenticated,
  }) {
    bool isExpanded = false; // Local state for expansion

    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Column(
            children: [
              // Header - always visible
              GestureDetector(
                onTap: () {
                  setState(() {
                    isExpanded = !isExpanded;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      // Trailer indicator with dropdown arrow
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                              color: Colors.orange.shade400,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Trailer',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade400,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Block info
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Block $blockNum',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Abs: $absBlock',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Authentication indicator
                      if (sectorAuthenticated)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: keyType == 'A' ? Colors.blue.shade100 : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(keyType == 'A' ? Icons.vpn_key : Icons.key, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                'Key $keyType',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(width: 8),

                      // Expand/collapse button
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.orange.shade400,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),

              // Expandable content
              if (isExpanded) ...[
                const SizedBox(height: 8),
                _buildTrailerDetails(hex, blockNum, absBlock),
              ],
            ],
          ),
        );
      },
    );
  }

// Build trailer details (expanded content)
  Widget _buildTrailerDetails(String hex, int blockNum, int absBlock) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.shade600,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trailer block header
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.orange.shade400),
              const SizedBox(width: 8),
              Text(
                'Trailer Block Details (Block $blockNum)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Parse and show trailer parts
          ..._parseTrailerBlock(hex),

          // Raw hex view
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Full Hex Data:',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  hex,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  '${hex.length} characters (${hex.length ~/ 2} bytes)',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// Build normal block row (non-trailer or error)
  Widget _buildNormalBlockRow({
    required Map<String, dynamic> block,
    required String hex,
    required String text,
    required int blockNum,
    required bool isTrailer,
    required bool isError,
    required int absBlock,
    required String keyType,
    required bool sectorAuthenticated,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError
            ? Colors.red.shade50
            : (isTrailer ? Colors.orange.shade50 : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError
              ? Colors.red.shade200
              : (isTrailer ? Colors.orange.shade200 : Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with block info and authentication status
          Row(
            children: [
              Chip(
                label: Text(
                  isTrailer ? 'Block $blockNum (Trailer)' : 'Block $blockNum',
                  style: TextStyle(
                    fontWeight: isTrailer ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                backgroundColor: isError
                    ? Colors.red.shade100
                    : (isTrailer ? Colors.orange.shade100 : Colors.blue.shade100),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              Text(
                'Abs: $absBlock',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Spacer(),
              if (sectorAuthenticated && !isError)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: keyType == 'A' ? Colors.blue.shade100 : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(keyType == 'A' ? Icons.vpn_key : Icons.key, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'Key $keyType',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Error state display
          if (isError) ...[
            Row(children: [
              const Icon(Icons.error, size: 14, color: Colors.red),
              const SizedBox(width: 4),
              Text(hex, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            ]),
          ]
          // Regular data block display
          else if (hex.isNotEmpty) ...[
            SelectableText(
              'Hex: $hex',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            const SizedBox(height: 4),
            SelectableText(
              'Text: "$text"',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ] else ...[
            const Text(
              'No data',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

// Alternative: Using ExpansionTile widget (simpler but less control)
  Widget _buildTrailerWithExpansionTile({
    required Map<String, dynamic> block,
    required String hex,
    required int blockNum,
    required int absBlock,
    required String keyType,
    required bool sectorAuthenticated,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        backgroundColor: Colors.orange.shade50,
        collapsedBackgroundColor: Colors.orange.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.orange.shade200),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.orange.shade200),
        ),
        leading: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            blockNum.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade800,
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              'Trailer Block',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade800,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Abs: $absBlock',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        subtitle: const Text(
          'Tap to expand details',
          style: TextStyle(fontSize: 11),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: keyType == 'A' ? Colors.blue.shade100 : Colors.green.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(keyType == 'A' ? Icons.vpn_key : Icons.key, size: 12),
              const SizedBox(width: 4),
              Text(
                'Key $keyType',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: _buildTrailerDetails(hex, blockNum, absBlock),
          ),
        ],
      ),
    );
  }

}