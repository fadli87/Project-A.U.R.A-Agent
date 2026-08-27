abstract class SecureStorageService {
  static late final SecureStorageService instance;

  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
}
