import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/nfc_provider.dart';

import 'package:flutter/services.dart';

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _sectorController = TextEditingController(text: '1');
  final _currentKeyController = TextEditingController(text: 'FFFFFFFFFFFF');
  final _newKeyAController = TextEditingController(text: 'FFFFFFFFFFFF');
  final _newKeyBController = TextEditingController(text: 'FFFFFFFFFFFF');
  final _accessBitsController = TextEditingController(text: 'FF0780'); // Only 6 chars now

  // Selected key type for authentication
  String _selectedKeyType = 'Key A';
  bool _isWriting = false;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<NfcProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configure Sector'),
        backgroundColor: Colors.orange.shade800,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Key Status
            Consumer<NfcProvider>(
              builder: (context, provider, child) {
                final sector = int.tryParse(_sectorController.text) ?? 1;
                final savedKeyA = provider.getKeyForSector(sector, 'A');
                final savedKeyB = provider.getKeyForSector(sector, 'B');

                if (savedKeyA != null || savedKeyB != null) {
                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 20),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Saved Keys for This Sector',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          if (savedKeyA != null) Text('Key A: $savedKeyA'),
                          if (savedKeyB != null) Text('Key B: $savedKeyB'),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {
                              if (savedKeyA != null) {
                                _currentKeyController.text = savedKeyA;
                                setState(() => _selectedKeyType = 'Key A');
                              }
                            },
                            child: const Text('Use Saved Key A'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 36),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            // Configuration Form
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sector Configuration',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Sector Number
                    _buildTextField(
                      controller: _sectorController,
                      label: 'Sector Number (0-15)',
                      hint: '0-15',
                      icon: Icons.grid_view,
                    ),
                    const SizedBox(height: 16),

                    // Authentication Section - CHANGED TO COLUMN
                    const Text(
                      'Authentication',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    // Key Type Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedKeyType,
                      decoration: InputDecoration(
                        labelText: 'Authenticate With',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        prefixIcon: const Icon(Icons.vpn_key),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Key A',
                          child: Row(
                            children: [
                              Icon(Icons.vpn_key, size: 20),
                              SizedBox(width: 8),
                              Text('Key A'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'Key B',
                          child: Row(
                            children: [
                              Icon(Icons.key, size: 20),
                              SizedBox(width: 8),
                              Text('Key B'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: _isWriting ? null : (value) {
                        setState(() => _selectedKeyType = value!);
                      },
                    ),

                    const SizedBox(height: 16),

                    // Current Key Input
                    _buildTextField(
                      controller: _currentKeyController,
                      label: 'Current Key (12 hex digits)',
                      hint: 'FFFFFFFFFFFF',
                      icon: Icons.vpn_key,
                      enabled: !_isWriting,
                      isKeyField: true,
                    ),

                    // Example keys for quick selection
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildExampleKeyChip('Default Key', 'FFFFFFFFFFFF'),
                        _buildExampleKeyChip('All Zeros', '000000000000'),
                        _buildExampleKeyChip('Random Key', 'A0B1C2D3E4F5'),
                        _buildExampleKeyChip('Alternate', 'D3F7D3F7D3F7'),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),

                    // New Configuration
                    const Text(
                      'New Configuration',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    // For New Key A
                    _buildTextField(
                      controller: _newKeyAController,
                      label: 'New Key A (12 hex digits)',
                      hint: 'FFFFFFFFFFFF',
                      icon: Icons.vpn_key,
                      enabled: !_isWriting,
                      isKeyField: true,
                    ),

                    const SizedBox(height: 16),

                    // For New Key B
                    _buildTextField(
                      controller: _newKeyBController,
                      label: 'New Key B (12 hex digits)',
                      hint: 'FFFFFFFFFFFF',
                      icon: Icons.vpn_key,
                      enabled: !_isWriting,
                      isKeyField: true,
                    ),

                    const SizedBox(height: 16),

                    // Example keys for New Keys
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildExampleNewKeyChip('Default', 'FFFFFFFFFFFF'),
                        _buildExampleNewKeyChip('Zeros', '000000000000'),
                        _buildExampleNewKeyChip('Custom A', 'A0A1A2A3A4A5'),
                        _buildExampleNewKeyChip('Custom B', 'B0B1B2B3B4B5'),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Access Bits and User Byte
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _accessBitsController,
                            label: 'Access Bits (6 hex digits)',
                            hint: '078069',
                            icon: Icons.lock,
                            enabled: !_isWriting,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          width: 120,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'User Byte',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: const Center(
                                  child: Text(
                                    '69',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Warning Message
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Warning: Wrong access bits can permanently lock the sector!',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Write Button
                    if (_isWriting)
                      const Center(child: CircularProgressIndicator())
                    else
                      ElevatedButton.icon(
                        onPressed: _configureSector,
                        icon: const Icon(Icons.save),
                        label: const Text('Write Configuration'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: Colors.orange,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Quick Configuration Templates
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Configuration Templates',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTemplateChip(
                          'Default Open',
                              () {
                            if (!_isWriting) {
                              setState(() {
                                _newKeyAController.text = 'FFFFFFFFFFFF';
                                _newKeyBController.text = 'FFFFFFFFFFFF';
                                _accessBitsController.text = '078069';
                              });
                            }
                          },
                          color: Colors.green,
                          enabled: !_isWriting,
                        ),
                        _buildTemplateChip(
                          'Read Only',
                              () {
                            if (!_isWriting) {
                              setState(() {
                                _newKeyAController.text = 'FFFFFFFFFFFF';
                                _newKeyBController.text = 'FFFFFFFFFFFF';
                                _accessBitsController.text = '078869';
                              });
                            }
                          },
                          color: Colors.blue,
                          enabled: !_isWriting,
                        ),
                        _buildTemplateChip(
                          'Key B Required',
                              () {
                            if (!_isWriting) {
                              setState(() {
                                _newKeyAController.text = 'FFFFFFFFFFFF';
                                _newKeyBController.text = 'A0B1C2D3E4F5';
                                _accessBitsController.text = '778F69';
                              });
                            }
                          },
                          color: Colors.purple,
                          enabled: !_isWriting,
                        ),
                        _buildTemplateChip(
                          'Fully Locked',
                              () {
                            if (!_isWriting) {
                              setState(() {
                                _newKeyAController.text = 'FFFFFFFFFFFF';
                                _newKeyBController.text = 'FFFFFFFFFFFF';
                                _accessBitsController.text = '778F00';
                              });
                            }
                          },
                          color: Colors.red,
                          enabled: !_isWriting,
                        ),
                        _buildTemplateChip(
                          'Custom Key A Only',
                              () {
                            if (!_isWriting) {
                              setState(() {
                                _newKeyAController.text = 'A0A1A2A3A4A5';
                                _newKeyBController.text = 'FFFFFFFFFFFF';
                                _accessBitsController.text = '078869';
                              });
                            }
                          },
                          color: Colors.orange,
                          enabled: !_isWriting,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Access Bits Decoder
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Access Bits Decoder',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_accessBitsController.text.isNotEmpty &&
                        _isValidHex(_accessBitsController.text, 6)) ...[
                      _buildAccessBitsInfo(_accessBitsController.text),
                      const SizedBox(height: 12),
                    ],

                    ElevatedButton(
                      onPressed: () {
                        _showAccessBitsDecoder(context);
                      },
                      child: const Text('Decode Access Bits'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // How It Works
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'How Sector Configuration Works',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildStep(
                      1,
                      'Enter sector number (0-15) and current key',
                    ),
                    _buildStep(
                      2,
                      'Select which key (A or B) you know for authentication',
                    ),
                    _buildStep(
                      3,
                      'Enter new Key A (6 bytes = 12 hex digits)',
                    ),
                    _buildStep(
                      4,
                      'Enter new Key B (6 bytes = 12 hex digits)',
                    ),
                    _buildStep(
                      5,
                      'Enter access bits (B6,B7,B8 = 3 bytes = 6 hex digits)',
                    ),
                    _buildStep(
                      6,
                      'User byte is fixed as 0x69 for Key B visibility',
                    ),

                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),

                    const Text(
                      'Important Notes:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),

                    _buildNote('✓ You must know the current key to write new configuration'),
                    _buildNote('✓ Access bits control permissions for the entire sector'),
                    _buildNote('✓ Wrong access bits can permanently lock the sector'),
                    _buildNote('✓ Always test on disposable cards first'),
                    _buildNote('✓ Key B can be set to "never" readable in access bits'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


// Add these methods to your class
  Widget _buildExampleKeyChip(String label, String key) {
    return GestureDetector(
      onTap: () {
        if (!_isWriting) {
          setState(() {
            _currentKeyController.text = key;
          });
        }
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

  Widget _buildExampleNewKeyChip(String label, String key) {
    return GestureDetector(
      onTap: () {
        if (!_isWriting) {
          setState(() {
            // Apply to both New Key A and New Key B for simplicity
            // You could modify this to apply to a specific field
            _newKeyAController.text = key;
            _newKeyBController.text = key;
          });
        }
      },
      child: Chip(
        label: Text(label),
        avatar: const Icon(Icons.vpn_key, size: 16),
        backgroundColor: Colors.blue.shade100,
        labelStyle: const TextStyle(fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
    );
  }

// Update the _buildTextField method to handle key validation
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool enabled = true,
    bool isKeyField = false,
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
          enabled: enabled,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            filled: true,
            fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade200,
            counterText: '',
            errorText: isKeyField && controller.text.isNotEmpty
                ? _validateKey(controller.text)
                : null,
          ),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            letterSpacing: 1.2,
          ),
          textCapitalization: TextCapitalization.characters,
          maxLength: isKeyField ? 12 : (hint.contains('Access') ? 6 : null),
          onChanged: (value) {
            if (isKeyField) {
              setState(() {}); // Trigger validation update
            }
          },
          inputFormatters: isKeyField ? [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f]')),
          ] : [],
        ),
      ],
    );
  }

// Add this validation method
  String? _validateKey(String key) {
    if (key.isEmpty) return null;

    final cleanKey = key.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();

    if (cleanKey.length != 12) {
      return 'Must be 12 hex characters';
    }

    if (!RegExp(r'^[0-9A-F]{12}$').hasMatch(cleanKey)) {
      return 'Invalid hex characters';
    }

    return null;
  }

  Widget _buildTemplateChip(String label, VoidCallback onTap, {
    Color color = Colors.blue,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Chip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: enabled ? Colors.black : Colors.grey,
          ),
        ),
        backgroundColor: color.withOpacity(0.1),
        side: BorderSide(color: color.withOpacity(0.3)),
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        avatar: Icon(
          Icons.settings,
          size: 16,
          color: enabled ? color : Colors.grey,
        ),
      ),
    );
  }

  Widget _buildAccessBitsInfo(String accessBitsHex) {
    if (accessBitsHex.length < 6) return const SizedBox.shrink();

    // Decode access bits (simplified)
    final isDefaultOpen = accessBitsHex == '078069';
    final isReadOnly = accessBitsHex == '078869';
    final isFullyLocked = accessBitsHex == '778F00';

    String permissionText = 'Custom Configuration';
    Color color = Colors.orange;

    if (isDefaultOpen) {
      permissionText = 'Default Open (Key A: RW, Key B: RW)';
      color = Colors.green;
    } else if (isReadOnly) {
      permissionText = 'Read Only (Key A: RO, Key B: RO)';
      color = Colors.blue;
    } else if (isFullyLocked) {
      permissionText = 'Fully Locked (Key A: NO ACCESS, Key B: NO ACCESS)';
      color = Colors.red;
    }

    return Container(
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
            permissionText,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text('Access Bits: $accessBitsHex'),
          const SizedBox(height: 4),
          Text('Block 0-2: Data blocks for sector 0, Data blocks for sectors 1-15'),
        ],
      ),
    );
  }

  Widget _buildStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNote(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  void _configureSector() async {
    // Get and validate inputs
    final sector = int.tryParse(_sectorController.text);
    final currentKey = _currentKeyController.text.toUpperCase().replaceAll(RegExp(r'[^0-9A-F]'), '');
    final newKeyA = _newKeyAController.text.toUpperCase().replaceAll(RegExp(r'[^0-9A-F]'), '');
    final newKeyB = _newKeyBController.text.toUpperCase().replaceAll(RegExp(r'[^0-9A-F]'), '');
    final accessBits = _accessBitsController.text.toUpperCase().replaceAll(RegExp(r'[^0-9A-F]'), '');

    print('DEBUG: Starting sector configuration');
    print('DEBUG: Sector: $sector');
    print('DEBUG: Current Key: $currentKey');
    print('DEBUG: Key Type: $_selectedKeyType');
    print('DEBUG: New Key A: $newKeyA');
    print('DEBUG: New Key B: $newKeyB');
    print('DEBUG: Access Bits: $accessBits');

    // Validate sector number
    if (sector == null || sector < 0 || sector > 15) {
      _showError('Please enter a valid sector number (0-15)');
      return;
    }

    // Validate keys using helper method
    final currentKeyError = _validateKey(currentKey);
    final newKeyAError = _validateKey(newKeyA);
    final newKeyBError = _validateKey(newKeyB);

    if (currentKeyError != null) {
      _showError('Current Key: $currentKeyError');
      return;
    }

    if (newKeyAError != null) {
      _showError('New Key A: $newKeyAError');
      return;
    }

    if (newKeyBError != null) {
      _showError('New Key B: $newKeyBError');
      return;
    }

    // Validate access bits
    if (!_isValidHex(accessBits, 6)) {
      _showError('Access bits must be 6 hexadecimal digits (3 bytes)');
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Confirm Sector Configuration'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sector: $sector'),
              Text('Authenticate with: $_selectedKeyType'),
              const SizedBox(height: 16),
              const Text(
                'This will write the following trailer block structure:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Key A (6 bytes): $newKeyA', style: const TextStyle(fontFamily: 'monospace')),
                    Text('Access Bits (3 bytes): $accessBits', style: const TextStyle(fontFamily: 'monospace')),
                    Text('User Byte (1 byte): 0x69', style: const TextStyle(fontFamily: 'monospace')),
                    Text('Key B (6 bytes): $newKeyB', style: const TextStyle(fontFamily: 'monospace')),
                    const SizedBox(height: 8),
                    Text(
                      'Full trailer block (16 bytes): ${newKeyA}${accessBits}69${newKeyB}',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '⚠️ Warning: Wrong access bits can permanently lock this sector!',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Write Configuration'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      print('DEBUG: User cancelled configuration');
      return;
    }

    // Start writing
    setState(() => _isWriting = true);

    try {
      final provider = Provider.of<NfcProvider>(context, listen: false);
      print('DEBUG: Checking if tag is present...');
      final tagPresent = await provider.checkTagPresent();
      if (!tagPresent) {
        _showError('No NFC tag detected. Please tap your card first.');
        return;
      }
      print('DEBUG: Calling provider.configureSector()...');

      // Use the configureSector method
      final success = await provider.configureSector(
        sector: sector,
        currentKey: currentKey,
        keyType: _selectedKeyType == 'Key A' ? 'A' : 'B',
        newKeyA: newKeyA,
        newKeyB: newKeyB,
        accessBits: accessBits,
      );

      print('DEBUG: configureSector returned: $success');
      print('DEBUG: Provider error message: ${provider.errorMessage}');

      if (success) {
        // Save the new key A for future use
        await provider.setCustomKey(sector, 'A', newKeyA);

        print('DEBUG: Configuration successful, updating UI...');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✓ Sector $sector configured successfully!'),
                SizedBox(height: 4),
                Text(
                  'Note: Key A may show as zeros when read back - this is normal.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );

        // Update current key in form to the new Key A
        _currentKeyController.text = newKeyA;
        _selectedKeyType = 'Key A';

        // Trigger a re-scan to show updated configuration
        await Future.delayed(const Duration(milliseconds: 1000));
        provider.startScan();

      } else {
        String errorMsg = 'Failed to write configuration';
        if (provider.errorMessage.isNotEmpty) {
          errorMsg += ': ${provider.errorMessage}';
        }
        _showError(errorMsg);
      }
    } catch (e, stackTrace) {
      print('DEBUG: Exception in _configureSector: $e');
      print('DEBUG: Stack trace: $stackTrace');
      _showError('Error: $e');
    } finally {
      setState(() => _isWriting = false);
    }
  }

  bool _isValidHex(String value, int length) {
    final cleanValue = value.replaceAll(RegExp(r'[^0-9A-F]'), '').toUpperCase();
    if (cleanValue.length != length) return false;
    final regex = RegExp(r'^[0-9A-F]{' + length.toString() + r'}$');
    return regex.hasMatch(cleanValue);
  }

  void _showAccessBitsDecoder(BuildContext context) {
    final accessBitsController = TextEditingController(text: _accessBitsController.text);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Access Bits Decoder'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: accessBitsController,
                decoration: const InputDecoration(
                  labelText: 'Access Bits (6 hex digits)',
                  hintText: '078069',
                ),
                style: const TextStyle(fontFamily: 'monospace'),
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                onChanged: (value) {
                  setState(() {
                    _accessBitsController.text = value.toUpperCase();
                  });
                },
              ),
              const SizedBox(height: 16),
              if (_isValidHex(accessBitsController.text, 6))
                _buildDetailedAccessBitsInfo(accessBitsController.text)
              else
                const Text('Enter 6 hex digits to decode'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _accessBitsController.text = accessBitsController.text.toUpperCase();
              });
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedAccessBitsInfo(String accessBits) {
    // This is a simplified decoder - in reality, you'd need to parse each bit
    final Map<String, String> commonAccessBits = {
      '078069': 'Default Open (Key A: RW, Key B: RW, Key B readable)',
      '078869': 'Read Only (Key A: RO, Key B: RO, Key B readable)',
      '778F69': 'Key B Required (Key A: RW, Key B: RW, Key B readable)',
      '778F00': 'Fully Locked (Key A: NO ACCESS, Key B: NO ACCESS, Key B not readable)',
      '08778F': 'Transport Configuration (Key A: NO ACCESS, Key B: RW, Key B not readable)',
    };

    final description = commonAccessBits[accessBits] ?? 'Custom Configuration';
    final isDangerous = accessBits == '778F00' || accessBits == '08778F';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDangerous ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDangerous ? Colors.red.shade200 : Colors.green.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            description,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDangerous ? Colors.red : Colors.green,
            ),
          ),
          const SizedBox(height: 8),
          const Text('Permissions per block:'),
          const Text('• Block 0-2: Data blocks (access controlled by bits)'),
          const Text('• Block 3/15: Trailer block (Key A/B + Access Bits)'),
          if (isDangerous) ...[
            const SizedBox(height: 8),
            const Text(
              '⚠️ This configuration may lock the sector!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _sectorController.dispose();
    _currentKeyController.dispose();
    _newKeyAController.dispose();
    _newKeyBController.dispose();
    _accessBitsController.dispose();
    super.dispose();
  }
}