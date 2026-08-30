import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:win32/win32.dart';
import 'package:aura_core/storage/secure_storage_service.dart';

class DesktopSecureStorage implements SecureStorageService {
  Future<File> _getFile() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, 'secure_credentials.json'));
      if (!await file.exists()) {
        await file.writeAsString(jsonEncode({}));
      }
      return file;
    } catch (_) {
      final file = File('secure_credentials.json');
      if (!await file.exists()) {
        await file.writeAsString(jsonEncode({}));
      }
      return file;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    final encryptedBase64 = _encrypt(value);
    if (encryptedBase64 == null) return;
    
    final file = await _getFile();
    final jsonStr = await file.readAsString();
    final data = Map<String, dynamic>.from(jsonDecode(jsonStr));
    data[key] = encryptedBase64;
    await file.writeAsString(jsonEncode(data));
  }

  @override
  Future<String?> read(String key) async {
    final file = await _getFile();
    final jsonStr = await file.readAsString();
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final encryptedBase64 = data[key] as String?;
    if (encryptedBase64 == null) return null;
    
    return _decrypt(encryptedBase64);
  }

  @override
  Future<void> delete(String key) async {
    final file = await _getFile();
    final jsonStr = await file.readAsString();
    final data = Map<String, dynamic>.from(jsonDecode(jsonStr));
    data.remove(key);
    await file.writeAsString(jsonEncode(data));
  }

  String? _encrypt(String plainText) {
    final utf8Bytes = utf8.encode(plainText);
    
    final pDataIn = calloc<CRYPT_INTEGER_BLOB>();
    final pBytes = calloc<Uint8>(utf8Bytes.length);
    for (var i = 0; i < utf8Bytes.length; i++) {
      pBytes[i] = utf8Bytes[i];
    }
    pDataIn.ref.cbData = utf8Bytes.length;
    pDataIn.ref.pbData = pBytes;

    final pDataOut = calloc<CRYPT_INTEGER_BLOB>();

    try {
      // package:win32 FFI wrapper signature (6 parameters, omitting reserved NULL):
      // CryptProtectData(pDataIn, szDataDescr, pOptionalEntropy, pPromptStruct, dwFlags, pDataOut)
      final result = CryptProtectData(
        pDataIn,
        null,
        null,
        null,
        0,
        pDataOut,
      );

      if (result.value == false) {
        throw Exception('CryptProtectData failed: ${result.error}');
      }

      final outBytes = pDataOut.ref.pbData.asTypedList(pDataOut.ref.cbData);
      final base64Str = base64.encode(outBytes);
      
      LocalFree(HLOCAL(pDataOut.ref.pbData.cast<NativeType>()));
      
      return base64Str;
    } finally {
      free(pBytes);
      free(pDataIn);
      free(pDataOut);
    }
  }

  String? _decrypt(String base64Str) {
    try {
      final encryptedBytes = base64.decode(base64Str);
      
      final pDataIn = calloc<CRYPT_INTEGER_BLOB>();
      final pBytes = calloc<Uint8>(encryptedBytes.length);
      for (var i = 0; i < encryptedBytes.length; i++) {
        pBytes[i] = encryptedBytes[i];
      }
      pDataIn.ref.cbData = encryptedBytes.length;
      pDataIn.ref.pbData = pBytes;

      final pDataOut = calloc<CRYPT_INTEGER_BLOB>();

      try {
        // package:win32 FFI wrapper signature (6 parameters, omitting reserved NULL):
        // CryptUnprotectData(pDataIn, szDataDescr, pOptionalEntropy, pPromptStruct, dwFlags, pDataOut)
        final result = CryptUnprotectData(
          pDataIn,
          null,
          null,
          null,
          0,
          pDataOut,
        );

        if (result.value == false) {
          throw Exception('CryptUnprotectData failed: ${result.error}');
        }

        final outBytes = pDataOut.ref.pbData.asTypedList(pDataOut.ref.cbData);
        final plainText = utf8.decode(outBytes);
        
        LocalFree(HLOCAL(pDataOut.ref.pbData.cast<NativeType>()));
        
        return plainText;
      } finally {
        free(pBytes);
        free(pDataIn);
        free(pDataOut);
      }
    } catch (_) {
      return null;
    }
  }
}
