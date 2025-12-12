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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isError ? Colors.red.shade50 : (isTrailer ? Colors.orange.shade50 : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError ? Colors.red.shade200 : (isTrailer ? Colors.orange.shade200 : Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip(
                label: Text(isTrailer ? 'Block $blockNum (Trailer)' : 'Block $blockNum'),
                backgroundColor: isError ? Colors.red.shade100 : (isTrailer ? Colors.orange.shade100 : Colors.blue.shade100),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              if (sectorAuthenticated) Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: keyType == 'A' ? Colors.blue.shade100 : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(keyType == 'A' ? Icons.vpn_key : Icons.key, size: 12),
                    const SizedBox(width: 4),
                    Text('Key $keyType', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (!isError) ...[
            SelectableText('Hex: $hex', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            const SizedBox(height: 4),
            SelectableText('Text: "$text"', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ] else ...[
            Row(children: [
              const Icon(Icons.error, size: 14, color: Colors.red),
              const SizedBox(width: 4),
              Text(hex, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            ]),
          ],
        ],
      ),
    );
  }
}