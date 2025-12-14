import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NfcProvider with ChangeNotifier {
  static const MethodChannel _methodChannel = MethodChannel('mifare_classic/method');
  static const EventChannel _eventChannel = EventChannel('mifare_classic/events');

  String _errorMessage = '';
  bool _isLoading = false;
  bool _isNfcAvailable = true;
  Map<String, dynamic> _cardData = {};
  Map<String, String> _customKeys = {};
  String _lastScannedUid = '';
  Stream<dynamic>? _tagStream;
  String? _lastDetectedUid;
  final Map<String, Map<String, String>> _cardKeys = {};
  String? _temporaryKeyA;
  String? _temporaryKeyB;

  String? get lastDetectedUid => _lastDetectedUid;
  String get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isNfcAvailable => _isNfcAvailable;
  Map<String, dynamic> get cardData => _cardData;
  Map<String, String> get customKeys => _customKeys;
  String get lastScannedUid => _lastScannedUid;
  String? get temporaryKeyA => _temporaryKeyA;
  String? get temporaryKeyB => _temporaryKeyB;

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
        final mapData = _convertData(data);
        print('DEBUG: Converted data keys: ${mapData.keys.toList()}');

        // Extract UID
        final uid = mapData['uid']?.toString() ?? '';
        if (uid.isNotEmpty && uid != 'N/A') {
          print('DEBUG: Tag UID: $uid');
          _lastScannedUid = uid;
          _updateLastDetectedUid(uid); // Track UID for storage
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

  Map<String, dynamic> _convertData(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    } else if (data is Map) {
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

  dynamic _convertValue(dynamic value) {
    if (value is Map) {
      return _convertData(value);
    } else if (value is List) {
      return value.map(_convertValue).toList();
    } else {
      return value;
    }
  }
// Add this method for scanning with custom keys
  Future<void> startScanWithCustomKeys({String? keyA, String? keyB}) async {
    try {
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
      await _startScanWithKeys();
    } catch (e) {
      print('DEBUG: Error in startScanWithCustomKeys: $e');
      _errorMessage = 'Error scanning with custom keys: $e';
      _isLoading = false;
      notifyListeners();
    }
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
        await _methodChannel.invokeMethod('setCustomKeys', {'keys': keysMap});
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

      await _methodChannel.invokeMethod('setSectorKeyBatch', {
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

  // Add this to track UID when tag is detected
  void _updateLastDetectedUid(String uid) {
    _lastDetectedUid = uid;
    print('DEBUG: Updated last detected UID: $uid');

    // Auto-load saved keys for this card
    _loadSavedKeysForCard(uid);
  }

  // Helper method to load saved keys
  Future<void> _loadSavedKeysForCard(String uid) async {
    try {
      final keys = await loadKeysForCard(uid);
      if (keys != null) {
        print('DEBUG: Loaded ${keys.length} saved keys for card $uid');

        // Apply these keys to in-memory storage
        await setCustomKeys(keys);
      }
    } catch (e) {
      print('ERROR: Failed to load saved keys: $e');
    }
  }

  // Add this method to save sector key to storage
  Future<bool> saveSectorKeyToStorage({
    required int sector,
    required String keyType,
    required String key,
    required String uid,
  }) async {
    try {
      print('DEBUG: Saving key to storage - UID: $uid, Sector: $sector, Type: $keyType');

      final Map<String, dynamic> args = {
        'uid': uid,
        'keyType': keyType,
        'sector': sector,
        'key': key,
      };

      final result = await _methodChannel.invokeMethod('saveSectorKey', args);
      return result == true;
    } catch (e) {
      print('ERROR: Failed to save key to storage: $e');
      return false;
    }
  }

  // Add this method to load keys for a specific card
  Future<Map<String, String>?> loadKeysForCard(String uid) async {
    try {
      final Map<String, dynamic> args = {'uid': uid};
      final result = await _methodChannel.invokeMethod('loadKeysForCard', args);
      return result != null ? Map<String, String>.from(result) : null;
    } catch (e) {
      print('ERROR: Failed to load keys for card: $e');
      return null;
    }
  }

  Stream<dynamic> get tagStream => _tagStream ?? const Stream.empty();

  // Start scanning


  List<Map<String, dynamic>> getBlocks() {
    final blocks = _cardData['blocks'];
    if (blocks is List) {
      return blocks.whereType<Map>().map((block) {
        if (block is Map<String, dynamic>) {
          return block;
        } else {
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

  List<Map<String, dynamic>> getKeyInfo() {
    final keyInfo = _cardData['keyInfo'];
    if (keyInfo is List) {
      return keyInfo.whereType<Map>().map((info) {
        if (info is Map<String, dynamic>) {
          return info;
        } else {
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

  String getCardInfo(String key, String defaultValue) {
    final value = _cardData[key];
    return value?.toString() ?? defaultValue;
  }

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
      final result = await _methodChannel.invokeMethod('setSectorKey', {
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
      _customKeys.remove('${keyType}_$sector');
      await _methodChannel.invokeMethod('clearCustomKeys');

      for (var entry in _customKeys.entries) {
        final parts = entry.key.split('_');
        if (parts.length == 2) {
          final type = parts[0];
          final sec = int.tryParse(parts[1]) ?? 0;
          await _methodChannel.invokeMethod('setSectorKey', {
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

      String cleanData;
      if (isHex) {
        cleanData = data.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();
        if (cleanData.isEmpty) {
          _errorMessage = 'Invalid hex data';
          return false;
        }
        if (cleanData.length % 2 != 0) {
          cleanData = '0$cleanData';
        }
        if (cleanData.length < 32) {
          cleanData = cleanData.padRight(32, '0');
        } else if (cleanData.length > 32) {
          cleanData = cleanData.substring(0, 32);
        }
      } else {
        final bytes = utf8.encode(data);
        cleanData = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('').toUpperCase();
        if (cleanData.length < 32) {
          cleanData = cleanData.padRight(32, '0');
        } else if (cleanData.length > 32) {
          cleanData = cleanData.substring(0, 32);
        }
      }

      final Map<String, dynamic> args = {
        'data': cleanData,
        'isHex': true,
        'sector': sector,
        'block': block,
      };

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
      final result = await _methodChannel.invokeMethod('writeData', args);
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
      final result = await _methodChannel.invokeMethod('configureSector', {
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

        // Save to permanent storage if we have a card UID
        if (_lastDetectedUid != null) {
          await saveSectorKeyToStorage(
            sector: sector,
            keyType: 'A',
            key: newKeyA,
            uid: _lastDetectedUid!,
          );
        }
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
      await getCustomKeys();
      return true;
    } catch (e) {
      return false;
    }
  }

// Multi-key array storage
  List<String> _customKeyArrayA = [];
  List<String> _customKeyArrayB = [];

// Getters
  List<String> get customKeyArrayA => List.from(_customKeyArrayA);
  List<String> get customKeyArrayB => List.from(_customKeyArrayB);

// Load saved custom key arrays
  Future<void> loadCustomKeyArrays() async {
    try {
      final result = await _methodChannel.invokeMethod('loadCustomKeyArrays');
      if (result != null && result is Map) {
        final keyMap = Map<String, dynamic>.from(result);

        if (keyMap.containsKey('keyA')) {
          final keysA = List<String>.from(keyMap['keyA'] ?? []);
          _customKeyArrayA = keysA;
        }

        if (keyMap.containsKey('keyB')) {
          final keysB = List<String>.from(keyMap['keyB'] ?? []);
          _customKeyArrayB = keysB;
        }

        print('DEBUG: Loaded custom key arrays - A: ${_customKeyArrayA.length}, B: ${_customKeyArrayB.length}');
      }
    } catch (e) {
      print('DEBUG: Error loading custom key arrays: $e');
    }
  }

// Save custom key arrays
  Future<void> saveCustomKeyArrays() async {
    try {
      final keyMap = {
        'keyA': _customKeyArrayA,
        'keyB': _customKeyArrayB,
      };

      await _methodChannel.invokeMethod('saveCustomKeyArrays', {
        'keys': keyMap,
      });

      print('DEBUG: Saved custom key arrays to storage');
    } catch (e) {
      print('DEBUG: Error saving custom key arrays: $e');
    }
  }

// Add key to array
  Future<bool> addCustomKeyToArray(String key, String keyType) async {
    try {
      // Validate key
      final cleanKey = key.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();
      if (cleanKey.length != 12) {
        _errorMessage = 'Key must be 12 hex characters';
        return false;
      }

      // Check if already exists
      if (keyType == 'A') {
        if (!_customKeyArrayA.contains(cleanKey)) {
          _customKeyArrayA.add(cleanKey);
        }
      } else {
        if (!_customKeyArrayB.contains(cleanKey)) {
          _customKeyArrayB.add(cleanKey);
        }
      }

      // Save to storage
      await saveCustomKeyArrays();

      notifyListeners();
      return true;
    } catch (e) {
      print('DEBUG: Error adding custom key to array: $e');
      return false;
    }
  }

// Remove key from array
  Future<bool> removeCustomKeyFromArray(String key, String keyType) async {
    try {
      if (keyType == 'A') {
        _customKeyArrayA.remove(key);
      } else {
        _customKeyArrayB.remove(key);
      }

      // Save to storage
      await saveCustomKeyArrays();

      notifyListeners();
      return true;
    } catch (e) {
      print('DEBUG: Error removing custom key from array: $e');
      return false;
    }
  }

// Clear all keys from array
  Future<void> clearCustomKeyArray(String keyType) async {
    try {
      if (keyType == 'A') {
        _customKeyArrayA.clear();
      } else {
        _customKeyArrayB.clear();
      }

      await saveCustomKeyArrays();
      notifyListeners();
    } catch (e) {
      print('DEBUG: Error clearing custom key array: $e');
    }
  }

  Future<bool> startScan() async {
    try {
      print('DEBUG: startScan called');

      // Reset tag connection first
      await _resetTagConnection();

      // Clear previous data
      clearCardData();

      // Set loading state
      _isLoading = true;
      _errorMessage = '';
      notifyListeners();

      // Apply custom keys from arrays
      await _applyCustomKeysFromArrays();

      // Small delay before starting scan
      await Future.delayed(Duration(milliseconds: 500));

      // Call the native method
      final result = await _methodChannel.invokeMethod('startScan');

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

// New private method to apply custom keys from arrays
  Future<void> _applyCustomKeysFromArrays() async {
    try {
      // Build keys map from arrays - TEST EACH KEY PROPERLY
      final Map<String, String> keysMap = {};

      // For Key A array: Test each key sequentially
      if (_customKeyArrayA.isNotEmpty) {
        // Instead of overwriting all sectors, we need a smarter approach
        // Use all keys for testing, but don't overwrite
        for (int i = 0; i < _customKeyArrayA.length; i++) {
          final key = _customKeyArrayA[i];
          // Add each key to all sectors
          for (int sector = 0; sector < 16; sector++) {
            keysMap['A_${sector}_$i'] = key; // Unique key identifier
          }
        }
      }

      // For Key B array
      if (_customKeyArrayB.isNotEmpty) {
        for (int i = 0; i < _customKeyArrayB.length; i++) {
          final key = _customKeyArrayB[i];
          for (int sector = 0; sector < 16; sector++) {
            keysMap['B_${sector}_$i'] = key; // Unique key identifier
          }
        }
      }

      if (keysMap.isNotEmpty) {
        print('DEBUG: Auto-applied ${keysMap.length} custom keys from arrays');
        print('DEBUG: Key A count: ${_customKeyArrayA.length}');
        print('DEBUG: Key B count: ${_customKeyArrayB.length}');

        // Send to Android with a flag indicating multiple keys
        await _methodChannel.invokeMethod('setCustomKeys', {
          'keys': keysMap,
          'multipleKeys': true, // Add this flag
        });
      } else {
        await _methodChannel.invokeMethod('clearCustomKeys');
        print('DEBUG: No custom keys to apply');
      }
    } catch (e) {
      print('DEBUG: Error applying custom keys: $e');
    }
  }

  Future<void> _resetTagConnection() async {
    try {
      // Clear any existing tag connection
      await _methodChannel.invokeMethod('clearCurrentTag');

      // Small delay to allow NFC to reset
      await Future.delayed(Duration(milliseconds: 300));
    } catch (e) {
      print('DEBUG: Error resetting tag connection: $e');
    }
  }
// You can keep the startScanWithCustomKeyArrays method for manual use
  Future<void> startScanWithCustomKeyArrays() async {
    try {
      print('DEBUG: Manual scan with custom keys called');

      // Clear previous data
      clearCardData();

      // Set loading state
      _isLoading = true;
      _errorMessage = '';
      notifyListeners();

      // Apply custom keys
      await _applyCustomKeysFromArrays();

      // Call the native method
      final result = await _methodChannel.invokeMethod('startScan');

      if (result == true) {
        print('DEBUG: Manual scan with custom keys started');
      } else {
        _errorMessage = 'Failed to start scan';
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      print('DEBUG: Error in startScanWithCustomKeyArrays: $e');
      _errorMessage = 'Error scanning with custom keys: $e';
      _isLoading = false;
      notifyListeners();
    }
  }
  // Get custom keys from plugin
  Future<Map<String, String>> getCustomKeys() async {
    try {
      final result = await _methodChannel.invokeMethod('getCustomKeys');
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
      final result = await _methodChannel.invokeMethod('clearCustomKeys');
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
      final result = await _methodChannel.invokeMethod('readWithKeys', {'keys': keys});
      return result == true;
    } on PlatformException catch (e) {
      _errorMessage = e.message ?? 'Unknown error';
      return false;
    }
  }

  // Check if method exists
  Future<bool> hasMethod(String methodName) async {
    try {
      await _methodChannel.invokeMethod(methodName, {});
      return true;
    } on PlatformException catch (e) {
      if (e.code == 'notImplemented') {
        return false;
      }
      return true;
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
      await _methodChannel.invokeMethod('clearAllCardKeys');
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
      final jsonString = json.encode(_cardKeys);
      await _methodChannel.invokeMethod('saveCardKeysToStorage', {
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
      final result = await _methodChannel.invokeMethod('loadCardKeysFromStorage');

      if (result != null && result is String && result.isNotEmpty) {
        final loadedData = json.decode(result) as Map<String, dynamic>;

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
      final Map<String, String> keysMap = {};

      for (final entry in savedKeys.entries) {
        final keyType = entry.key;
        final key = entry.value;

        for (int sector = 0; sector < 16; sector++) {
          keysMap['${keyType}_$sector'] = key;
        }
      }

      await _methodChannel.invokeMethod('setCustomKeys', {'keys': keysMap});
      print('DEBUG: Applied saved keys for card $uid');
      return true;
    } catch (e) {
      print('DEBUG: Error applying saved keys: $e');
      return false;
    }
  }

  // Set custom keys (for batch operations)
  Future<bool> setCustomKeys(Map<String, String> keys) async {
    try {
      final result = await _methodChannel.invokeMethod('setCustomKeys', {'keys': keys});
      if (result == true) {
        // Update local storage
        _customKeys.addAll(keys);
        notifyListeners();
      }
      return result == true;
    } on PlatformException catch (e) {
      _errorMessage = e.message ?? 'Unknown error';
      notifyListeners();
      return false;
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
      _cardKeys[uid]!.remove(keyType);
      if (_cardKeys[uid]!.isEmpty) {
        _cardKeys.remove(uid);
      }

      await _methodChannel.invokeMethod('removeKeyForCard', {
        'uid': uid,
        'keyType': keyType,
      });

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
}