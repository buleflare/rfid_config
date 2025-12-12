import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AccessBitsToolScreen extends StatefulWidget {
  const AccessBitsToolScreen({super.key});

  @override
  State<AccessBitsToolScreen> createState() => _AccessBitsToolScreenState();
}

class _AccessBitsToolScreenState extends State<AccessBitsToolScreen> {
  final _hexController = TextEditingController(text: '078069');
  final _generatedHexController = TextEditingController();

  // Data Block Permissions
  String _dataRead = 'key A|B';
  String _dataWrite = 'key A|B';
  String _dataIncrement = 'key A|B';
  String _dataDecrement = 'key A|B';
  String _dataTransfer = 'key A|B';

  // Trailer Block Permissions
  String _trailerReadKeyA = 'never';
  String _trailerWriteKeyA = 'key A';
  String _trailerReadKeyB = 'key A';
  String _trailerWriteKeyB = 'never';
  String _trailerReadAccess = 'key A';
  String _trailerWriteAccess = 'key A';

  // Selected combination indexes
  int? _selectedDataCombination;
  int? _selectedTrailerCombination;

  int _selectedTab = 0;

  // Data block combinations (8 valid combinations from Table 8)
  final List<Map<String, String>> _dataCombinations = [
    {
      'name': 'Combination 1 (0,0,0) - Transport',
      'read': 'key A|B',
      'write': 'key A|B',
      'increment': 'key A|B',
      'decrement': 'key A|B',
      'transfer': 'key A|B',
    },
    {
      'name': 'Combination 2 (0,1,0) - Read/Write',
      'read': 'key A|B',
      'write': 'never',
      'increment': 'never',
      'decrement': 'never',
      'transfer': 'never',
    },
    {
      'name': 'Combination 3 (1,0,0) - Read/Write B',
      'read': 'key A|B',
      'write': 'key B',
      'increment': 'never',
      'decrement': 'never',
      'transfer': 'never',
    },
    {
      'name': 'Combination 4 (1,1,0) - Value Block',
      'read': 'key A|B',
      'write': 'key B',
      'increment': 'key B',
      'decrement': 'key B',
      'transfer': 'key A|B',
    },
    {
      'name': 'Combination 5 (0,0,1) - Value Block 2',
      'read': 'key A|B',
      'write': 'never',
      'increment': 'never',
      'decrement': 'never',
      'transfer': 'key A|B',
    },
    {
      'name': 'Combination 6 (0,1,1) - Read/Write B only',
      'read': 'key B',
      'write': 'key B',
      'increment': 'never',
      'decrement': 'never',
      'transfer': 'never',
    },
    {
      'name': 'Combination 7 (1,0,1) - Read B only',
      'read': 'key B',
      'write': 'never',
      'increment': 'never',
      'decrement': 'never',
      'transfer': 'never',
    },
    {
      'name': 'Combination 8 (1,1,1) - Fully Locked',
      'read': 'never',
      'write': 'never',
      'increment': 'never',
      'decrement': 'never',
      'transfer': 'never',
    },
  ];

  // Trailer block combinations (8 valid combinations from Table 7)
  final List<Map<String, String>> _trailerCombinations = [
    {
      'name': 'Combination 1 (0,0,0) - Default',
      'readKeyA': 'never',
      'writeKeyA': 'key A',
      'readKeyB': 'key A',
      'writeKeyB': 'never',
      'readAccess': 'key A',
      'writeAccess': 'key A',
    },
    {
      'name': 'Combination 2 (0,1,0) - Read-Only',
      'readKeyA': 'never',
      'writeKeyA': 'never',
      'readKeyB': 'key A',
      'writeKeyB': 'never',
      'readAccess': 'key A',
      'writeAccess': 'never',
    },
    {
      'name': 'Combination 3 (1,0,0) - Key B Control',
      'readKeyA': 'never',
      'writeKeyA': 'key B',
      'readKeyB': 'key A|B',
      'writeKeyB': 'never',
      'readAccess': 'never',
      'writeAccess': 'key B',
    },
    {
      'name': 'Combination 4 (1,1,0) - Key B Only',
      'readKeyA': 'never',
      'writeKeyA': 'never',
      'readKeyB': 'key A|B',
      'writeKeyB': 'never',
      'readAccess': 'never',
      'writeAccess': 'never',
    },
    {
      'name': 'Combination 5 (0,0,1) - Transport Config',
      'readKeyA': 'never',
      'writeKeyA': 'key A',
      'readKeyB': 'key A',
      'writeKeyB': 'key A',
      'readAccess': 'key A',
      'writeAccess': 'key A',
    },
    {
      'name': 'Combination 6 (0,1,1) - Key B Write',
      'readKeyA': 'never',
      'writeKeyA': 'key B',
      'readKeyB': 'key A|B',
      'writeKeyB': 'key B',
      'readAccess': 'never',
      'writeAccess': 'key B',
    },
    {
      'name': 'Combination 7 (1,0,1) - Restricted',
      'readKeyA': 'never',
      'writeKeyA': 'never',
      'readKeyB': 'key A|B',
      'writeKeyB': 'key B',
      'readAccess': 'never',
      'writeAccess': 'never',
    },
    {
      'name': 'Combination 8 (1,1,1) - Locked',
      'readKeyA': 'never',
      'writeKeyA': 'never',
      'readKeyB': 'key A|B',
      'writeKeyB': 'never',
      'readAccess': 'never',
      'writeAccess': 'never',
    },
  ];

  @override
  void initState() {
    super.initState();
    // Set default to combination 1 for both
    _selectDataCombination(0);
    _selectTrailerCombination(0);
  }

  void _selectDataCombination(int index) {
    setState(() {
      _selectedDataCombination = index;
      final combo = _dataCombinations[index];
      _dataRead = combo['read']!;
      _dataWrite = combo['write']!;
      _dataIncrement = combo['increment']!;
      _dataDecrement = combo['decrement']!;
      _dataTransfer = combo['transfer']!;
    });
  }

  void _selectTrailerCombination(int index) {
    setState(() {
      _selectedTrailerCombination = index;
      final combo = _trailerCombinations[index];
      _trailerReadKeyA = combo['readKeyA']!;
      _trailerWriteKeyA = combo['writeKeyA']!;
      _trailerReadKeyB = combo['readKeyB']!;
      _trailerWriteKeyB = combo['writeKeyB']!;
      _trailerReadAccess = combo['readAccess']!;
      _trailerWriteAccess = combo['writeAccess']!;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Access Bits Tool'),
          backgroundColor: Colors.teal.shade800,
          bottom: TabBar(
            tabs: const [
              Tab(text: '🔍 Decode', icon: Icon(Icons.search)),
              Tab(text: '⚡ Generate', icon: Icon(Icons.build)),
            ],
            onTap: (index) => setState(() => _selectedTab = index),
          ),
        ),
        body: TabBarView(
          children: [
            _buildDecodeTab(),
            _buildGenerateTab(),
          ],
        ),
      ),
    );
  }

  // -------------------------
  // Decode Tab
  // -------------------------
  Widget _buildDecodeTab() {
    final decoded = _safeDecode(_hexController.text);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Input Hex
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _hexController,
                decoration: InputDecoration(
                  labelText: 'Access Bytes (6 hex chars, e.g. 078069)',
                  hintText: 'Enter 6 hex characters (B6 B7 B8)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => setState(() {}),
                  ),
                ),
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 16, letterSpacing: 2),
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                onChanged: (value) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            'Decoded Permissions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildDecodedCard('📦 Data Blocks (0–2)', decoded['data'] ?? {}),
          const SizedBox(height: 20),
          _buildDecodedCard('🔐 Trailer Block (3)', decoded['trailer'] ?? {}),
          const SizedBox(height: 30),
          _buildPresetChips(),
        ],
      ),
    );
  }

  Widget _buildDecodedCard(String title, Map<String, String> permissions) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: permissions.entries.map((e) {
            return _buildPermissionRow(e.key, e.value);
          }).toList(),
        ),
      ),
    );
  }

  // -------------------------
  // Generate Tab
  // -------------------------
  Widget _buildGenerateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Configure Permissions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text(
            'Select from 8 predefined combinations for data and trailer blocks.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 30),

          // Data Blocks Combination Selector
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.storage, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('📦 Data Blocks (0-2)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Data combination dropdown
                  DropdownButtonFormField<int>(
                    value: _selectedDataCombination,
                    decoration: InputDecoration(
                      labelText: 'Select Data Block Combination (1-8)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.blue.shade50,
                    ),
                    items: List.generate(8, (index) {
                      return DropdownMenuItem<int>(
                        value: index,
                        child: Text(_dataCombinations[index]['name']!),
                      );
                    }),
                    onChanged: (value) {
                      if (value != null) _selectDataCombination(value);
                    },
                    isExpanded: true,
                  ),

                  const SizedBox(height: 16),

                  // Show selected data permissions
                  _buildPermissionRow('Read Access', _dataRead),
                  _buildPermissionRow('Write Access', _dataWrite),
                  _buildPermissionRow('Increment', _dataIncrement),
                  _buildPermissionRow('Decrement/Transfer', _dataDecrement),
                  _buildPermissionRow('Transfer/Restore', _dataTransfer),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Trailer Block Combination Selector
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('🔐 Trailer Block (3)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Trailer combination dropdown
                  DropdownButtonFormField<int>(
                    value: _selectedTrailerCombination,
                    decoration: InputDecoration(
                      labelText: 'Select Trailer Block Combination (1-8)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.orange.shade50,
                    ),
                    items: List.generate(8, (index) {
                      return DropdownMenuItem<int>(
                        value: index,
                        child: Text(_trailerCombinations[index]['name']!),
                      );
                    }),
                    onChanged: (value) {
                      if (value != null) _selectTrailerCombination(value);
                    },
                    isExpanded: true,
                  ),

                  const SizedBox(height: 16),

                  // Show selected trailer permissions
                  _buildPermissionRow('Read Key A', _trailerReadKeyA),
                  _buildPermissionRow('Write Key A', _trailerWriteKeyA),
                  _buildPermissionRow('Read Key B', _trailerReadKeyB),
                  _buildPermissionRow('Write Key B', _trailerWriteKeyB),
                  _buildPermissionRow('Read Access Bits', _trailerReadAccess),
                  _buildPermissionRow('Write Access Bits', _trailerWriteAccess),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _generateHexCode,
            icon: const Icon(Icons.code),
            label: const Text('Generate Access Bytes (B6 B7 B8)'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Colors.teal,
            ),
          ),
          const SizedBox(height: 20),
          if (_generatedHexController.text.isNotEmpty) _buildGeneratedHexCard(),
        ],
      ),
    );
  }

  Widget _buildGeneratedHexCard() {
    return Card(
      color: Colors.teal.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('✅ Generated Access Bytes (B6 B7 B8)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _generatedHexController,
              readOnly: true,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2),
              decoration: InputDecoration(
                labelText: 'Copy 6-character hex code',
                hintText: 'e.g., 078069',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.content_copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _generatedHexController.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied!'), backgroundColor: Colors.green)
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                _hexController.text = _generatedHexController.text;
                setState(() => _selectedTab = 0);
              },
              child: const Text('Decode This Code'),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------
  // Permission Helpers
  // -------------------------
  Widget _buildPermissionRow(String label, String permission) {
    final color = _getPermissionColor(permission);
    final icon = _getPermissionIcon(permission);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
          const SizedBox(width: 10),
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(
                permission,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getPermissionColor(String permission) {
    switch (permission) {
      case 'never':
        return Colors.red;
      case 'key A':
        return Colors.blue;
      case 'key B':
        return Colors.green;
      case 'key A|B':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getPermissionIcon(String permission) {
    switch (permission) {
      case 'never':
        return Icons.block;
      case 'key A':
        return Icons.vpn_key;
      case 'key B':
        return Icons.key;
      case 'key A|B':
        return Icons.vpn_key_outlined;
      default:
        return Icons.help;
    }
  }

  // -------------------------
  // Presets
  // -------------------------
  Widget _buildPresetChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildPresetChip('Default (Open)', '078069'),
        _buildPresetChip('Read-Only Data', '078869'),
        _buildPresetChip('Key B Required', '778F69'),
        _buildPresetChip('Fully Locked', '778F00'),
        _buildPresetChip('NFC Forum', '078869'),
      ],
    );
  }

  Widget _buildPresetChip(String label, String hex) {
    return GestureDetector(
      onTap: () {
        _hexController.text = hex;
        setState(() {});
      },
      child: Chip(
        label: Text('$label\n$hex', style: const TextStyle(fontSize: 12)),
        avatar: const Icon(Icons.content_copy, size: 16),
        backgroundColor: Colors.teal.shade100,
      ),
    );
  }

  // -------------------------
  // CORRECTED DECODE LOGIC
  // -------------------------
  Map<String, Map<String, String>> _safeDecode(String hex) {
    try {
      return _decodeHexToPermissions(hex);
    } catch (e) {
      return {
        'data': {'read': 'Error', 'write': 'Error', 'increment': 'Error', 'decrement': 'Error', 'transfer': 'Error'},
        'trailer': {'readKeyA': 'Error','writeKeyA':'Error','readKeyB':'Error','writeKeyB':'Error','readAccess':'Error','writeAccess':'Error'},
      };
    }
  }

  Map<String, Map<String, String>> _decodeHexToPermissions(String hex) {
    try {
      // Clean hex input - expecting 6 chars (078069 format)
      final cleanHex = hex.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').padLeft(6, '0').substring(0, 6);

      // Parse hex to bytes (3 bytes total for B6, B7, B8)
      final bytes = List<int>.generate(3, (i) => int.parse(cleanHex.substring(i * 2, i * 2 + 2), radix: 16));

      final B6 = bytes[0];
      final B7 = bytes[1];
      final B8 = bytes[2];

      // Extract c1', c2', c3' from B6 and B7
      final c1_prime = [
        (B6 >> 0) & 1,  // c1'_B0
        (B6 >> 1) & 1,  // c1'_B1
        (B6 >> 2) & 1,  // c1'_B2
        (B6 >> 3) & 1,  // c1'_B3
      ];

      final c2_prime = [
        (B6 >> 4) & 1,  // c2'_B0
        (B6 >> 5) & 1,  // c2'_B1
        (B6 >> 6) & 1,  // c2'_B2
        (B6 >> 7) & 1,  // c2'_B3
      ];

      final c1 = [
        (B7 >> 4) & 1,  // c1_B0
        (B7 >> 5) & 1,  // c1_B1
        (B7 >> 6) & 1,  // c1_B2
        (B7 >> 7) & 1,  // c1_B3
      ];

      final c3_prime = [
        (B7 >> 0) & 1,  // c3'_B0
        (B7 >> 1) & 1,  // c3'_B1
        (B7 >> 2) & 1,  // c3'_B2
        (B7 >> 3) & 1,  // c3'_B3
      ];

      final c3 = [
        (B8 >> 4) & 1,  // c3_B0
        (B8 >> 5) & 1,  // c3_B1
        (B8 >> 6) & 1,  // c3_B2
        (B8 >> 7) & 1,  // c3_B3
      ];

      final c2 = [
        (B8 >> 0) & 1,  // c2_B0
        (B8 >> 1) & 1,  // c2_B1
        (B8 >> 2) & 1,  // c2_B2
        (B8 >> 3) & 1,  // c2_B3
      ];

      // Verify complement condition: cx = ~cx'
      bool isValid = true;
      for (int i = 0; i < 4; i++) {
        if (c1[i] != (c1_prime[i] ^ 1)) isValid = false;
        if (c2[i] != (c2_prime[i] ^ 1)) isValid = false;
        if (c3[i] != (c3_prime[i] ^ 1)) isValid = false;
      }

      if (!isValid) {
        return {
          'data': {'read': 'Invalid', 'write': 'Invalid', 'increment': 'Invalid', 'decrement': 'Invalid', 'transfer': 'Invalid'},
          'trailer': {'readKeyA': 'Invalid','writeKeyA':'Invalid','readKeyB':'Invalid','writeKeyB':'Invalid','readAccess':'Invalid','writeAccess':'Invalid'},
        };
      }

      // Function to get data block permissions from c1,c2,c3
      Map<String, String> getDataPermissions(int block) {
        final c1b = c1[block];
        final c2b = c2[block];
        final c3b = c3[block];

        // Table 8: Access conditions for data blocks
        if (c1b == 0 && c2b == 0 && c3b == 0) {
          return {'read': 'key A|B', 'write': 'key A|B', 'increment': 'key A|B', 'decrement': 'key A|B', 'transfer': 'key A|B'};
        } else if (c1b == 0 && c2b == 1 && c3b == 0) {
          return {'read': 'key A|B', 'write': 'never', 'increment': 'never', 'decrement': 'never', 'transfer': 'never'};
        } else if (c1b == 1 && c2b == 0 && c3b == 0) {
          return {'read': 'key A|B', 'write': 'key B', 'increment': 'never', 'decrement': 'never', 'transfer': 'never'};
        } else if (c1b == 1 && c2b == 1 && c3b == 0) {
          return {'read': 'key A|B', 'write': 'key B', 'increment': 'key B', 'decrement': 'key B', 'transfer': 'key A|B'};
        } else if (c1b == 0 && c2b == 0 && c3b == 1) {
          return {'read': 'key A|B', 'write': 'never', 'increment': 'never', 'decrement': 'never', 'transfer': 'key A|B'};
        } else if (c1b == 0 && c2b == 1 && c3b == 1) {
          return {'read': 'key B', 'write': 'key B', 'increment': 'never', 'decrement': 'never', 'transfer': 'never'};
        } else if (c1b == 1 && c2b == 0 && c3b == 1) {
          return {'read': 'key B', 'write': 'never', 'increment': 'never', 'decrement': 'never', 'transfer': 'never'};
        } else if (c1b == 1 && c2b == 1 && c3b == 1) {
          return {'read': 'never', 'write': 'never', 'increment': 'never', 'decrement': 'never', 'transfer': 'never'};
        }

        return {'read': 'Error', 'write': 'Error', 'increment': 'Error', 'decrement': 'Error', 'transfer': 'Error'};
      }

      // Function to get trailer block permissions from c1,c2,c3
      Map<String, String> getTrailerPermissions() {
        final c1b = c1[3];
        final c2b = c2[3];
        final c3b = c3[3];

        // Table 7: Access conditions for sector trailer
        if (c1b == 0 && c2b == 0 && c3b == 0) {
          return {
            'readKeyA': 'never', 'writeKeyA': 'key A',
            'readKeyB': 'key A', 'writeKeyB': 'never',
            'readAccess': 'key A', 'writeAccess': 'key A'
          };
        } else if (c1b == 0 && c2b == 1 && c3b == 0) {
          return {
            'readKeyA': 'never', 'writeKeyA': 'never',
            'readKeyB': 'key A', 'writeKeyB': 'never',
            'readAccess': 'key A', 'writeAccess': 'never'
          };
        } else if (c1b == 1 && c2b == 0 && c3b == 0) {
          return {
            'readKeyA': 'never', 'writeKeyA': 'key B',
            'readKeyB': 'key A|B', 'writeKeyB': 'never',
            'readAccess': 'never', 'writeAccess': 'key B'
          };
        } else if (c1b == 1 && c2b == 1 && c3b == 0) {
          return {
            'readKeyA': 'never', 'writeKeyA': 'never',
            'readKeyB': 'key A|B', 'writeKeyB': 'never',
            'readAccess': 'never', 'writeAccess': 'never'
          };
        } else if (c1b == 0 && c2b == 0 && c3b == 1) {
          return {
            'readKeyA': 'never', 'writeKeyA': 'key A',
            'readKeyB': 'key A', 'writeKeyB': 'key A',
            'readAccess': 'key A', 'writeAccess': 'key A'
          };
        } else if (c1b == 0 && c2b == 1 && c3b == 1) {
          return {
            'readKeyA': 'never', 'writeKeyA': 'key B',
            'readKeyB': 'key A|B', 'writeKeyB': 'key B',
            'readAccess': 'never', 'writeAccess': 'key B'
          };
        } else if (c1b == 1 && c2b == 0 && c3b == 1) {
          return {
            'readKeyA': 'never', 'writeKeyA': 'never',
            'readKeyB': 'key A|B', 'writeKeyB': 'key B',
            'readAccess': 'never', 'writeAccess': 'never'
          };
        } else if (c1b == 1 && c2b == 1 && c3b == 1) {
          return {
            'readKeyA': 'never', 'writeKeyA': 'never',
            'readKeyB': 'key A|B', 'writeKeyB': 'never',
            'readAccess': 'never', 'writeAccess': 'never'
          };
        }

        return {
          'readKeyA': 'Error', 'writeKeyA': 'Error',
          'readKeyB': 'Error', 'writeKeyB': 'Error',
          'readAccess': 'Error', 'writeAccess': 'Error'
        };
      }

      // Get permissions for all blocks
      final block0Perms = getDataPermissions(0);
      final block1Perms = getDataPermissions(1);
      final block2Perms = getDataPermissions(2);
      final trailerPerms = getTrailerPermissions();

      // Check if all data blocks have same permissions
      final sameDataBlocks =
          block0Perms['read'] == block1Perms['read'] &&
              block0Perms['write'] == block1Perms['write'] &&
              block0Perms['read'] == block2Perms['read'] &&
              block0Perms['write'] == block2Perms['write'];

      if (sameDataBlocks) {
        return {
          'data': block0Perms,
          'trailer': trailerPerms,
        };
      } else {
        return {
          'data0': block0Perms,
          'data1': block1Perms,
          'data2': block2Perms,
          'trailer': trailerPerms,
        };
      }

    } catch (e) {
      print('Decode error: $e');
      return {
        'data': {'read': 'Error', 'write': 'Error', 'increment': 'Error', 'decrement': 'Error', 'transfer': 'Error'},
        'trailer': {'readKeyA': 'Error','writeKeyA':'Error','readKeyB':'Error','writeKeyB':'Error','readAccess':'Error','writeAccess':'Error'},
      };
    }
  }

  // -------------------------
  // CORRECTED ENCODE LOGIC
  // -------------------------
  void _generateHexCode() {
    try {
      // Helper to convert permissions to c1,c2,c3 bits for data blocks
      List<int> dataPermissionsToBits(String read, String write, String increment, String decrement, String transfer) {
        // Map permissions to Table 8 - 8 valid combinations only
        if (read == 'key A|B' && write == 'key A|B' && increment == 'key A|B' && decrement == 'key A|B' && transfer == 'key A|B') {
          return [0, 0, 0];
        } else if (read == 'key A|B' && write == 'never' && increment == 'never' && decrement == 'never' && transfer == 'never') {
          return [0, 1, 0];
        } else if (read == 'key A|B' && write == 'key B' && increment == 'never' && decrement == 'never' && transfer == 'never') {
          return [1, 0, 0];
        } else if (read == 'key A|B' && write == 'key B' && increment == 'key B' && decrement == 'key B' && transfer == 'key A|B') {
          return [1, 1, 0];
        } else if (read == 'key A|B' && write == 'never' && increment == 'never' && decrement == 'never' && transfer == 'key A|B') {
          return [0, 0, 1];
        } else if (read == 'key B' && write == 'key B' && increment == 'never' && decrement == 'never' && transfer == 'never') {
          return [0, 1, 1];
        } else if (read == 'key B' && write == 'never' && increment == 'never' && decrement == 'never' && transfer == 'never') {
          return [1, 0, 1];
        } else if (read == 'never' && write == 'never' && increment == 'never' && decrement == 'never' && transfer == 'never') {
          return [1, 1, 1];
        } else {
          // Should never reach here as we only allow 8 combinations
          return [0, 0, 0];
        }
      }

      // Helper to convert permissions to c1,c2,c3 bits for trailer
      List<int> trailerPermissionsToBits(String readKeyA, String writeKeyA, String readKeyB,
          String writeKeyB, String readAccess, String writeAccess) {
        // Map permissions to Table 7 - 8 valid combinations only
        if (readKeyA == 'never' && writeKeyA == 'key A' && readKeyB == 'key A' &&
            writeKeyB == 'never' && readAccess == 'key A' && writeAccess == 'key A') {
          return [0, 0, 0];
        } else if (readKeyA == 'never' && writeKeyA == 'never' && readKeyB == 'key A' &&
            writeKeyB == 'never' && readAccess == 'key A' && writeAccess == 'never') {
          return [0, 1, 0];
        } else if (readKeyA == 'never' && writeKeyA == 'key B' && readKeyB == 'key A|B' &&
            writeKeyB == 'never' && readAccess == 'never' && writeAccess == 'key B') {
          return [1, 0, 0];
        } else if (readKeyA == 'never' && writeKeyA == 'never' && readKeyB == 'key A|B' &&
            writeKeyB == 'never' && readAccess == 'never' && writeAccess == 'never') {
          return [1, 1, 0];
        } else if (readKeyA == 'never' && writeKeyA == 'key A' && readKeyB == 'key A' &&
            writeKeyB == 'key A' && readAccess == 'key A' && writeAccess == 'key A') {
          return [0, 0, 1];
        } else if (readKeyA == 'never' && writeKeyA == 'key B' && readKeyB == 'key A|B' &&
            writeKeyB == 'key B' && readAccess == 'never' && writeAccess == 'key B') {
          return [0, 1, 1];
        } else if (readKeyA == 'never' && writeKeyA == 'never' && readKeyB == 'key A|B' &&
            writeKeyB == 'key B' && readAccess == 'never' && writeAccess == 'never') {
          return [1, 0, 1];
        } else if (readKeyA == 'never' && writeKeyA == 'never' && readKeyB == 'key A|B' &&
            writeKeyB == 'never' && readAccess == 'never' && writeAccess == 'never') {
          return [1, 1, 1];
        } else {
          // Should never reach here as we only allow 8 combinations
          return [0, 0, 0];
        }
      }

      // Get bits for data blocks
      final dataBits = dataPermissionsToBits(
          _dataRead, _dataWrite, _dataIncrement, _dataDecrement, _dataTransfer
      );

      // Get bits for trailer (block 3)
      final trailerBits = trailerPermissionsToBits(
          _trailerReadKeyA, _trailerWriteKeyA, _trailerReadKeyB,
          _trailerWriteKeyB, _trailerReadAccess, _trailerWriteAccess
      );

      // Create c1, c2, c3 arrays for blocks 0-3
      final c1 = [dataBits[0], dataBits[0], dataBits[0], trailerBits[0]];
      final c2 = [dataBits[1], dataBits[1], dataBits[1], trailerBits[1]];
      final c3 = [dataBits[2], dataBits[2], dataBits[2], trailerBits[2]];

      // Create complement bits
      final c1_prime = c1.map((bit) => bit ^ 1).toList();
      final c2_prime = c2.map((bit) => bit ^ 1).toList();
      final c3_prime = c3.map((bit) => bit ^ 1).toList();

      // Build B6 byte
      int B6 = 0;
      B6 |= (c2_prime[3] << 7);
      B6 |= (c2_prime[2] << 6);
      B6 |= (c2_prime[1] << 5);
      B6 |= (c2_prime[0] << 4);
      B6 |= (c1_prime[3] << 3);
      B6 |= (c1_prime[2] << 2);
      B6 |= (c1_prime[1] << 1);
      B6 |= (c1_prime[0] << 0);

      // Build B7 byte
      int B7 = 0;
      B7 |= (c1[3] << 7);
      B7 |= (c1[2] << 6);
      B7 |= (c1[1] << 5);
      B7 |= (c1[0] << 4);
      B7 |= (c3_prime[3] << 3);
      B7 |= (c3_prime[2] << 2);
      B7 |= (c3_prime[1] << 1);
      B7 |= (c3_prime[0] << 0);

      // Build B8 byte
      int B8 = 0;
      B8 |= (c3[3] << 7);
      B8 |= (c3[2] << 6);
      B8 |= (c3[1] << 5);
      B8 |= (c3[0] << 4);
      B8 |= (c2[3] << 3);
      B8 |= (c2[2] << 2);
      B8 |= (c2[1] << 1);
      B8 |= (c2[0] << 0);

      // Format as hex: B6 + B7 + B8 (3 bytes = 6 hex characters)
      final hexString =
          '${B6.toRadixString(16).padLeft(2, '0').toUpperCase()}'
          '${B7.toRadixString(16).padLeft(2, '0').toUpperCase()}'
          '${B8.toRadixString(16).padLeft(2, '0').toUpperCase()}';

      setState(() {
        _generatedHexController.text = hexString;
      });

    } catch (e) {
      print('Error generating hex: $e');
      setState(() {
        _generatedHexController.text = 'ERROR: $e';
      });
    }
  }

  @override
  void dispose() {
    _hexController.dispose();
    _generatedHexController.dispose();
    super.dispose();
  }
}