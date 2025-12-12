import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/nfc_provider.dart';

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
  final _accessBitsController = TextEditingController(text: '078069'); // Only 6 chars now

  // Selected key type for authentication
  String _selectedKeyType = 'Key A';

  @override
  Widget build(BuildContext context) {
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

                    // Authentication Section
                    const Text(
                      'Authentication',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedKeyType,
                            decoration: InputDecoration(
                              labelText: 'Authenticate With',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Key A',
                                child: Text('Key A 🔑'),
                              ),
                              DropdownMenuItem(
                                value: 'Key B',
                                child: Text('Key B 🔑'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedKeyType = value!);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _currentKeyController,
                            label: 'Current Key',
                            hint: '12 hex digits',
                            icon: Icons.vpn_key,
                          ),
                        ),
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

                    _buildTextField(
                      controller: _newKeyAController,
                      label: 'New Key A (6 bytes)',
                      hint: 'FFFFFFFFFFFF',
                      icon: Icons.vpn_key,
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _newKeyBController,
                      label: 'New Key B (6 bytes)',
                      hint: 'FFFFFFFFFFFF',
                      icon: Icons.vpn_key,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _accessBitsController,
                            label: 'Access Bits (B6,B7,B8)',
                            hint: '078069',
                            icon: Icons.lock,
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
                            setState(() {
                              _newKeyAController.text = 'FFFFFFFFFFFF';
                              _newKeyBController.text = 'FFFFFFFFFFFF';
                              _accessBitsController.text = '078069';
                            });
                          },
                          color: Colors.green,
                        ),
                        _buildTemplateChip(
                          'Read Only',
                              () {
                            setState(() {
                              _newKeyAController.text = 'FFFFFFFFFFFF';
                              _newKeyBController.text = 'FFFFFFFFFFFF';
                              _accessBitsController.text = '078869';
                            });
                          },
                          color: Colors.blue,
                        ),
                        _buildTemplateChip(
                          'Key B Required',
                              () {
                            setState(() {
                              _newKeyAController.text = 'FFFFFFFFFFFF';
                              _newKeyBController.text = 'A0B1C2D3E4F5';
                              _accessBitsController.text = '778F69';
                            });
                          },
                          color: Colors.purple,
                        ),
                        _buildTemplateChip(
                          'Fully Locked',
                              () {
                            setState(() {
                              _newKeyAController.text = 'FFFFFFFFFFFF';
                              _newKeyBController.text = 'FFFFFFFFFFFF';
                              _accessBitsController.text = '778F00';
                            });
                          },
                          color: Colors.red,
                        ),
                        _buildTemplateChip(
                          'Custom Key A Only',
                              () {
                            setState(() {
                              _newKeyAController.text = 'A0A1A2A3A4A5';
                              _newKeyBController.text = 'FFFFFFFFFFFF';
                              _accessBitsController.text = '078869';
                            });
                          },
                          color: Colors.orange,
                        ),
                      ],
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
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
            hintText: hint,
            prefixIcon: Icon(icon),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            counterText: '',
          ),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
          ),
          textCapitalization: TextCapitalization.characters,
          maxLength: hint.contains('12') ? 12 : 6,
        ),
      ],
    );
  }

  Widget _buildTemplateChip(String label, VoidCallback onTap, {Color color = Colors.blue}) {
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        label: Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
        backgroundColor: color.withOpacity(0.1),
        side: BorderSide(color: color.withOpacity(0.3)),
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        avatar: Icon(
          Icons.settings,
          size: 16,
          color: color,
        ),
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

  void _configureSector() {
    // Get and validate inputs
    final sector = int.tryParse(_sectorController.text);
    final currentKey = _currentKeyController.text.toUpperCase();
    final newKeyA = _newKeyAController.text.toUpperCase();
    final newKeyB = _newKeyBController.text.toUpperCase();
    final accessBits = _accessBitsController.text.toUpperCase();

    // Validate sector number
    if (sector == null || sector < 0 || sector > 15) {
      _showError('Please enter a valid sector number (0-15)');
      return;
    }

    // Validate keys and access bits
    if (!_isValidHex(currentKey, 12)) {
      _showError('Current key must be 12 hexadecimal digits');
      return;
    }

    if (!_isValidHex(newKeyA, 12)) {
      _showError('New Key A must be 12 hexadecimal digits');
      return;
    }

    if (!_isValidHex(newKeyB, 12)) {
      _showError('New Key B must be 12 hexadecimal digits');
      return;
    }

    if (!_isValidHex(accessBits, 6)) {
      _showError('Access bits must be 6 hexadecimal digits');
      return;
    }

    // Construct trailer block (16 bytes = 32 hex chars)
    // Format: Key A (6B) + Access Bits (3B) + User Byte (1B) + Key B (6B)
    final userByte = '69'; // Fixed user byte for Key B visibility
    final trailerBlock = newKeyA + accessBits + userByte + newKeyB;

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Confirm Sector Configuration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sector: $sector'),
            Text('Authenticate with: $_selectedKeyType'),
            const SizedBox(height: 16),
            const Text('New Trailer Block:'),
            SelectableText(
              trailerBlock,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Structure:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Key A: ${trailerBlock.substring(0, 12)} (6 bytes)'),
            Text('Access Bits: ${trailerBlock.substring(12, 18)} (3 bytes)'),
            Text('User Byte: ${trailerBlock.substring(18, 20)} (0x69)'),
            Text('Key B: ${trailerBlock.substring(20, 32)} (6 bytes)'),
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _writeConfiguration(sector, currentKey, trailerBlock);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Write Configuration'),
          ),
        ],
      ),
    );
  }

  bool _isValidHex(String value, int length) {
    final regex = RegExp(r'^[0-9A-F]{' + length.toString() + r'}$');
    return regex.hasMatch(value);
  }

  void _writeConfiguration(int sector, String currentKey, String trailerBlock) {
    // Get the NFC provider
    final provider = Provider.of<NfcProvider>(context, listen: false);

    // In a real implementation, you would call:
    // provider.writeSector(sector, currentKey, _selectedKeyType, trailerBlock);

    // For now, show a simulation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Writing configuration to Sector $sector...'),
        duration: const Duration(seconds: 2),
      ),
    );

    // Simulate write operation
    Future.delayed(const Duration(seconds: 2), () {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Configuration written to Sector $sector'),
          backgroundColor: Colors.green,
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