import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/nfc_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<NfcProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mifare Classic 1K RFID Manager'),
        backgroundColor: Colors.blue.shade800,
        actions: [
          IconButton(
            icon: const Icon(Icons.info),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('NFC Instructions'),
                  content: const Text(
                    'This app works with real Mifare Classic 1K RFID cards.\n\n'
                        '1. Make sure NFC is enabled on your device\n'
                        '2. Hold the RFID card near the NFC antenna\n'
                        '3. The app will automatically detect and read the card\n\n'
                        'Features:\n'
                        '• Read all sectors and blocks\n'
                        '• Write data to card\n'
                        '• Configure access bits and keys\n'
                        '• Access bits calculator',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.nfc,
                          color: provider.isNfcAvailable ? Colors.green : Colors.red,
                          size: 30,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            provider.isNfcAvailable
                                ? 'NFC Hardware Ready'
                                : 'NFC Not Available',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: provider.isNfcAvailable ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (provider.lastScannedUid.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(),
                          const SizedBox(height: 10),
                          const Text(
                            'Last Scanned Card:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            provider.lastScannedUid,
                            style: const TextStyle(
                              fontSize: 16,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Main Features Grid
            // Main Features Grid - Fixed version
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.0, // Changed to 1.0
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  _buildFeatureCard(
                    context: context,
                    icon: Icons.read_more,
                    title: 'Read Card',
                    subtitle: 'View all blocks',
                    color: Colors.blue,
                    route: '/read',
                  ),
                  _buildFeatureCard(
                    context: context,
                    icon: Icons.edit,
                    title: 'Write Data',
                    subtitle: 'Write to blocks',
                    color: Colors.green,
                    route: '/write',
                  ),
                  _buildFeatureCard(
                    context: context,
                    icon: Icons.settings,
                    title: 'Configuration',
                    subtitle: 'Set keys & access',
                    color: Colors.orange,
                    route: '/config',
                  ),

                  _buildFeatureCard(
                    context: context,
                    icon: Icons.lock,
                    title: 'Access Tool',
                    subtitle: 'Decode & Generate bits',
                    color: Colors.teal,
                    route: '/access_tool',
                  ),
                ],
              ),
            ),
            // Instructions
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.nfc,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        provider.isNfcAvailable
                            ? 'Hold your Mifare Classic 1K card near the NFC antenna to read data'
                            : 'This device does not have NFC capability',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: provider.isNfcAvailable ? () {
          provider.startScan();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ready to scan - hold card near NFC'),
              duration: Duration(seconds: 2),
            ),
          );
        } : null,
        icon: const Icon(Icons.nfc),
        label: const Text('Start Scan'),
        tooltip: 'Start NFC Scanning',
      ),
    );
  }

  Widget _buildFeatureCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required String route,
  }) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 100,
            maxHeight: 120,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 32, // Reduced from 36
                  color: color,
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13, // Reduced from 14
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10, // Reduced from 11
                    color: color.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


}