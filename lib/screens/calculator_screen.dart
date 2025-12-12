import 'package:flutter/material.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final Map<String, Map<String, String>> _accessMatrix = {
    'Block 0': {'read': 'KeyA|B', 'write': 'KeyA|B', 'inc': 'KeyA|B', 'dec': 'KeyA|B'},
    'Block 1': {'read': 'KeyA|B', 'write': 'KeyA|B', 'inc': 'KeyA|B', 'dec': 'KeyA|B'},
    'Block 2': {'read': 'KeyA|B', 'write': 'KeyA|B', 'inc': 'KeyA|B', 'dec': 'KeyA|B'},
    'Trailer': {
      'readKeyA': 'Never',
      'writeKeyA': 'KeyA',
      'readKeyB': 'KeyA|B',
      'writeKeyB': 'KeyA',
      'readAC': 'KeyA',
      'writeAC': 'KeyA'
    },
  };

  String _c1 = '0';
  String _c2 = '0';
  String _c3 = '0';
  String _calculatedBits = '000';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Access Bits Calculator'),
        backgroundColor: Colors.purple.shade800,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Calculator
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Access Bits Calculator',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // C1, C2, C3 Selectors
                    _buildBitSelector('C1 (Bit 7)', _c1, (value) {
                      setState(() => _c1 = value);
                      _calculateBits();
                    }),
                    const SizedBox(height: 12),
                    _buildBitSelector('C2 (Bit 8)', _c2, (value) {
                      setState(() => _c2 = value);
                      _calculateBits();
                    }),
                    const SizedBox(height: 12),
                    _buildBitSelector('C3 (Bit 9)', _c3, (value) {
                      setState(() => _c3 = value);
                      _calculateBits();
                    }),

                    const SizedBox(height: 24),

                    // Result
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.purple.shade200),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Access Bits (Binary)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _calculatedBits,
                            style: const TextStyle(
                              fontSize: 32,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'C1 C2 C3 = $_c1 $_c2 $_c3',
                            style: const TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Access Matrix
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Access Conditions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildAccessMatrix(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Explanation
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'How to Read This Table',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildLegendItem('KeyA', Colors.blue),
                    _buildLegendItem('KeyB', Colors.green),
                    _buildLegendItem('KeyA|B', Colors.orange),
                    _buildLegendItem('Never', Colors.red),
                    const SizedBox(height: 12),
                    const Text(
                      'For data blocks (0-2): Read, Write, Increment, Decrement operations',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const Text(
                      'For trailer block: Access to KeyA, KeyB, and Access Condition bits',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBitSelector(String label, String value, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
           // marginBottom: 8,
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _buildBitOption('0', value == '0', () => onChanged('0')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildBitOption('1', value == '1', () => onChanged('1')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBitOption(String bit, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? Colors.purple : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? Colors.purple : Colors.grey.shade300,
          ),
        ),
        child: Text(
          bit,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildAccessMatrix() {
    final accessConditions = _getAccessConditions(_c1, _c2, _c3);

    return Column(
      children: [
        // Header
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Block',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                ...['Read', 'Write', 'Increment', 'Decrement'].map((op) =>
                    Expanded(
                      child: Text(
                        op,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    )
                ).toList(),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Data Blocks
        ...['Block 0', 'Block 1', 'Block 2'].map((block) =>
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      block,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  ...['read', 'write', 'inc', 'dec'].map((op) =>
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          decoration: BoxDecoration(
                            color: _getColorForAccess(accessConditions[block]![op]!),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            accessConditions[block]![op]!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                  ).toList(),
                ],
              ),
            )
        ).toList(),

        const SizedBox(height: 16),

        // Trailer Block Header
        Container(
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'Trailer Block (Block 3)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Trailer Operations
        ...[
          {'label': 'Read Key A', 'key': 'readKeyA'},
          {'label': 'Write Key A', 'key': 'writeKeyA'},
          {'label': 'Read Key B', 'key': 'readKeyB'},
          {'label': 'Write Key B', 'key': 'writeKeyB'},
          {'label': 'Read Access Bits', 'key': 'readAC'},
          {'label': 'Write Access Bits', 'key': 'writeAC'},
        ].map((item) =>
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      item['label']!,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      decoration: BoxDecoration(
                        color: _getColorForAccess(accessConditions['Trailer']![item['key']]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        accessConditions['Trailer']![item['key']]!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
        ).toList(),
      ],
    );
  }

  Map<String, Map<String, String>> _getAccessConditions(String c1, String c2, String c3) {
    // This is a simplified version. In reality, you'd have the full access matrix
    final bits = c1 + c2 + c3;

    switch (bits) {
      case '000':
        return {
          'Block 0': {'read': 'KeyA|B', 'write': 'KeyA|B', 'inc': 'KeyA|B', 'dec': 'KeyA|B'},
          'Block 1': {'read': 'KeyA|B', 'write': 'KeyA|B', 'inc': 'KeyA|B', 'dec': 'KeyA|B'},
          'Block 2': {'read': 'KeyA|B', 'write': 'KeyA|B', 'inc': 'KeyA|B', 'dec': 'KeyA|B'},
          'Trailer': {
            'readKeyA': 'Never',
            'writeKeyA': 'KeyA',
            'readKeyB': 'KeyA|B',
            'writeKeyB': 'KeyA',
            'readAC': 'KeyA',
            'writeAC': 'KeyA'
          },
        };
      case '010':
        return {
          'Block 0': {'read': 'KeyA|B', 'write': 'KeyB', 'inc': 'KeyB', 'dec': 'KeyB'},
          'Block 1': {'read': 'KeyA|B', 'write': 'Never', 'inc': 'Never', 'dec': 'Never'},
          'Block 2': {'read': 'KeyA|B', 'write': 'KeyB', 'inc': 'KeyB', 'dec': 'KeyB'},
          'Trailer': {
            'readKeyA': 'Never',
            'writeKeyA': 'KeyA',
            'readKeyB': 'KeyA|B',
            'writeKeyB': 'Never',
            'readAC': 'KeyA',
            'writeAC': 'KeyA'
          },
        };
      case '100':
        return {
          'Block 0': {'read': 'KeyA|B', 'write': 'KeyB', 'inc': 'Never', 'dec': 'Never'},
          'Block 1': {'read': 'KeyB', 'write': 'KeyB', 'inc': 'Never', 'dec': 'Never'},
          'Block 2': {'read': 'KeyB', 'write': 'KeyB', 'inc': 'Never', 'dec': 'Never'},
          'Trailer': {
            'readKeyA': 'Never',
            'writeKeyA': 'KeyA',
            'readKeyB': 'KeyB',
            'writeKeyB': 'Never',
            'readAC': 'KeyA',
            'writeAC': 'KeyA'
          },
        };
      case '110':
        return {
          'Block 0': {'read': 'KeyB', 'write': 'Never', 'inc': 'Never', 'dec': 'Never'},
          'Block 1': {'read': 'KeyB', 'write': 'KeyB', 'inc': 'Never', 'dec': 'Never'},
          'Block 2': {'read': 'KeyB', 'write': 'KeyB', 'inc': 'Never', 'dec': 'Never'},
          'Trailer': {
            'readKeyA': 'Never',
            'writeKeyA': 'Never',
            'readKeyB': 'KeyB',
            'writeKeyB': 'Never',
            'readAC': 'KeyB',
            'writeAC': 'Never'
          },
        };
      case '001':
        return {
          'Block 0': {'read': 'KeyA|B', 'write': 'KeyB', 'inc': 'KeyB', 'dec': 'KeyB'},
          'Block 1': {'read': 'KeyA|B', 'write': 'KeyB', 'inc': 'KeyB', 'dec': 'KeyB'},
          'Block 2': {'read': 'KeyA|B', 'write': 'KeyB', 'inc': 'KeyB', 'dec': 'KeyB'},
          'Trailer': {
            'readKeyA': 'Never',
            'writeKeyA': 'KeyA',
            'readKeyB': 'KeyA|B',
            'writeKeyB': 'KeyA',
            'readAC': 'KeyA',
            'writeAC': 'KeyA'
          },
        };
      case '011':
        return {
          'Block 0': {'read': 'KeyB', 'write': 'KeyB', 'inc': 'KeyB', 'dec': 'KeyB'},
          'Block 1': {'read': 'KeyB', 'write': 'Never', 'inc': 'Never', 'dec': 'Never'},
          'Block 2': {'read': 'KeyB', 'write': 'Never', 'inc': 'Never', 'dec': 'Never'},
          'Trailer': {
            'readKeyA': 'Never',
            'writeKeyA': 'KeyA',
            'readKeyB': 'KeyB',
            'writeKeyB': 'KeyA',
            'readAC': 'KeyA',
            'writeAC': 'KeyA'
          },
        };
      case '101':
        return {
          'Block 0': {'read': 'Never', 'write': 'Never', 'inc': 'Never', 'dec': 'Never'},
          'Block 1': {'read': 'KeyB', 'write': 'Never', 'inc': 'Never', 'dec': 'Never'},
          'Block 2': {'read': 'KeyB', 'write': 'KeyB', 'inc': 'Never', 'dec': 'Never'},
          'Trailer': {
            'readKeyA': 'Never',
            'writeKeyA': 'Never',
            'readKeyB': 'KeyB',
            'writeKeyB': 'KeyA',
            'readAC': 'KeyA|B',
            'writeAC': 'Never'
          },
        };
      case '111':
        return {
          'Block 0': {'read': 'Never', 'write': 'Never', 'inc': 'Never', 'dec': 'Never'},
          'Block 1': {'read': 'Never', 'write': 'Never', 'inc': 'Never', 'dec': 'Never'},
          'Block 2': {'read': 'Never', 'write': 'Never', 'inc': 'Never', 'dec': 'Never'},
          'Trailer': {
            'readKeyA': 'Never',
            'writeKeyA': 'Never',
            'readKeyB': 'Never',
            'writeKeyB': 'Never',
            'readAC': 'KeyA|B',
            'writeAC': 'Never'
          },
        };
      default:
        return _accessMatrix;
    }
  }

  Color _getColorForAccess(String access) {
    switch (access) {
      case 'KeyA':
        return Colors.blue.shade100;
      case 'KeyB':
        return Colors.green.shade100;
      case 'KeyA|B':
        return Colors.orange.shade100;
      case 'Never':
        return Colors.red.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  Widget _buildLegendItem(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            color: color,
            margin: const EdgeInsets.only(right: 8),
          ),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  void _calculateBits() {
    setState(() {
      _calculatedBits = _c1 + _c2 + _c3;
    });
  }

  @override
  void initState() {
    super.initState();
    _calculateBits();
  }
}