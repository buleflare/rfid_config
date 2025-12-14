import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/nfc_provider.dart';

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class ReadScreen extends StatefulWidget {
  const ReadScreen({super.key});

  @override
  State<ReadScreen> createState() => _ReadScreenState();
}

class _ReadScreenState extends State<ReadScreen> {
  // State variables for custom key arrays
  final List<TextEditingController> _keyAControllers = [TextEditingController()];
  final List<TextEditingController> _keyBControllers = [TextEditingController()];
  bool _hasCustomKeys = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<NfcProvider>(context, listen: false);
      provider.startScan();
      _loadCustomKeyArrays();
    });
  }

  @override
  void dispose() {
    for (var controller in _keyAControllers) {
      controller.dispose();
    }
    for (var controller in _keyBControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // Helper method to validate hex keys
  bool _isValidHexKey(String key) {
    if (key.isEmpty) return false;
    final cleanKey = key.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();
    if (cleanKey.length != 12) return false;
    return RegExp(r'^[0-9A-Fa-f]{12}$').hasMatch(cleanKey);
  }


// Update _loadCustomKeyArrays method
  void _loadCustomKeyArrays() async {
    final provider = Provider.of<NfcProvider>(context, listen: false);
    await provider.loadCustomKeyArrays();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      setState(() {
        // Check if we have any custom keys
        _hasCustomKeys = provider.customKeyArrayA.isNotEmpty ||
            provider.customKeyArrayB.isNotEmpty;

        // Load Key A array
        _keyAControllers.clear();
        final keyAArray = provider.customKeyArrayA;
        for (final key in keyAArray) {
          _keyAControllers.add(TextEditingController(text: key));
        }
        // Add empty controller for new input
        _keyAControllers.add(TextEditingController());

        // Load Key B array
        _keyBControllers.clear();
        final keyBArray = provider.customKeyArrayB;
        for (final key in keyBArray) {
          _keyBControllers.add(TextEditingController(text: key));
        }
        // Add empty controller for new input
        _keyBControllers.add(TextEditingController());
      });
    });
  }

// Remove _hasCustomKeys variable declaration

// Update _addKey method
  void _addKey(String key, String keyType, NfcProvider provider) async {
    final cleanKey = key.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();

    if (cleanKey.length != 12) {
      _showError('Key must be 12 hex characters');
      return;
    }

    final success = await provider.addCustomKeyToArray(cleanKey, keyType);

    if (success && mounted) {
      _loadCustomKeyArrays(); // Reload to refresh the display
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$keyType key added: $cleanKey'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

// Update _removeKey method (no _hasCustomKeys check needed)
  void _removeKey(String key, String keyType, NfcProvider provider) async {
    final cleanKey = key.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();

    final success = await provider.removeCustomKeyFromArray(cleanKey, keyType);

    if (success && mounted) {
      _loadCustomKeyArrays(); // Reload to refresh the display
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$keyType key removed: $cleanKey'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

// Update _clearAllKeys method (no _hasCustomKeys check needed)
  void _clearAllKeys(String keyType, NfcProvider provider) async {
    await provider.clearCustomKeyArray(keyType);

    if (mounted) {
      _loadCustomKeyArrays(); // Reload to refresh the display

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All Key $keyType cleared'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Read with custom keys
  void _readWithCustomKeys(NfcProvider provider) async {
    if (provider.customKeyArrayA.isEmpty && provider.customKeyArrayB.isEmpty) {
      _showError('Please add at least one custom key');
      return;
    }

    try {
      await provider.startScanWithCustomKeyArrays();
    } catch (e) {
      _showError('Error reading with custom keys: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $text'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Build the custom keys section
  Widget _buildCustomKeysSection(BuildContext context, NfcProvider provider) {
    final keyAArray = provider.customKeyArrayA;
    final keyBArray = provider.customKeyArrayB;

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status indicator

            Row(
              children: [
                Icon(
                    Icons.vpn_key,
                    color: provider.customKeyArrayA.isNotEmpty || provider.customKeyArrayB.isNotEmpty
                        ? Colors.green
                        : Colors.blue.shade800
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Custom Keys for Authentication',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (provider.customKeyArrayA.isNotEmpty || provider.customKeyArrayB.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, size: 12, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          '${provider.customKeyArrayA.length + provider.customKeyArrayB.length} keys active',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              provider.customKeyArrayA.isNotEmpty || provider.customKeyArrayB.isNotEmpty
                  ? 'Custom keys will be automatically tried when scanning'
                  : 'Add keys to try. Keys will be tested on all sectors.',
              style: TextStyle(
                color: provider.customKeyArrayA.isNotEmpty || provider.customKeyArrayB.isNotEmpty
                    ? Colors.green.shade700
                    : Colors.grey,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 20),

            // Key A Section
            _buildKeySection(
              title: 'Key A',
              icon: Icons.vpn_key,
              color: Colors.blue,
              controllers: _keyAControllers,
              keyArray: keyAArray,
              keyType: 'A',
              provider: provider,
            ),

            const SizedBox(height: 24),

            // Key B Section
            _buildKeySection(
              title: 'Key B',
              icon: Icons.key,
              color: Colors.green,
              controllers: _keyBControllers,
              keyArray: keyBArray,
              keyType: 'B',
              provider: provider,
            ),

            const SizedBox(height: 20),

            // Quick Add Common Keys
            _buildQuickKeysSection(context, provider),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_hasCustomKeys) {
                        provider.startScanWithCustomKeyArrays(); // Force rescan
                      } else {
                        _showError('Please add at least one custom key first');
                      }
                    },
                    icon: const Icon(Icons.nfc),
                    label: const Text('Read with Custom Keys'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue.shade800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'clear_a') {
                      _clearAllKeys('A', provider);
                    } else if (value == 'clear_b') {
                      _clearAllKeys('B', provider);
                    } else if (value == 'clear_all') {
                      _clearAllKeys('A', provider);
                      _clearAllKeys('B', provider);
                    } else if (value == 'load_keys') {
                      _loadCustomKeyArrays();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'load_keys',
                      child: ListTile(
                        leading: Icon(Icons.refresh),
                        title: Text('Reload Keys'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'clear_a',
                      child: ListTile(
                        leading: Icon(Icons.delete, color: Colors.blue),
                        title: Text('Clear All Key A'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'clear_b',
                      child: ListTile(
                        leading: Icon(Icons.delete, color: Colors.green),
                        title: Text('Clear All Key B'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'clear_all',
                      child: ListTile(
                        leading: Icon(Icons.delete_sweep, color: Colors.red),
                        title: Text('Clear All Keys', style: TextStyle(color: Colors.red)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Build individual key section
  Widget _buildKeySection({
    required String title,
    required IconData icon,
    required Color color,
    required List<TextEditingController> controllers,
    required List<String> keyArray,
    required String keyType,
    required NfcProvider provider,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${keyArray.length} keys',
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Saved Keys Chips
        if (keyArray.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: keyArray.map((key) {
              return Chip(
                label: Text(
                  key,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
                backgroundColor: color.withOpacity(0.1),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => _removeKey(key, keyType, provider),
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],

        // Add New Key Row
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controllers.last,
                decoration: InputDecoration(
                  hintText: 'FFFFFFFFFFFF',
                  labelText: 'Add new $title',
                  prefixIcon: Icon(icon, color: color),
                  border: const OutlineInputBorder(),
                  errorText: controllers.last.text.isNotEmpty &&
                      !_isValidHexKey(controllers.last.text)
                      ? '12 hex characters'
                      : null,
                ),
                style: const TextStyle(fontFamily: 'monospace'),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f]')),
                  LengthLimitingTextInputFormatter(12),
                  UpperCaseTextFormatter(),
                ],
                textCapitalization: TextCapitalization.characters,
                onChanged: (value) {
                  // Auto-add when valid key is entered (optional)
                  if (_isValidHexKey(value) && value.length == 12) {
                    _addKey(value, keyType, provider);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {
                final key = controllers.last.text.trim();
                if (key.isNotEmpty && _isValidHexKey(key)) {
                  _addKey(key, keyType, provider);
                  controllers.last.clear();
                }
              },
              style: ElevatedButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(12),
                backgroundColor: color,
              ),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ],
        ),
      ],
    );
  }

  // Quick keys section
  Widget _buildQuickKeysSection(BuildContext context, NfcProvider provider) {
    final List<Map<String, dynamic>> commonKeys = [
      {'label': 'Default', 'key': 'FFFFFFFFFFFF', 'color': Colors.blue},
      {'label': 'Transport', 'key': 'A0A1A2A3A4A5', 'color': Colors.green},
      {'label': 'D3F7', 'key': 'D3F7D3F7D3F7', 'color': Colors.orange},
      {'label': 'Zeros', 'key': '000000000000', 'color': Colors.grey},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Add:',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: commonKeys.map((keyInfo) {
            final String label = keyInfo['label'] as String;
            final String key = keyInfo['key'] as String;
            final Color color = keyInfo['color'] as Color;

            return ElevatedButton(
              onPressed: () {
                _addKey(key, 'A', provider);
                _addKey(key, 'B', provider);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: color.withOpacity(0.1),
                foregroundColor: color,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: color.withOpacity(0.3)),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, size: 14),
                  const SizedBox(width: 4),
                  Text(label),
                  const SizedBox(width: 4),
                  Text(
                    key.substring(0, 6),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Info row widget
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
                  const Icon(Icons.error, color: Colors.red, size: 60),
                  const SizedBox(height: 20),
                  const Text(
                    'NFC not available on this device',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                  const Icon(Icons.error, color: Colors.orange, size: 60),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      provider.errorMessage,
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
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

          final uid = provider.getCardInfo('uid', 'N/A');
          final type = provider.getCardInfo('type', 'N/A');
          final size = provider.getCardInfoInt('size', 0);
          final sectorCount = provider.getCardInfoInt('sectorCount', 0);
          final successfulSectors = provider.getCardInfoInt('successfulSectors', 0);
          final blocks = provider.getBlocks();
          final keyInfo = provider.getKeyInfo();

// In the "Ready to Scan" section of your build method
          // In the "Ready to Scan" section of your build method, replace with:

          if (!provider.isLoading && provider.cardData.isEmpty) {
            // Get the key arrays from provider
            final keyAArray = provider.customKeyArrayA;
            final keyBArray = provider.customKeyArrayB;
            final hasCustomKeys = keyAArray.isNotEmpty || keyBArray.isNotEmpty;

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                      Icons.nfc,
                      size: 80,
                      color: hasCustomKeys ? Colors.green.shade600 : Colors.blue.shade400
                  ),
                  const SizedBox(height: 20),
                  Text(
                    hasCustomKeys ? 'Ready to Scan with Custom Keys' : 'Ready to Scan',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: hasCustomKeys ? Colors.green.shade800 : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    hasCustomKeys
                        ? 'Hold your card near the NFC antenna\n${keyAArray.length + keyBArray.length} custom keys will be tried'
                        : 'Hold your Mifare Classic card near\nthe NFC antenna to read',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),

                  // Show custom keys summary if available
                  if (hasCustomKeys) ...[
                    const SizedBox(height: 20),
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            const Text(
                              'Custom Keys to try:',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Column(
                                  children: [
                                    Icon(Icons.vpn_key, color: Colors.blue, size: 20),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${keyAArray.length}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const Text('Key A', style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(width: 24),
                                Column(
                                  children: [
                                    Icon(Icons.key, color: Colors.green, size: 20),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${keyBArray.length}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const Text('Key B', style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: () => provider.startScan(),
                    icon: Icon(
                      hasCustomKeys ? Icons.vpn_key : Icons.search,
                      color: hasCustomKeys ? Colors.green : null,
                    ),
                    label: Text(
                      hasCustomKeys ? 'Scan with Custom Keys' : 'Start Scanning',
                      style: TextStyle(
                        color: hasCustomKeys ? Colors.green.shade800 : null,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      backgroundColor: hasCustomKeys ? Colors.green.shade50 : null,
                      foregroundColor: hasCustomKeys ? Colors.green : null,
                      side: hasCustomKeys ? BorderSide(color: Colors.green.shade300) : null,
                    ),
                  ),
                ],
              ),
            );
          }
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Custom Keys Section
                  _buildCustomKeysSection(context, provider),

                  const SizedBox(height: 20),

                  // Card Information
                  Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Card Information',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ),
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
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Authentication Status
                  if (keyInfo.isNotEmpty) ...[
                    Card(
                      elevation: 3,
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.verified_user, color: Colors.blue),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Authentication Status',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: keyInfo.map((keyData) {
                                final sector = keyData['sector'] as int? ?? 0;
                                final keyType = keyData['keyType'] as String? ?? '';
                                final authenticated = keyData['authenticated'] as bool? ?? false;

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
                                      if (authenticated) ...[
                                        const SizedBox(width: 4),
                                        const Text(
                                          '✓',
                                          style: TextStyle(
                                            color: Colors.green,
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
                  ],

                  // Memory Blocks
                  if (blocks.isNotEmpty) ...[
                    const Text(
                      'Memory Blocks',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ..._buildSectorViews(blocks, keyInfo),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildSectorViews(List<Map<String, dynamic>> blocks, List<Map<String, dynamic>> keyInfo) {
    Map<int, List<Map<String, dynamic>>> sectors = {};
    for (var block in blocks) {
      final sector = (block['sector'] as int?) ?? 0;
      sectors.putIfAbsent(sector, () => []).add(block);
    }

    return sectors.entries.map((entry) {
      final sectorKeyInfo = keyInfo.firstWhere(
            (info) => (info['sector'] as int?) == entry.key,
        orElse: () => {'keyType': '', 'key': '', 'authenticated': false},
      );
      return _buildSectorCard(entry.key, entry.value, sectorKeyInfo);
    }).toList();
  }

  Widget _buildSectorCard(int sector, List<Map<String, dynamic>> blocks, Map<String, dynamic> keyInfo) {
    final keyType = keyInfo['keyType'] as String? ?? '';
    final keyHex = keyInfo['key'] as String? ?? '';
    final authenticated = keyInfo['authenticated'] as bool? ?? false;

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
    final hex = block['hex'] as String? ?? '';
    final text = block['text'] as String? ?? '';
    final blockNum = block['block'] as int? ?? 0;
    final isTrailer = block['isTrailer'] as bool? ?? false;
    final isError = !sectorAuthenticated || hex == 'AUTH ERROR' || hex == 'READ ERROR';
    final absBlock = block['absBlock'] as int? ?? 0;

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
            ],
          ),
          const SizedBox(height: 8),
          if (isError) ...[
            Row(children: [
              const Icon(Icons.error, size: 14, color: Colors.red),
              const SizedBox(width: 4),
              Text(hex, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            ]),
          ]
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
}