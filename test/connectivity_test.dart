import 'package:flutter_test/flutter_test.dart';
import 'package:test_build_game/core/connectivity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConnectivityService', () {
    test('initializes with default online state and provides isOnlineNotifier', () {
      final service = ConnectivityService.instance;
      expect(service.isOnlineNotifier, isNotNull);
      expect(service.isOnline, isA<bool>());
    });

    test('checkInternet completes without throwing unhandled exceptions', () async {
      final service = ConnectivityService.instance;
      final result = await service.checkInternet(
        timeout: const Duration(milliseconds: 500),
      );
      expect(result, isA<bool>());
      expect(service.isOnline, equals(result));
    });
  });
}
