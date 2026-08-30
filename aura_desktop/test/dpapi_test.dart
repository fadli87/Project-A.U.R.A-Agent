import 'package:flutter_test/flutter_test.dart';
import 'package:aura_desktop/src/services/desktop_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('DesktopSecureStorage DPAPI round-trip test', () async {
    final storage = DesktopSecureStorage();
    const testKey = 'test_dummy_api_key';
    const testValue = 'AURA_SECURE_API_KEY_998877665544332211_SECRET_TEST';

    // 1. Write dummy key
    await storage.write(testKey, testValue);

    // 2. Read back dummy key
    final readValue = await storage.read(testKey);

    expect(readValue, equals(testValue));

    // Clean up
    await storage.delete(testKey);
    final deletedValue = await storage.read(testKey);
    expect(deletedValue, isNull);
  });
}
