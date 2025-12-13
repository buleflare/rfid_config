import 'dart:convert';

import 'package:convert/convert.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert' as convert;

class NfcProvider with ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('mifare_classic/method');
  static const EventChannel _eventChannel = EventChannel('mifare_classic/events');

  String _errorMessage = '';
  bool _isLoading = false;
  bool _isNfcAvailable = true; // Assume NFC is available
  Map<String, dynamic> _cardData = {};
  Map<String, String> _customKeys = {};
  String _lastScannedUid = '';
  Stream<dynamic>? _tagStream;

  String get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isNfcAvailable => _isNfcAvailable;
  Map<String, dynamic> get cardData => _cardData;
  Map<String, String> get customKeys => _customKeys;
  String get lastScannedUid => _lastScannedUid;

  NfcProvider() {
    _initStream();
  }

  void _initStream() {
    print('DEBUG: Initializing NFC stream');
    _tagStream = _eventChannel.receiveBroadcastStream();

    _tagStream?.listen((data) {
      print('DEBUG: Received NFC data in Flutter');
      print('DEBUG: Data type: ${data.runtimeType}');

      try {
        // Safely convert the data
        final mapData = _convertData(data);

        print('DEBUG: Converted data keys: ${mapData.keys.toList()}');

        // Extract UID
        final uid = mapData['uid']?.toString() ?? '';
        if (uid.isNotEmpty && uid != 'N/A') {
          print('DEBUG: Tag UID: $uid');
          _lastScannedUid = uid;
        }

        // Check for blocks
        if (mapData.containsKey('blocks')) {
          final blocks = mapData['blocks'];
          if (blocks is List) {
            print('DEBUG: Blocks found: ${blocks.length}');
          }
        }

        _cardData = mapData;
        _isLoading = false;
        notifyListeners();

      } catch (e) {
        print('DEBUG: Error processing NFC data: $e');
        print('DEBUG: Raw data: $data');
        _errorMessage = 'Error processing tag data: $e';
        _isLoading = false;
        notifyListeners();
      }
    }, onError: (error) {
      print('DEBUG: NFC Stream error: $error');
      _errorMessage = error.toString();
      _isLoading = false;
      notifyListeners();
    }, onDone: () {
      print('DEBUG: NFC Stream closed');
    });
  }

// Helper method to safely convert platform data
  Map<String, dynamic> _convertData(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    } else if (data is Map) {
      // Convert Map<Object?, Object?> to Map<String, dynamic>
      final result = <String, dynamic>{};
      data.forEach((key, value) {
        final stringKey = key.toString();
        result[stringKey] = _convertValue(value);
      });
      return result;
    } else {
      return {'error': 'Invalid data format: ${data.runtimeType}'};
    }
  }

// Recursively convert values
  dynamic _convertValue(dynamic value) {
    if (value is Map) {
      return _convertData(value);
    } else if (value is List) {
      return value.map(_convertValue).toList();
    } else {
      return value;
    }
  }

  Stream<dynamic> get tagStream => _tagStream ?? const Stream.empty();

  // Start scanning
  Future<bool> startScan() async {
    try {
      _isLoading = true;
      _errorMessage = '';
      notifyListeners();

      final result = await _channel.invokeMethod('startScan');
      _isLoading = false;
      notifyListeners();
      return result == true;
    } on PlatformException catch (e) {
      _errorMessage = e.message ?? 'Unknown error';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

// Get blocks from card data
  List<Map<String, dynamic>> getBlocks() {
    final blocks = _cardData['blocks'];
    if (blocks is List) {
      return blocks.whereType<Map>().map((block) {
        if (block is Map<String, dynamic>) {
          return block;
        } else {
          // Convert Map<dynamic, dynamic> to Map<String, dynamic>
          return Map<String, dynamic>.fromEntries(
              block.entries.map((entry) =>
                  MapEntry(entry.key.toString(), entry.value)
              )
          );
        }
      }).toList();
    }
    return [];
  }

// Get key info from card data
  List<Map<String, dynamic>> getKeyInfo() {
    final keyInfo = _cardData['keyInfo'];
    if (keyInfo is List) {
      return keyInfo.whereType<Map>().map((info) {
        if (info is Map<String, dynamic>) {
          return info;
        } else {
          // Convert Map<dynamic, dynamic> to Map<String, dynamic>
          return Map<String, dynamic>.fromEntries(
              info.entries.map((entry) =>
                  MapEntry(entry.key.toString(), entry.value)
              )
          );
        }
      }).toList();
    }
    return [];
  }

// Get card info by key
  String getCardInfo(String key, String defaultValue) {
    final value = _cardData[key];
    return value?.toString() ?? defaultValue;
  }

// Get card info as int
  int getCardInfoInt(String key, int defaultValue) {
    final value = _cardData[key];
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    if (value is num) return value.toInt();
    return defaultValue;
  }

  // Set custom key
  Future<bool> setCustomKey(int sector, String keyType, String key) async {
    try {
      final result = await _channel.invokeMethod('setSectorKey', {
        'sector': sector,
        'keyType': keyType,
        'key': key,
      });

      if (result == true) {
        _customKeys['${keyType}_$sector'] = key;
        notifyListeners();
      }
      return result == true;
    } on PlatformException catch (e) {
      _errorMessage = e.message ?? 'Unknown error';
      notifyListeners();
      return false;
    }
  }

  // Get key for specific sector and type
  String? getKeyForSector(int sector, String keyType) {
    return _customKeys['${keyType}_$sector'];
  }

  // Remove custom key
  Future<bool> removeCustomKey(int sector, String keyType) async {
    try {
      // Clear the key locally
      _customKeys.remove('${keyType}_$sector');

      // Re-set all remaining keys to the plugin
      await _channel.invokeMethod('clearCustomKeys');

      for (var entry in _customKeys.entries) {
        final parts = entry.key.split('_');
        if (parts.length == 2) {
          final type = parts[0];
          final sec = int.tryParse(parts[1]) ?? 0;
          await _channel.invokeMethod('setSectorKey', {
            'sector': sec,
            'keyType': type,
            'key': entry.value,
          });
        }
      }

      notifyListeners();
      return true;
    } on PlatformException catch (e) {
      _errorMessage = e.message ?? 'Unknown error';
      notifyListeners();
      return false;
    }
  }

  // Clear last scanned UID
  Future<void> clearLastScannedUid() async {
    _lastScannedUid = '';
    notifyListeners();
  }

  // Write data
  Future<bool> writeData(
      String data,
      bool isHex,
      int sector,
      int block,
      {String? customKeyA, String? customKeyB}
      ) async {
    try {
      // Validate custom keys
      if (customKeyA != null && customKeyA.isNotEmpty) {
        final cleanKeyA = customKeyA.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();
        if (cleanKeyA.length != 12 || !RegExp(r'^[0-9A-F]{12}$').hasMatch(cleanKeyA)) {
          _errorMessage = 'Invalid Key A format. Must be exactly 12 hex characters.';
          return false;
        }
      }

      if (customKeyB != null && customKeyB.isNotEmpty) {
        final cleanKeyB = customKeyB.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();
        if (cleanKeyB.length != 12 || !RegExp(r'^[0-9A-F]{12}$').hasMatch(cleanKeyB)) {
          _errorMessage = 'Invalid Key B format. Must be exactly 12 hex characters.';
          return false;
        }
      }

      // Prepare data for writing - ALWAYS convert to hex
      String cleanData;
      if (isHex) {
        // Clean hex data
        cleanData = data.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();
        if (cleanData.isEmpty) {
          _errorMessage = 'Invalid hex data';
          return false;
        }
        // Pad to even length
        if (cleanData.length % 2 != 0) {
          cleanData = '0$cleanData';
        }
        // Pad to 32 characters max
        if (cleanData.length < 32) {
          cleanData = cleanData.padRight(32, '0');
        } else if (cleanData.length > 32) {
          cleanData = cleanData.substring(0, 32);
        }
      } else {
        // Convert text to hex
        final bytes = utf8.encode(data);
        cleanData = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('').toUpperCase();
        // Pad to 32 characters max
        if (cleanData.length < 32) {
          cleanData = cleanData.padRight(32, '0');
        } else if (cleanData.length > 32) {
          cleanData = cleanData.substring(0, 32);
        }
      }

      // Always send as hex to Android
      final Map<String, dynamic> args = {
        'data': cleanData,
        'isHex': true, // Always true since we always send hex
        'sector': sector,
        'block': block,
      };

      // Prepare keys
      final keys = <String, String>{};

      if (customKeyA != null && customKeyA.isNotEmpty) {
        final cleanKeyA = customKeyA.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();
        keys['A_$sector'] = cleanKeyA;
        print('DEBUG: Adding Key A for sector $sector: $cleanKeyA');
      }

      if (customKeyB != null && customKeyB.isNotEmpty) {
        final cleanKeyB = customKeyB.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();
        keys['B_$sector'] = cleanKeyB;
        print('DEBUG: Adding Key B for sector $sector: $cleanKeyB');
      }

      if (keys.isNotEmpty) {
        args['keys'] = keys;
        print('DEBUG: Sending keys map to Android: $keys');
      }

      print('DEBUG: Writing hex data: $cleanData');
      final result = await _channel.invokeMethod('writeData', args);
      print('DEBUG: Write result from Android: $result');
      return result == true;
    } on PlatformException catch (e) {
      _errorMessage = e.message ?? 'Unknown error';
      print('DEBUG: PlatformException in writeData: $_errorMessage');
      return false;
    }
  }
  // Configure sector
  Future<bool> configureSector({
    required int sector,
    required String currentKey,
    required String keyType,
    required String newKeyA,
    required String newKeyB,
    required String accessBits,
  }) async {
    print('DEBUG: NfcProvider.configureSector called');
    print('DEBUG:   sector: $sector');
    print('DEBUG:   keyType: $keyType');
    print('DEBUG:   currentKey: $currentKey');
    print('DEBUG:   newKeyA: $newKeyA');
    print('DEBUG:   newKeyB: $newKeyB');
    print('DEBUG:   accessBits: $accessBits');

    try {
      final result = await _channel.invokeMethod('configureSector', {
        'sector': sector,
        'currentKey': currentKey,
        'keyType': keyType,
        'newKeyA': newKeyA,
        'newKeyB': newKeyB,
        'accessBits': accessBits,
      });

      print('DEBUG: configureSector result: $result');

      if (result == true) {
        // Save the new key A for future use
        _customKeys['A_$sector'] = newKeyA;
        print('DEBUG: Saved Key A for sector $sector: $newKeyA');
      }

      return result == true;
    } on PlatformException catch (e) {
      print('DEBUG: PlatformException in configureSector: ${e.message}');
      print('DEBUG: Exception details: ${e.details}');
      print('DEBUG: Exception code: ${e.code}');
      _errorMessage = e.message ?? 'Unknown error';
      return false;
    } catch (e) {
      print('DEBUG: Other error in configureSector: $e');
      _errorMessage = e.toString();
      return false;
    }
  }
// Add this method to check if tag is still present
  Future<bool> checkTagPresent() async {
    try {
      // Try to read custom keys - if this works, tag is probably present
      await getCustomKeys();
      return true;
    } catch (e) {
      return false;
    }
  }
  // Get custom keys from plugin
  Future<Map<String, String>> getCustomKeys() async {
    try {
      final result = await _channel.invokeMethod('getCustomKeys');
      _customKeys = Map<String, String>.from(result ?? {});
      notifyListeners();
      return _customKeys;
    } on PlatformException catch (e) {
      _errorMessage = e.message ?? 'Unknown error';
      return {};
    }
  }

  // Clear all custom keys
  Future<bool> clearCustomKeys() async {
    try {
      final result = await _channel.invokeMethod('clearCustomKeys');
      if (result == true) {
        _customKeys.clear();
        notifyListeners();
      }
      return result == true;
    } on PlatformException catch (e) {
      _errorMessage = e.message ?? 'Unknown error';
      return false;
    }
  }

  // Read with specific keys
  Future<bool> readWithKeys(Map<String, String> keys) async {
    try {
      final result = await _channel.invokeMethod('readWithKeys', {'keys': keys});
      return result == true;
    } on PlatformException catch (e) {
      _errorMessage = e.message ?? 'Unknown error';
      return false;
    }
  }

  // Check if method exists
  Future<bool> hasMethod(String methodName) async {
    try {
      await _channel.invokeMethod(methodName, {});
      return true;
    } on PlatformException catch (e) {
      if (e.code == 'notImplemented') {
        return false;
      }
      return true;
    }
  }

  // Storage for custom keys per card (card UID -> {keyType: key})
  final Map<String, Map<String, String>> _cardKeys = {};

// Temporary custom keys for current read operation
  String? _temporaryKeyA;
  String? _temporaryKeyB;

// Start scan with custom keys
  void startScanWithCustomKeys({String? keyA, String? keyB}) {
    print('DEBUG: startScanWithCustomKeys called');
    print('DEBUG: Key A: $keyA');
    print('DEBUG: Key B: $keyB');

    // Store temporary keys for this scan session
    _temporaryKeyA = keyA?.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();
    _temporaryKeyB = keyB?.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();

    // Validate keys if provided
    if (_temporaryKeyA != null && _temporaryKeyA!.length != 12) {
      _errorMessage = 'Key A must be 12 hex characters';
      notifyListeners();
      return;
    }

    if (_temporaryKeyB != null && _temporaryKeyB!.length != 12) {
      _errorMessage = 'Key B must be 12 hex characters';
      notifyListeners();
      return;
    }

    // Clear previous data
    clearCardData();

    // Set loading state
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    // Start the scan with the custom keys
    _startScanWithKeys();
  }

// Private method to start scan with keys
  Future<void> _startScanWithKeys() async {
    try {
      print('DEBUG: Starting scan with custom keys');

      // Create keys map for Android
      final Map<String, dynamic> keysMap = {};

      if (_temporaryKeyA != null && _temporaryKeyA!.isNotEmpty) {
        // Apply Key A to all sectors (0-15)
        for (int sector = 0; sector < 16; sector++) {
          keysMap['A_$sector'] = _temporaryKeyA!;
        }
        print('DEBUG: Applied Key A to all sectors: $_temporaryKeyA');
      }

      if (_temporaryKeyB != null && _temporaryKeyB!.isNotEmpty) {
        // Apply Key B to all sectors (0-15)
        for (int sector = 0; sector < 16; sector++) {
          keysMap['B_$sector'] = _temporaryKeyB!;
        }
        print('DEBUG: Applied Key B to all sectors: $_temporaryKeyB');
      }

      if (keysMap.isNotEmpty) {
        // Send keys to Android plugin
        await _channel.invokeMethod('setCustomKeys', {'keys': keysMap});
        print('DEBUG: Custom keys sent to Android');
      }

      // Start the scan
      await startScan();

      // Clear temporary keys after scan
      _temporaryKeyA = null;
      _temporaryKeyB = null;

    } catch (e) {
      print('DEBUG: Error in _startScanWithKeys: $e');
      _errorMessage = 'Error scanning with custom keys: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

// Save key for specific card
  Future<void> saveKeyForCard(String uid, String keyType, String key) async {
    print('DEBUG: saveKeyForCard called');
    print('DEBUG: UID: $uid, KeyType: $keyType, Key: $key');

    // Validate input
    if (uid.isEmpty || uid == 'N/A') {
      _errorMessage = 'Invalid card UID';
      notifyListeners();
      return;
    }

    if (keyType != 'A' && keyType != 'B') {
      _errorMessage = 'Key type must be A or B';
      notifyListeners();
      return;
    }

    // Validate key format
    final cleanKey = key.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();
    if (cleanKey.length != 12) {
      _errorMessage = 'Key must be 12 hex characters';
      notifyListeners();
      return;
    }

    try {
      // Initialize card entry if not exists
      if (!_cardKeys.containsKey(uid)) {
        _cardKeys[uid] = {};
      }

      // Save the key
      _cardKeys[uid]![keyType] = cleanKey;

      // Also save to Android plugin for immediate use
      // Since we don't know which sector, apply to all sectors (0-15)
      final Map<String, String> keysMap = {};
      for (int sector = 0; sector < 16; sector++) {
        keysMap['${keyType}_$sector'] = cleanKey;
      }

      await _channel.invokeMethod('setSectorKeyBatch', {
        'uid': uid,
        'keyType': keyType,
        'key': cleanKey,
      });

      // Save to persistent storage
      await _saveKeysToStorage();

      print('DEBUG: Key $keyType saved for card $uid: $cleanKey');

      notifyListeners();
    } catch (e) {
      print('DEBUG: Error saving key: $e');
      _errorMessage = 'Error saving key: $e';
      notifyListeners();
    }
  }

// Get key for specific card
  String? getKeyForCard(String uid, String keyType) {
    if (uid.isEmpty || uid == 'N/A') {
      return null;
    }

    if (keyType != 'A' && keyType != 'B') {
      return null;
    }

    return _cardKeys[uid]?[keyType];
  }

// Get all keys for specific card
  Map<String, String> getKeysForCard(String uid) {
    if (uid.isEmpty || uid == 'N/A' || !_cardKeys.containsKey(uid)) {
      return {};
    }

    return Map<String, String>.from(_cardKeys[uid]!);
  }

// Remove key for specific card
  Future<bool> removeKeyForCard(String uid, String keyType) async {
    print('DEBUG: removeKeyForCard called');
    print('DEBUG: UID: $uid, KeyType: $keyType');

    if (uid.isEmpty || uid == 'N/A' || !_cardKeys.containsKey(uid)) {
      return false;
    }

    if (keyType != 'A' && keyType != 'B') {
      return false;
    }

    try {
      // Remove the specific key
      _cardKeys[uid]!.remove(keyType);

      // If no keys left for this card, remove the entire entry
      if (_cardKeys[uid]!.isEmpty) {
        _cardKeys.remove(uid);
      }

      // Remove from Android plugin
      await _channel.invokeMethod('removeKeyForCard', {
        'uid': uid,
        'keyType': keyType,
      });

      // Save to persistent storage
      await _saveKeysToStorage();

      print('DEBUG: Key $keyType removed for card $uid');

      notifyListeners();
      return true;
    } catch (e) {
      print('DEBUG: Error removing key: $e');
      _errorMessage = 'Error removing key: $e';
      notifyListeners();
      return false;
    }
  }

// Get all saved card UIDs
  List<String> getSavedCardUids() {
    return _cardKeys.keys.toList();
  }

// Check if card has saved keys
  bool hasSavedKeys(String uid) {
    return _cardKeys.containsKey(uid) && _cardKeys[uid]!.isNotEmpty;
  }

// Clear all saved keys
  Future<void> clearAllSavedKeys() async {
    try {
      _cardKeys.clear();

      // Clear from Android plugin
      await _channel.invokeMethod('clearAllCardKeys');

      // Clear from persistent storage
      await _saveKeysToStorage();

      print('DEBUG: All saved keys cleared');

      notifyListeners();
    } catch (e) {
      print('DEBUG: Error clearing all keys: $e');
      _errorMessage = 'Error clearing keys: $e';
      notifyListeners();
    }
  }

// Private method to save keys to persistent storage
  Future<void> _saveKeysToStorage() async {
    try {
      // Convert the map to JSON string
      final jsonString = json.encode(_cardKeys);
      await _channel.invokeMethod('saveCardKeysToStorage', {
        'keysJson': jsonString,
      });
      print('DEBUG: Keys saved to storage');
    } catch (e) {
      print('DEBUG: Error saving keys to storage: $e');
    }
  }

// Private method to load keys from persistent storage
  Future<void> _loadKeysFromStorage() async {
    try {
      final result = await _channel.invokeMethod('loadCardKeysFromStorage');

      if (result != null && result is String && result.isNotEmpty) {
        final loadedData = json.decode(result) as Map<String, dynamic>;

        // Convert the loaded data
        _cardKeys.clear();
        loadedData.forEach((uid, keyData) {
          if (keyData is Map<String, dynamic>) {
            _cardKeys[uid] = {};
            keyData.forEach((keyType, key) {
              if (key is String && (keyType == 'A' || keyType == 'B')) {
                _cardKeys[uid]![keyType] = key;
              }
            });
          }
        });
        print('DEBUG: Loaded ${_cardKeys.length} cards with saved keys from storage');
      }
    } catch (e) {
      print('DEBUG: Error loading keys from storage: $e');
    }
  }

// Initialize keys when provider is created
  Future<void> initializeKeys() async {
    await _loadKeysFromStorage();
    print('DEBUG: Keys initialized, ${_cardKeys.length} cards found');
  }

// Get temporary keys (used by NFC reading logic)
  String? get temporaryKeyA => _temporaryKeyA;
  String? get temporaryKeyB => _temporaryKeyB;

// Clear temporary keys
  void clearTemporaryKeys() {
    _temporaryKeyA = null;
    _temporaryKeyB = null;
  }

// Clear card data
  void clearCardData() {
    _cardData.clear();
    _errorMessage = '';
    notifyListeners();
  }

// Method to check if a card has custom keys and apply them
  Future<bool> applySavedKeysForCard(String uid) async {
    if (uid.isEmpty || uid == 'N/A') {
      return false;
    }

    final savedKeys = getKeysForCard(uid);
    if (savedKeys.isEmpty) {
      return false;
    }

    try {
      // Apply saved keys to Android plugin
      final Map<String, String> keysMap = {};

      for (final entry in savedKeys.entries) {
        final keyType = entry.key;
        final key = entry.value;

        // Apply to all sectors (0-15)
        for (int sector = 0; sector < 16; sector++) {
          keysMap['${keyType}_$sector'] = key;
        }
      }

      await _channel.invokeMethod('setCustomKeys', {'keys': keysMap});
      print('DEBUG: Applied saved keys for card $uid');
      return true;
    } catch (e) {
      print('DEBUG: Error applying saved keys: $e');
      return false;
    }
  }
}