import 'package:convert/convert.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/nfc_provider.dart';
import 'dart:convert' as convert;

class WriteScreen extends StatefulWidget {
  const WriteScreen({super.key});

  @override
  State<WriteScreen> createState() => _WriteScreenState();
}

class _WriteScreenState extends State<WriteScreen> {
  final _dataController = TextEditingController();
  final _sectorController = TextEditingController(text: '0');
  final _blockController = TextEditingController(text: '1');
  final _keyAController = TextEditingController(text: 'FFFFFFFFFFFF');
  final _keyBController = TextEditingController(text: 'FFFFFFFFFFFF');
  bool _isHex = false;
  bool _useCustomKeys = false;

  // Store available blocks for each sector
  List<int> _availableBlocks = [1, 2]; // Default for sector 0

  bool _isValidHex(String input) {
    if (input.isEmpty) return false;
    final cleanInput = input.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
    if (cleanInput.length != 12) return false;
    return RegExp(r'^[0-9A-Fa-f]{12}$').hasMatch(cleanInput);
  }

  // Add the isValidKey method (for consistency with your existing code)


  @override
  void initState() {
    super.initState();
    // Listen for sector changes
    _sectorController.addListener(_updateAvailableBlocks);
    _updateAvailableBlocks();

    // Load existing keys if available for sector 0
    _loadExistingKeys();
  }

  // Load existing keys for the current sector
  void _loadExistingKeys() {
    final provider = Provider.of<NfcProvider>(context, listen: false);
    final sector = int.tryParse(_sectorController.text) ?? 0;

    final keyA = provider.getKeyForSector(sector, 'A');
    final keyB = provider.getKeyForSector(sector, 'B');

    if (keyA != null) {
      _keyAController.text = keyA;
    }
    if (keyB != null) {
      _keyBController.text = keyB;
    }
  }

  // Update available blocks based on selected sector
  void _updateAvailableBlocks() {
    final sector = int.tryParse(_sectorController.text) ?? 0;

    setState(() {
      if (sector == 0) {
        // Sector 0: Block 0 is manufacturer (read-only), blocks 1-2 are data blocks
        _availableBlocks = [1, 2];
      } else if (sector >= 1 && sector <= 4) {
        // Sectors 1-4: Blocks 0-2 are data blocks (3 blocks per sector)
        _availableBlocks = [0, 1, 2];
      } else if (sector >= 5 && sector <= 15) {
        // Sectors 5-15: Blocks 0-14 are data blocks (15 blocks per sector)
        _availableBlocks = List.generate(15, (index) => index);
      } else {
        // Invalid sector, default to sector 0 blocks
        _availableBlocks = [1, 2];
      }

      // If current block is not in available blocks, reset to first available
      final currentBlock = int.tryParse(_blockController.text) ?? 1;
      if (!_availableBlocks.contains(currentBlock)) {
        _blockController.text = _availableBlocks.first.toString();
      }

      // Load keys for the new sector
      _loadExistingKeys();
    });
  }

  // Validate hex key input
// Replace this method:
  bool _isValidKey(String key) {
    if (key.isEmpty) return false;
    final cleanKey = key.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
    if (cleanKey.length != 12) return false;
    return RegExp(r'^[0-9A-Fa-f]{12}$').hasMatch(cleanKey);
  }

// With this method that properly validates hex:
  bool _isValidHexKey(String key) {
    if (key.isEmpty) return false;

    // Clean the key - remove any non-hex characters
    final cleanKey = key.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();

    // Check length
    if (cleanKey.length != 12) return false;

    // Check if it's valid hex
    try {
      // Try to parse as hex
      final bytes = hex.decode(cleanKey);
      return bytes.length == 6; // 6 bytes = 12 hex chars
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<NfcProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Write Data to Card'),
        backgroundColor: Colors.green.shade800,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!provider.isNfcAvailable)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.error,
                        color: Colors.red,
                        size: 40,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'NFC not available',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const Text(
                        'This device does not support NFC',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

            if (provider.isNfcAvailable) ...[
              // Last Scanned UID Section
              if (provider.lastScannedUid.isNotEmpty)
                Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 20),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.history, color: Colors.blue.shade800),
                            const SizedBox(width: 8),
                            const Text(
                              'Last Scanned Card',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: SelectableText(
                                  provider.lastScannedUid,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  _dataController.text =
                                      provider.lastScannedUid;
                                  setState(() => _isHex = true);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('UID loaded as hex data'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.content_copy),
                                label: const Text('Use UID as Data'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: () {
                                _copyToClipboard(
                                    context, provider.lastScannedUid);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              // Key Status Section
// Custom Keys Toggle Section - ALWAYS VISIBLE
              Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 20),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.vpn_key, color: Colors.orange.shade800),
                          const SizedBox(width: 8),
                          const Text(
                            'Authentication Keys',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Show saved keys if available
                      Consumer<NfcProvider>(
                        builder: (context, provider, child) {
                          final sector = int.tryParse(_sectorController.text) ?? 0;
                          final keyA = provider.getKeyForSector(sector, 'A');
                          final keyB = provider.getKeyForSector(sector, 'B');

                          if (keyA != null || keyB != null) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Saved keys for this sector:',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (keyA != null) _buildKeyChip('Key A', keyA),
                                    if (keyB != null) _buildKeyChip('Key B', keyB),
                                  ],
                                ),
                                const SizedBox(height: 12),
                              ],
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),

                      // Custom keys toggle
                      Row(
                        children: [
                          Checkbox(
                            value: _useCustomKeys,
                            onChanged: (value) {
                              setState(() {
                                _useCustomKeys = value ?? false;
                              });
                            },
                          ),
                          const Text('Use custom keys for this write'),
                        ],
                      ),

                      if (_useCustomKeys)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            _buildKeyInputField(
                              controller: _keyAController,
                              label: 'Custom Key A (6 bytes, 12 hex chars)',
                              hintText: 'FFFFFFFFFFFF',
                              isKeyA: true,
                            ),
                            const SizedBox(height: 12),
                            _buildKeyInputField(
                              controller: _keyBController,
                              label: 'Custom Key B (6 bytes, 12 hex chars)',
                              hintText: 'FFFFFFFFFFFF',
                              isKeyA: false,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.info, color: Colors.blue.shade800, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Keys must be 12 hex characters (6 bytes). Leave empty to use default FFFFFFFFFFFF.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: [
                                _buildExampleKeyChip('Default Key', 'FFFFFFFFFFFF'),
                                _buildExampleKeyChip('All Zeros', '000000000000'),
                                _buildExampleKeyChip('All As', 'AAAAAAAAAAAA'),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

              // Write Configuration
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Write Data to Card',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Sector & Block Input
                      Row(
                        children: [
                          Expanded(
                            child: _buildSectorField(),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildBlockDropdown(),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Data Type Selection
                      Row(
                        children: [
                          Expanded(
                            child: _buildToggleOption(
                              'Text',
                              !_isHex,
                                  () => setState(() => _isHex = false),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildToggleOption(
                              'Hex',
                              _isHex,
                                  () => setState(() => _isHex = true),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Data Input
                      TextField(
                        controller: _dataController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: _isHex
                              ? 'Hex Data (32 chars max)'
                              : 'Text Data (16 chars max)',
                          hintText: _isHex
                              ? 'Enter 32 hex characters (16 bytes)'
                              : 'Enter text to write (max 16 characters)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),

                      const SizedBox(height: 20),

                      // Write Button
                      ElevatedButton.icon(
                        onPressed: _writeData,
                        icon: const Icon(Icons.edit),
                        label: const Text('Write to Card'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Sector Information Card
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sector Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildSectorInfoItem(
                        'Sector 0 (Manufacturer)',
                        '• Block 0: Manufacturer data (READ-ONLY)\n• Block 1-2: Data blocks (WRITABLE)\n• Block 3: Trailer block',
                        Colors.orange,
                      ),
                      _buildSectorInfoItem(
                        'Sectors 1-4',
                        '• 4 blocks each (3 data + 1 trailer)\n• Blocks 0-2: Data blocks\n• Block 3: Trailer block',
                        Colors.blue,
                      ),
                      _buildSectorInfoItem(
                        'Sectors 5-15',
                        '• 16 blocks each (15 data + 1 trailer)\n• Blocks 0-14: Data blocks\n• Block 15: Trailer block',
                        Colors.purple,
                      ),
                      _buildSectorInfoItem(
                        'Trailer Blocks',
                        '• Sector 0: Block 3\n• Sectors 1-4: Block 3\n• Sectors 5-15: Block 15\n• Contains Keys A/B and Access Bits',
                        Colors.red,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Examples
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Example Data',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildExampleChip(
                              'Hello World', 'Hello World!', false),
                          _buildExampleChip(
                              'All Zeros', '00000000000000000000000000000000',
                              true),
                          _buildExampleChip(
                              'All Fs', 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF',
                              true),
                          _buildExampleChip(
                              'Test Data', '0123456789ABCDEF0123456789ABCDEF',
                              true),
                          _buildExampleChip(
                              'UID Reference', 'Copy UID from read screen',
                              false),
                          _buildExampleChip(
                              'Empty Block', '00000000000000000000000000000000',
                              true),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Important Notes
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Important Notes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildNoteItem(
                        Icons.block,
                        'Sector 0, Block 0 is manufacturer block (READ-ONLY)',
                        Colors.red,
                      ),
                      _buildNoteItem(
                        Icons.edit_attributes,
                        'Sector 0, Blocks 1-2 are WRITABLE data blocks',
                        Colors.green,
                      ),
                      _buildNoteItem(
                        Icons.lock,
                        'Custom keys will be used for authentication if available',
                        Colors.blue,
                      ),
                      _buildNoteItem(
                        Icons.sd_storage,
                        'Each block can store 16 bytes of data',
                        Colors.purple,
                      ),
                      _buildNoteItem(
                        Icons.warning,
                        'Writing wrong data can corrupt the card',
                        Colors.orange,
                      ),
                      _buildNoteItem(
                        Icons.key,
                        'Use FFFFFFFFFFFF as default key for most cards',
                        Colors.amber,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectorField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sector (0-15)',
          style: TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _sectorController,
          decoration: InputDecoration(
            hintText: '0-15',
            prefixIcon: const Icon(Icons.grid_view),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            _updateAvailableBlocks();
            setState(() {}); // Trigger rebuild to update key display
          },
        ),
      ],
    );
  }

  Widget _buildBlockDropdown() {
    final sector = int.tryParse(_sectorController.text) ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Block',
          style: TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<int>(
          value: int.tryParse(_blockController.text) ?? _availableBlocks.first,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          items: _availableBlocks.map((block) {
            // Determine block type for display
            String blockType = 'Data';
            final sector = int.tryParse(_sectorController.text) ?? 0;

            if (sector == 0 && block == 0) {
              blockType = 'Manufacturer (Read-Only)';
            } else if ((sector >= 0 && sector <= 4 && block == 3) ||
                (sector >= 5 && sector <= 15 && block == 15)) {
              blockType = 'Trailer';
            }

            return DropdownMenuItem<int>(
              value: block,
              child: Text(
                'Block $block ($blockType)',
                style: TextStyle(
                  color: blockType.contains('Read-Only') ||
                      blockType == 'Trailer'
                      ? Colors.grey
                      : Colors.black,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              _blockController.text = value.toString();
            }
          },
          isExpanded: true,
        ),
      ],
    );
  }

  Widget _buildKeyInputField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required bool isKeyA,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(isKeyA ? Icons.vpn_key : Icons.key),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                controller.text = 'FFFFFFFFFFFF';
                setState(() {});
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            filled: true,
            fillColor: _isValidHexKey(controller.text)
                ? Colors.green.shade50
                : Colors.grey.shade50,
            errorText: controller.text.isNotEmpty &&
                !_isValidHexKey(controller.text)
                ? 'Invalid key format (12 hex chars like AABBCCDDEEFF)'
                : null,
          ),
          style: const TextStyle(
            fontFamily: 'monospace',
            letterSpacing: 1.2,
          ),
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.characters,
          onChanged: (value) {
            setState(() {});
          },
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f]')),
            LengthLimitingTextInputFormatter(12),
          ],
        ),
      ],
    );
  }

  Widget _buildKeyChip(String label, String key) {
    return Chip(
      label: Text('$label: $key'),
      avatar: Icon(label == 'Key A' ? Icons.vpn_key : Icons.key),
      backgroundColor: label == 'Key A' ? Colors.blue.shade100 : Colors.green
          .shade100,
    );
  }

  Widget _buildExampleKeyChip(String label, String key) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _keyAController.text = key;
          _keyBController.text = key;
        });
      },
      child: Chip(
        label: Text(label),
        avatar: const Icon(Icons.key, size: 16),
        backgroundColor: Colors.amber.shade100,
        labelStyle: const TextStyle(fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
    );
  }

  Widget _buildSectorInfoItem(String title, String description, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? Colors.green : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? Colors.green : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildExampleChip(String label, String data, bool isHex) {
    return GestureDetector(
      onTap: () {
        _dataController.text = data;
        setState(() => _isHex = isHex);
      },
      child: Chip(
        label: Text(label),
        avatar: const Icon(Icons.content_copy, size: 16),
        backgroundColor: Colors.green.shade100,
        labelStyle: const TextStyle(fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
    );
  }

  Widget _buildNoteItem(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $text'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _writeData() {
    final data = _dataController.text.trim();
    final provider = Provider.of<NfcProvider>(context, listen: false);

    if (data.isEmpty) {
      _showError('Please enter data to write');
      return;
    }

    final sector = int.tryParse(_sectorController.text);
    final block = int.tryParse(_blockController.text);

    if (sector == null || sector < 0 || sector > 15) {
      _showError('Please enter a valid sector (0-15)');
      return;
    }

    // Validate block based on sector
    if (block == null) {
      _showError('Please select a valid block');
      return;
    }

    // Special validation for sector 0
    if (sector == 0) {
      if (block == 0) {
        _showError('Sector 0, Block 0 is manufacturer block (READ-ONLY)');
        return;
      }
      if (block == 3) {
        _showError('Use Config screen to write trailer blocks');
        return;
      }
      if (block != 1 && block != 2) {
        _showError('Sector 0 only has writable blocks 1 and 2');
        return;
      }
    }

    // Validate for other sectors
    if (sector >= 1 && sector <= 4) {
      if (block == 3) {
        _showError('Use Config screen to write trailer blocks');
        return;
      }
      if (block < 0 || block > 2) {
        _showError('Sectors 1-4 have data blocks 0-2');
        return;
      }
    }

    if (sector >= 5 && sector <= 15) {
      if (block == 15) {
        _showError('Use Config screen to write trailer blocks');
        return;
      }
      if (block < 0 || block > 14) {
        _showError('Sectors 5-15 have data blocks 0-14');
        return;
      }
    }

    // Prepare custom keys if enabled
    String? customKeyA;
    String? customKeyB;

    if (_useCustomKeys) {
      final keyAText = _keyAController.text.trim();
      final keyBText = _keyBController.text.trim();

      // Validate keys if provided (they can be empty to use default)
      if (keyAText.isNotEmpty && !_isValidHex(keyAText)) {
        _showError(
            'Invalid Key A format. Must be exactly 12 hex characters (0-9, A-F).');
        return;
      }

      if (keyBText.isNotEmpty && !_isValidHex(keyBText)) {
        _showError(
            'Invalid Key B format. Must be exactly 12 hex characters (0-9, A-F).');
        return;
      }

      // Use provided keys or null if empty
      customKeyA = keyAText.isEmpty ? null : keyAText.toUpperCase();
      customKeyB = keyBText.isEmpty ? null : keyBText.toUpperCase();

      // If both are empty, don't send custom keys
      if (customKeyA == null && customKeyB == null) {
        customKeyA = null;
        customKeyB = null;
      }
    }

    // Validate data length and format
    if (_isHex) {
      final cleanHex = data
          .replaceAll(RegExp(r'[^0-9A-Fa-f]'), '')
          .toUpperCase();
      if (cleanHex.isEmpty) {
        _showError('Invalid hex data');
        return;
      }
      if (cleanHex.length % 2 != 0) {
        _showError('Hex data must have even number of characters');
        return;
      }
      if (cleanHex.length > 32) {
        _showError('Hex data too long (max 32 characters = 16 bytes)');
        return;
      }
    } else {
      if (data.length > 16) {
        _showError('Text too long (max 16 characters)');
        return;
      }
    }

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('Confirm Write'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sector: $sector, Block: $block'),
                if (sector == 0 && block == 0)
                  const Text(
                    '⚠️ WARNING: Manufacturer block!',
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                const SizedBox(height: 10),
                const Text('Data:'),
                SelectableText(
                  data.length > 100 ? '${data.substring(0, 100)}...' : data,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                const SizedBox(height: 10),
                if (_isHex)
                  Text('Length: ${data
                      .replaceAll(RegExp(r'[^0-9A-Fa-f]'), '')
                      .length ~/ 2} bytes'),
                if (!_isHex)
                  Text('Length: ${data.length} characters'),

                // Show which keys will be used
                Consumer<NfcProvider>(
                  builder: (context, provider, child) {
                    final savedKeyA = provider.getKeyForSector(sector!, 'A');
                    final savedKeyB = provider.getKeyForSector(sector!, 'B');

                    final displayKeyA = _useCustomKeys && customKeyA != null
                        ? customKeyA
                        : (savedKeyA ?? 'FFFFFFFFFFFF');
                    final displayKeyB = _useCustomKeys && customKeyB != null
                        ? customKeyB
                        : (savedKeyB ?? 'FFFFFFFFFFFF');

                    final keyASource = _useCustomKeys && customKeyA != null
                        ? '(Custom)'
                        : (savedKeyA != null ? '(Saved)' : '(Default)');
                    final keyBSource = _useCustomKeys && customKeyB != null
                        ? '(Custom)'
                        : (savedKeyB != null ? '(Saved)' : '(Default)');

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        const Text('Authentication keys to be used:'),
                        const SizedBox(height: 5),
                        Text('• Key A: $displayKeyA $keyASource'),
                        Text('• Key B: $displayKeyB $keyBSource'),
                      ],
                    );
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _performWrite(data, sector!, block!, customKeyA, customKeyB);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: sector == 0 && block == 0
                      ? Colors.red
                      : Colors.green,
                ),
                child: const Text('Write'),
              ),
            ],
          ),
    );
  } // Missing closing brace was here

  void _performWrite(String data, int sector, int block, String? customKeyA,
      String? customKeyB) {
    final provider = Provider.of<NfcProvider>(context, listen: false);

    // Validate custom keys if provided
    if (_useCustomKeys) {
      if ((customKeyA != null && !_isValidHex(customKeyA)) ||
          (customKeyB != null && !_isValidHex(customKeyB))) {
        _showError('Invalid custom key format. Must be 12 hex characters.');
        return;
      }
    }

    provider.writeData(
      data,
      _isHex,
      sector,
      block,
      customKeyA: _useCustomKeys ? customKeyA : null,
      customKeyB: _useCustomKeys ? customKeyB : null,
    ).then((success) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Data written to Sector $sector, Block $block'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        // Clear the input field
        _dataController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Write failed: ${provider.errorMessage}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Write error: $error'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}