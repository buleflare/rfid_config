import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

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
  Future<bool> writeData(String data, bool isHex, [int? sector, int? block]) async {
    try {
      final Map<String, dynamic> args = {
        'data': data,
        'isHex': isHex,
      };

      if (sector != null && block != null) {
        args['sector'] = sector;
        args['block'] = block;
      }

      final result = await _channel.invokeMethod('writeData', args);
      return result == true;
    } on PlatformException catch (e) {
      _errorMessage = e.message ?? 'Unknown error';
      return false;
    }
  }

  // Configure sector
  Future<bool> configureSector({
    required int sector,
    required String currentKey,
    required String keyType, // 'A' or 'B'
    required String newKeyA,
    required String newKeyB,
    required String accessBits,
  }) async {
    try {
      final result = await _channel.invokeMethod('configureSector', {
        'sector': sector,
        'currentKey': currentKey,
        'keyType': keyType,
        'newKeyA': newKeyA,
        'newKeyB': newKeyB,
        'accessBits': accessBits,
      });

      if (result == true) {
        // Save the new key A for future use
        _customKeys['A_$sector'] = newKeyA;
        notifyListeners();
      }

      return result == true;
    } on PlatformException catch (e) {
      _errorMessage = e.message ?? 'Unknown error';
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
}