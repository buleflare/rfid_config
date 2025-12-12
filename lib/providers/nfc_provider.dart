import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NfcProvider extends ChangeNotifier {
  bool _isNfcAvailable = false;
  bool _isLoading = false;
  String _errorMessage = '';
  String _lastScannedUid = '';
  Map<String, dynamic> _cardData = {};

  // Method channel for native communication
  static const platform = MethodChannel('mifare_classic/method');
  static const eventChannel = EventChannel('mifare_classic/events');

  // Stream subscription for events
  StreamSubscription? _eventSubscription;

  // Store configuration for simulation
  Map<int, Map<String, String>> _sectorConfig = {};

  bool get isNfcAvailable => _isNfcAvailable;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  String get lastScannedUid => _lastScannedUid;
  Map<String, dynamic> get cardData => _cardData;

  NfcProvider() {
    _initializeSectorConfig();
    _initializeNfc();
  }

  void _initializeSectorConfig() {
    for (int i = 1; i <= 15; i++) {
      _sectorConfig[i] = {
        'keyA': 'FFFFFFFFFFFF',
        'keyB': 'FFFFFFFFFFFF',
        'accessBits': 'FF078069'
      };
    }
  }

  Future<void> _initializeNfc() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Initialize NFC
      final bool? result = await platform.invokeMethod('startScan');
      _isNfcAvailable = result ?? false;

      // Setup event listener
      _setupEventListener();

      _isLoading = false;
      notifyListeners();
    } on PlatformException catch (e) {
      print("NFC initialization error: ${e.message}");
      _isLoading = false;
      _errorMessage = "NFC not available on this device";
      _isNfcAvailable = false;
      notifyListeners();
    }
  }

  void _setupEventListener() {
    try {
      _eventSubscription = eventChannel.receiveBroadcastStream().listen(
            (event) {
          if (event is Map) {
            _handleNfcEvent(event);
          }
        },
        onError: (error) {
          print("Event channel error: $error");
          _errorMessage = "NFC communication error";
          notifyListeners();
        },
      );
    } catch (e) {
      print("Failed to setup event listener: $e");
    }
  }

  void _handleNfcEvent(Map event) {
    print("Received NFC event: ${event.keys}");

    if (event.containsKey('error')) {
      _errorMessage = event['error'];
      notifyListeners();
    } else if (event.containsKey('uid')) {
      // Card scanned successfully
      _lastScannedUid = event['uid'] ?? '';
      _cardData = Map<String, dynamic>.from(event);
      _errorMessage = '';

      print("Card scanned: UID=$_lastScannedUid, sectors: ${event['sectorCount']}");
      notifyListeners();
    }
  }

  Future<void> startScan() async {
    try {
      _isLoading = true;
      _errorMessage = '';
      notifyListeners();

      await platform.invokeMethod('startScan');

      _isLoading = false;
      notifyListeners();
    } on PlatformException catch (e) {
      _isLoading = false;
      _errorMessage = "Scan failed: ${e.message}";
      notifyListeners();
    }
  }

  Future<void> writeData(String data, bool isHex, int sector, int block) async {
    try {
      _isLoading = true;
      notifyListeners();

      final result = await platform.invokeMethod('writeData', {
        'data': data,
        'isHex': isHex,
        'sector': sector,
        'block': block,
      });

      _isLoading = false;
      if (result != true) {
        throw Exception('Write failed');
      }

      // Re-read the card to show updated data
      await Future.delayed(const Duration(milliseconds: 500));
      await startScan();

      notifyListeners();
    } on PlatformException catch (e) {
      _isLoading = false;
      _errorMessage = "Write failed: ${e.message}";
      notifyListeners();
      rethrow;
    } catch (e) {
      _isLoading = false;
      _errorMessage = "Write error: ${e.toString()}";
      notifyListeners();
      rethrow;
    }
  }

  Future<void> clearAllBlocks() async {
    try {
      _isLoading = true;
      notifyListeners();

      final result = await platform.invokeMethod('clearAllBlocks');

      _isLoading = false;
      if (result != true) {
        throw Exception('Clear failed');
      }

      notifyListeners();
    } on PlatformException catch (e) {
      _isLoading = false;
      _errorMessage = "Clear failed: ${e.message}";
      notifyListeners();
      rethrow;
    }
  }

  void updateConfiguration(int sector, String keyA, String keyB, String accessBits) {
    if (sector >= 1 && sector <= 15) {
      _sectorConfig[sector] = {
        'keyA': keyA,
        'keyB': keyB,
        'accessBits': accessBits,
      };
      notifyListeners();
    }
  }

  Map<String, String>? getSectorConfig(int sector) {
    return _sectorConfig[sector];
  }

  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  void clearCardData() {
    _cardData = {};
    _lastScannedUid = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}